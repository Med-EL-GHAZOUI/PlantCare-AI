"""Évaluation externe du modèle sur des images de terrain (hors PlantVillage).

Règles (docs/FIELD_VALIDATION.md) :
- le manifeste est d'abord validé (consentement, GPS, doublons, fuite) ; une erreur bloque l'évaluation ;
- le seuil de confiance est FIXÉ (0,80, choisi sur la validation PlantVillage) et jamais réglé ici ;
- `--split dev` sert à comprendre les erreurs ; `--split test` exige `--final` et ne s'exécute qu'une fois.

Usage (depuis ml/) :
    .venv\\Scripts\\python.exe scripts/evaluate_external.py --split dev
    .venv\\Scripts\\python.exe scripts/evaluate_external.py --split test --final
"""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
from pathlib import Path

import keras
import numpy as np
from validate_field_manifest import dhash_int, load_reference

from agriscan_ml.config import PreprocessConfig
from agriscan_ml.data import make_dataset
from agriscan_ml.field import OOD_LABELS, evaluate_field, read_manifest, select_rows, validate_manifest


def markdown_report(result: dict, meta: dict, class_names: list[str]) -> str:
    lines = [
        f"# Rapport d'évaluation externe — découpage « {meta['split']} »",
        "",
        f"- Modèle : `{meta['model_version']}` ; seuil de confiance fixé : {meta['threshold']}",
        (f"- Images évaluées : {result['n_images']} (dans le périmètre : {result['n_in_scope']}, hors périmètre : "
         f"{result['n_out_of_distribution']}) ; images écartées (certitude insuffisante) : {meta['excluded']}"),
        "",
    ]
    scope = result.get("in_scope")
    if scope:
        ci = scope["bootstrap"]
        lines += [
            "## Dans le périmètre (10 classes de tomate)",
            "",
            f"- Accuracy : **{scope['accuracy']:.3f}** (IC 95 % par plante [{ci['accuracy_ci95'][0]:.3f} ; {ci['accuracy_ci95'][1]:.3f}], {scope['n_subjects']} plantes)",
            f"- Macro-F1 (classes présentes) : **{scope['macro_f1_present_classes']:.3f}** (IC 95 % [{ci['macro_f1_ci95'][0]:.3f} ; {ci['macro_f1_ci95'][1]:.3f}])",
        ]
        selective = scope.get("selective")
        if selective and selective["accuracy_answered"] is not None:
            low, high = selective["accuracy_ci95"]
            lines.append(f"- Au seuil {meta['threshold']} : couverture {selective['coverage']:.3f}, précision sélective "
                         f"**{selective['accuracy_answered']:.3f}** [{low:.3f} ; {high:.3f}] (IC naïf, sans regroupement par plante)")
        lines += ["", "| Classe | Précision | Rappel | F1 | Images |", "|---|---|---|---|---|"]
        for name in class_names:
            v = scope["per_class"][name]
            lines.append(f"| {name} | {v['precision']:.3f} | {v['recall']:.3f} | {v['f1']:.3f} | {v['support']} |")
        lines += ["", "### Par condition de prise de vue (n < 20 : peu fiable)", ""]
        for column, groups in result["breakdown"].items():
            lines.append(f"**{column}** : " + " ; ".join(
                f"{k} {g['accuracy']:.2f} (n={g['n']}{', peu fiable' if g['low_support'] else ''})" for k, g in groups.items()))
            lines.append("")
    ood = result.get("out_of_distribution")
    if ood:
        low, high = ood["false_acceptance_ci95"]
        lines += [
            "## Hors périmètre (le bon comportement est « incertain »)",
            "",
            (f"- Fausses acceptations : **{ood['false_acceptance_rate']:.3f}** [{low:.3f} ; {high:.3f}] sur {ood['n']} images "
             f"(une classe de tomate est proposée alors qu'aucune ne convient) ; confiance moyenne {ood['mean_confidence']:.3f}"),
        ]
        lines += [f"  - {k} : {v['accepted_at_threshold']}/{v['n']} acceptées" for k, v in ood["by_label"].items()]
    lines += ["", ("> Aide au dépistage : ces chiffres décrivent ce jeu d'images précis ; ne pas les généraliser sans examiner "
                   "la diversité des sites, appareils et conditions (voir le protocole).")]
    return "\n".join(lines) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--manifest", type=Path, default=Path("data/field/manifest.csv"))
    parser.add_argument("--root", type=Path, default=Path("data/field/images"))
    parser.add_argument("--model-dir", type=Path, default=Path("artifacts/mobilenetv2"))
    parser.add_argument("--reference", type=Path, default=Path("data/manifest.csv"))
    parser.add_argument("--split", choices=["dev", "test"], required=True)
    parser.add_argument("--final", action="store_true", help="Requis pour le découpage test")
    parser.add_argument("--threshold", type=float, default=0.80, help="Seuil fixé a priori (validation PlantVillage)")
    parser.add_argument("--min-certainty", choices=["certain", "probable"], default="certain")
    parser.add_argument("--batch-size", type=int, default=32)
    args = parser.parse_args()

    if args.split == "test" and not args.final:
        print("Le découpage test est réservé à l'évaluation finale : ajouter --final en connaissance de cause.", file=sys.stderr)
        return 2
    out_dir = args.model_dir / "field"
    out_json = out_dir / f"field_eval_{args.split}.json"
    if args.split == "test" and out_json.exists():
        print(f"{out_json} existe déjà : l'évaluation test a déjà été faite et ne doit pas être répétée.", file=sys.stderr)
        return 2

    class_names = json.loads((args.model_dir / "class_names.json").read_text(encoding="utf-8"))
    saved = json.loads((args.model_dir / "config.json").read_text(encoding="utf-8"))
    preprocess = PreprocessConfig(image_height=saved["preprocess"]["image_height"], image_width=saved["preprocess"]["image_width"])

    rows = read_manifest(args.manifest)
    known_hashes, known_dhashes = load_reference(args.reference) if args.reference.is_file() else (None, None)
    report = validate_manifest(rows, class_names, args.root, known_hashes, known_dhashes, dhash_int)
    if not report.ok:
        print("Manifeste invalide, évaluation refusée :", file=sys.stderr)
        for message in report.errors[:20]:
            print(f"  - {message}", file=sys.stderr)
        return 1

    indices, excluded = select_rows(rows, args.split, args.min_certainty)
    if not indices:
        print(f"Aucune image évaluable dans le découpage « {args.split} ».", file=sys.stderr)
        return 1
    paths = [str(args.root / rows[i]["path"]) for i in indices]
    dataset = make_dataset(paths, np.zeros(len(paths), dtype=np.int32), preprocess, args.batch_size, training=False)
    model_path = args.model_dir / "model.keras"
    model = keras.models.load_model(model_path)
    probabilities = np.asarray(model.predict(dataset, verbose=0))

    result = evaluate_field(rows, indices, probabilities, class_names, args.threshold)
    model_version = f"{model.name}-{hashlib.sha256(model_path.read_bytes()).hexdigest()[:12]}"
    meta = {"split": args.split, "model_version": model_version, "threshold": args.threshold, "excluded": excluded,
            "min_certainty": args.min_certainty, "ood_labels": list(OOD_LABELS)}
    out_dir.mkdir(parents=True, exist_ok=True)
    out_json.write_text(json.dumps({"meta": meta, **result}, indent=2, ensure_ascii=False), encoding="utf-8")
    (out_dir / f"field_report_{args.split}.md").write_text(markdown_report(result, meta, class_names), encoding="utf-8")
    print(markdown_report(result, meta, class_names))
    print(f"Écrit : {out_json} et field_report_{args.split}.md")
    return 0


if __name__ == "__main__":
    sys.exit(main())
