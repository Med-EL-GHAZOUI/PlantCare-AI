"""Validation terrain : contrôle du manifeste d'images réelles et métriques d'évaluation externe.

Fonctions pures (sans TensorFlow) : elles sont testées sur des données synthétiques. Les scripts
`validate_field_manifest.py` et `evaluate_external.py` les relient au modèle et aux fichiers.
Protocole complet : docs/FIELD_VALIDATION.md.
"""

from __future__ import annotations

import csv
import hashlib
import re
from collections import Counter, defaultdict
from dataclasses import dataclass, field
from pathlib import Path

import numpy as np
from PIL import Image, UnidentifiedImageError

from agriscan_ml.metrics import classification_report, confusion_matrix
from agriscan_ml.selective import per_class_coverage, selective_curve, wilson_interval

OOD_LABELS = ("out_of_scope", "other_disease")  # hors périmètre : le bon comportement est « incertain »
SPLITS = ("dev", "test")
LIGHTING = ("full_sun", "shade", "overcast", "indoor", "flash")
BACKGROUND = ("plain", "soil", "foliage", "hand", "other")
EXPERTISE = ("agronomist", "technician", "farmer", "student")
CERTAINTY = ("certain", "probable", "uncertain")
REQUIRED_COLUMNS = (
    "path", "label", "subject_id", "split", "site", "capture_date", "device", "lighting", "background",
    "labeler", "labeler_expertise", "label_certainty", "consent", "source",
)
MIN_SIDE = 64
GPS_IFD = 0x8825
MIN_IMAGES_PER_CLASS = 30  # repères du protocole, pas des seuils de validité
MIN_SUBJECTS_PER_CLASS = 10
MIN_GROUP_SUPPORT = 20
DATE_PATTERN = re.compile(r"^\d{4}-\d{2}-\d{2}$")


@dataclass
class ValidationReport:
    errors: list[str] = field(default_factory=list)
    warnings: list[str] = field(default_factory=list)
    counts: dict[str, int] = field(default_factory=dict)

    @property
    def ok(self) -> bool:
        return not self.errors


def read_manifest(path: Path) -> list[dict[str, str]]:
    with path.open(newline="", encoding="utf-8") as handle:
        return [{key: (value or "").strip() for key, value in row.items()} for row in csv.DictReader(handle)]


def sha256_of(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1 << 20), b""):
            digest.update(chunk)
    return digest.hexdigest()


def has_gps_metadata(path: Path) -> bool:
    """Vrai si l'image contient des coordonnées GPS dans ses métadonnées EXIF (donnée personnelle)."""
    try:
        with Image.open(path) as image:
            return bool(image.getexif().get_ifd(GPS_IFD))
    except (OSError, UnidentifiedImageError, SyntaxError, ValueError):
        return False


def validate_manifest(
    rows: list[dict[str, str]],
    class_names: list[str],
    root: Path,
    known_hashes: dict[str, str] | None = None,
    known_dhashes: list[tuple[str, int]] | None = None,
    dhash_fn=None,
    max_hamming: int = 2,
) -> ValidationReport:
    """Contrôle le manifeste et les fichiers. Les erreurs bloquent l'évaluation, les avertissements non.

    `known_hashes` : {sha256: chemin} du jeu d'entraînement/validation/test PlantVillage ;
    `known_dhashes` : [(chemin, dhash entier)] et `dhash_fn(image) -> int` pour détecter les quasi-doublons.
    """
    report = ValidationReport()
    if not rows:
        report.errors.append("Manifeste vide.")
        return report
    missing = [column for column in REQUIRED_COLUMNS if column not in rows[0]]
    if missing:
        report.errors.append(f"Colonnes manquantes : {', '.join(missing)}")
        return report

    allowed_labels = set(class_names) | set(OOD_LABELS)
    seen_hashes: dict[str, str] = {}
    subject_splits: dict[str, set[str]] = defaultdict(set)
    per_class_images: Counter[str] = Counter()
    per_class_subjects: dict[str, set[str]] = defaultdict(set)

    for line, row in enumerate(rows, start=2):  # ligne 1 = en-tête
        where = f"ligne {line} ({row['path'] or '?'})"
        for column, allowed in (("split", SPLITS), ("lighting", LIGHTING), ("background", BACKGROUND),
                                ("labeler_expertise", EXPERTISE), ("label_certainty", CERTAINTY)):
            if row[column] not in allowed:
                report.errors.append(f"{where} : {column}='{row[column]}' invalide (choix : {', '.join(allowed)})")
        if row["label"] not in allowed_labels:
            report.errors.append(f"{where} : label '{row['label']}' inconnu (classes du modèle ou {', '.join(OOD_LABELS)})")
        if row["consent"].lower() != "yes":
            report.errors.append(f"{where} : consentement absent (consent doit valoir 'yes')")
        for column in ("subject_id", "site", "device", "labeler", "source"):
            if not row[column]:
                report.errors.append(f"{where} : {column} vide")
        if not DATE_PATTERN.match(row["capture_date"]):
            report.errors.append(f"{where} : capture_date doit être au format AAAA-MM-JJ")
        subject_splits[row["subject_id"]].add(row["split"])
        if row["label"] in set(class_names):
            per_class_images[row["label"]] += 1
            per_class_subjects[row["label"]].add(row["subject_id"])

        file = root / row["path"]
        if not file.is_file():
            report.errors.append(f"{where} : fichier introuvable")
            continue
        try:
            with Image.open(file) as image:
                width, height = image.size
                image.verify()
            if min(width, height) < MIN_SIDE:
                report.errors.append(f"{where} : image trop petite ({width}×{height}, minimum {MIN_SIDE} px)")
            if has_gps_metadata(file):
                report.errors.append(f"{where} : coordonnées GPS dans les métadonnées EXIF — retirer avant usage (vie privée)")
        except (OSError, UnidentifiedImageError, SyntaxError):
            report.errors.append(f"{where} : image illisible ou corrompue")
            continue

        digest = sha256_of(file)
        if digest in seen_hashes:
            report.errors.append(f"{where} : doublon exact de {seen_hashes[digest]}")
        seen_hashes[digest] = row["path"]
        if known_hashes and digest in known_hashes:
            report.errors.append(f"{where} : identique à une image d'entraînement/évaluation PlantVillage ({known_hashes[digest]}) — pas indépendante")
        if known_dhashes and dhash_fn is not None:
            with Image.open(file) as image:
                value = dhash_fn(image)
            near = next((name for name, other in known_dhashes if (value ^ other).bit_count() <= max_hamming), None)
            if near:
                report.errors.append(f"{where} : quasi-doublon d'une image PlantVillage ({near}) — pas indépendante")

    for subject, splits in subject_splits.items():
        if len(splits) > 1:
            report.errors.append(f"subject_id '{subject}' présent dans dev ET test (fuite) : une plante appartient à un seul découpage")

    for name in class_names:
        if per_class_images[name] < MIN_IMAGES_PER_CLASS or len(per_class_subjects[name]) < MIN_SUBJECTS_PER_CLASS:
            report.warnings.append(
                f"{name} : {per_class_images[name]} image(s) de {len(per_class_subjects[name])} plante(s) "
                f"(repère du protocole : {MIN_IMAGES_PER_CLASS} images de {MIN_SUBJECTS_PER_CLASS} plantes) — métriques peu fiables")
    report.counts = {
        "images": len(rows),
        "subjects": len(subject_splits),
        "dev": sum(1 for r in rows if r["split"] == "dev"),
        "test": sum(1 for r in rows if r["split"] == "test"),
        "out_of_distribution": sum(1 for r in rows if r["label"] in OOD_LABELS),
    }
    return report


# ---------------------------------------------------------------- évaluation


def select_rows(rows: list[dict[str, str]], split: str, min_certainty: str = "certain") -> tuple[list[int], int]:
    """Indices des lignes évaluées (découpage demandé, certitude suffisante) et nombre de lignes écartées."""
    order = {"certain": 0, "probable": 1, "uncertain": 2}
    kept = [i for i, r in enumerate(rows) if r["split"] == split and order[r["label_certainty"]] <= order[min_certainty]]
    in_split = sum(1 for r in rows if r["split"] == split)
    return kept, in_split - len(kept)


def macro_f1_present(report: dict) -> float:
    """Macro-F1 sur les classes qui ont au moins une image (une classe absente n'est pas comptée comme 0)."""
    values = [v["f1"] for v in report["per_class"].values() if v["support"] > 0]
    return float(np.mean(values)) if values else 0.0


def cluster_bootstrap(
    y_true: np.ndarray, y_pred: np.ndarray, subjects: np.ndarray, num_classes: int,
    class_names: list[str], resamples: int = 1000, seed: int = 42,
) -> dict[str, list[float]]:
    """Intervalle de confiance à 95 % par rééchantillonnage des PLANTES (les photos d'une même plante sont corrélées)."""
    rng = np.random.default_rng(seed)
    unique = np.unique(subjects)
    members = {s: np.flatnonzero(subjects == s) for s in unique}
    accuracies, f1s = [], []
    for _ in range(resamples):
        chosen = rng.choice(unique, size=len(unique), replace=True)
        idx = np.concatenate([members[s] for s in chosen])
        report = classification_report(confusion_matrix(y_true[idx], y_pred[idx], num_classes), class_names)
        accuracies.append(report["accuracy"])
        f1s.append(macro_f1_present(report))
    low_high = lambda values: [float(np.percentile(values, 2.5)), float(np.percentile(values, 97.5))]
    return {"accuracy_ci95": low_high(accuracies), "macro_f1_ci95": low_high(f1s)}


def breakdown(rows: list[dict[str, str]], indices: list[int], correct: np.ndarray, column: str) -> dict[str, dict]:
    groups: dict[str, list[int]] = defaultdict(list)
    for position, index in enumerate(indices):
        groups[rows[index][column]].append(position)
    result = {}
    for value, positions in sorted(groups.items()):
        hits = int(correct[positions].sum())
        low, high = wilson_interval(hits, len(positions))
        result[value] = {
            "n": len(positions), "accuracy": hits / len(positions), "ci95": [low, high],
            "low_support": len(positions) < MIN_GROUP_SUPPORT,
        }
    return result


def evaluate_field(
    rows: list[dict[str, str]],
    indices: list[int],
    probabilities: np.ndarray,
    class_names: list[str],
    threshold: float | None,
    resamples: int = 1000,
    seed: int = 42,
) -> dict:
    """Métriques sur les images `indices` (probabilités alignées, une ligne par indice)."""
    labels = [rows[i]["label"] for i in indices]
    confidences = probabilities.max(axis=1)
    predicted = probabilities.argmax(axis=1)
    index_of = {name: k for k, name in enumerate(class_names)}
    in_scope = np.array([label in index_of for label in labels])
    result: dict = {"n_images": len(indices), "n_in_scope": int(in_scope.sum()), "n_out_of_distribution": int((~in_scope).sum()),
                    "threshold": threshold}

    if in_scope.any():
        y_true = np.array([index_of[label] for label, keep in zip(labels, in_scope, strict=True) if keep])
        y_pred = predicted[in_scope]
        conf = confidences[in_scope]
        subjects = np.array([rows[i]["subject_id"] for i, keep in zip(indices, in_scope, strict=True) if keep])
        matrix = confusion_matrix(y_true, y_pred, len(class_names))
        report = classification_report(matrix, class_names)
        correct = y_true == y_pred
        result["in_scope"] = {
            "accuracy": report["accuracy"],
            "macro_f1_present_classes": macro_f1_present(report),
            "per_class": report["per_class"],
            "confusion_matrix": matrix.tolist(),
            "mean_confidence_correct": float(conf[correct].mean()) if correct.any() else None,
            "mean_confidence_wrong": float(conf[~correct].mean()) if (~correct).any() else None,
            "bootstrap": cluster_bootstrap(y_true, y_pred, subjects, len(class_names), class_names, resamples, seed),
            "n_subjects": len(np.unique(subjects)),
        }
        if threshold is not None:
            row = selective_curve(conf, correct, np.array([threshold]))[0]
            result["in_scope"]["selective"] = {**row, "per_class_coverage": per_class_coverage(conf, y_true, class_names, threshold)}
        in_scope_positions = [i for i, keep in zip(indices, in_scope, strict=True) if keep]
        result["breakdown"] = {
            column: breakdown(rows, in_scope_positions, correct, column)
            for column in ("lighting", "background", "device", "labeler_expertise", "site")
        }

    if (~in_scope).any():
        ood_conf = confidences[~in_scope]
        accepted = int((ood_conf >= threshold).sum()) if threshold is not None else len(ood_conf)
        low, high = wilson_interval(accepted, len(ood_conf))
        by_label = {}
        for label in OOD_LABELS:
            mask = np.array([lab == label for lab in labels])
            if mask.any():
                values = confidences[mask]
                by_label[label] = {
                    "n": int(mask.sum()),
                    "accepted_at_threshold": int((values >= threshold).sum()) if threshold is not None else int(mask.sum()),
                    "mean_confidence": float(values.mean()),
                }
        result["out_of_distribution"] = {
            "n": len(ood_conf),
            "false_acceptance_rate": accepted / len(ood_conf),  # images hors périmètre auxquelles une classe est quand même proposée
            "false_acceptance_ci95": [low, high],
            "mean_confidence": float(ood_conf.mean()),
            "by_label": by_label,
        }
    return result
