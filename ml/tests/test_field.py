"""Validation du manifeste terrain et métriques externes, sur données synthétiques."""

import csv
from pathlib import Path

import numpy as np
import pytest
from inspect_dataset import dhash_of
from PIL import Image

from agriscan_ml.field import (
    REQUIRED_COLUMNS,
    breakdown,
    cluster_bootstrap,
    evaluate_field,
    has_gps_metadata,
    macro_f1_present,
    read_manifest,
    select_rows,
    validate_manifest,
)
from agriscan_ml.metrics import classification_report, confusion_matrix

CLASSES = ["a", "b", "c"]


def write_image(path: Path, seed: int, size: tuple[int, int] = (120, 100), exif=None) -> None:
    rng = np.random.default_rng(seed)
    path.parent.mkdir(parents=True, exist_ok=True)
    image = Image.fromarray(rng.integers(0, 256, (size[1], size[0], 3), dtype=np.uint8))
    image.save(path, "JPEG", exif=exif) if exif else image.save(path, "JPEG")


def make_row(name: str, **overrides) -> dict[str, str]:
    row = {
        "path": name, "label": "a", "subject_id": f"plant-{name}", "split": "dev", "site": "serre-1",
        "capture_date": "2026-11-05", "device": "phone-x", "lighting": "shade", "background": "plain",
        "labeler": "expert-1", "labeler_expertise": "agronomist", "label_certainty": "certain",
        "consent": "yes", "source": "photos prises par l'équipe",
    }
    row.update(overrides)
    return row


@pytest.fixture
def field_dir(tmp_path: Path) -> Path:
    for seed, name in enumerate(["1.jpg", "2.jpg", "3.jpg"]):
        write_image(tmp_path / name, seed)
    return tmp_path


def errors_of(rows, root, **kwargs) -> list[str]:
    return validate_manifest(rows, CLASSES, root, **kwargs).errors


# ---------- validation du manifeste ----------

def test_valid_manifest_has_no_error_but_warns_about_small_classes(field_dir) -> None:
    report = validate_manifest([make_row("1.jpg"), make_row("2.jpg", label="b"), make_row("3.jpg", label="c")], CLASSES, field_dir)
    assert report.ok and report.counts["images"] == 3
    assert any("métriques peu fiables" in w for w in report.warnings)


def test_missing_columns_and_empty_manifest(field_dir) -> None:
    assert "Manifeste vide" in errors_of([], field_dir)[0]
    incomplete = [{key: "x" for key in REQUIRED_COLUMNS if key != "consent"}]
    assert "consent" in errors_of(incomplete, field_dir)[0]


@pytest.mark.parametrize(("override", "expected"), [
    ({"consent": "no"}, "consentement"),
    ({"consent": ""}, "consentement"),
    ({"label": "inconnue"}, "label"),
    ({"split": "train"}, "split"),
    ({"lighting": "disco"}, "lighting"),
    ({"background": "x"}, "background"),
    ({"labeler_expertise": "chef"}, "labeler_expertise"),
    ({"label_certainty": "maybe"}, "label_certainty"),
    ({"capture_date": "05/11/2026"}, "capture_date"),
    ({"subject_id": ""}, "subject_id"),
    ({"device": ""}, "device"),
    ({"source": ""}, "source"),
])
def test_invalid_values_are_reported(field_dir, override, expected) -> None:
    assert any(expected in e for e in errors_of([make_row("1.jpg", **override)], field_dir))


def test_out_of_distribution_labels_are_accepted(field_dir) -> None:
    rows = [make_row("1.jpg", label="out_of_scope"), make_row("2.jpg", label="other_disease")]
    assert errors_of(rows, field_dir) == []


def test_missing_corrupt_and_tiny_files_are_reported(field_dir) -> None:
    (field_dir / "broken.jpg").write_bytes(b"pas une image")
    write_image(field_dir / "tiny.jpg", 9, size=(20, 20))
    errors = errors_of([make_row("absent.jpg"), make_row("broken.jpg"), make_row("tiny.jpg")], field_dir)
    assert any("introuvable" in e for e in errors)
    assert any("illisible" in e for e in errors)
    assert any("trop petite" in e for e in errors)


def test_gps_metadata_is_rejected_for_privacy(field_dir) -> None:
    exif = Image.Exif()
    exif[0x8825] = {1: "N", 2: (34.0, 1.0, 2.0), 3: "W", 4: (6.0, 3.0, 4.0)}
    write_image(field_dir / "gps.jpg", 5, exif=exif)
    assert has_gps_metadata(field_dir / "gps.jpg") is True
    assert has_gps_metadata(field_dir / "1.jpg") is False
    assert any("GPS" in e for e in errors_of([make_row("gps.jpg")], field_dir))


def test_exact_duplicates_inside_the_set_are_reported(field_dir) -> None:
    (field_dir / "copy.jpg").write_bytes((field_dir / "1.jpg").read_bytes())
    errors = errors_of([make_row("1.jpg"), make_row("copy.jpg")], field_dir)
    assert any("doublon exact" in e for e in errors)


def test_images_from_plantvillage_are_rejected_as_not_independent(field_dir) -> None:
    from agriscan_ml.field import sha256_of

    leaked = sha256_of(field_dir / "1.jpg")
    errors = errors_of([make_row("1.jpg")], field_dir, known_hashes={leaked: "Tomato___x/1.jpg"})
    assert any("identique" in e and "PlantVillage" in e for e in errors)

    with Image.open(field_dir / "2.jpg") as image:
        near = [("Tomato___y/2.jpg", int(dhash_of(image), 16) ^ 0b11)]  # 2 bits d'écart
    errors = errors_of([make_row("2.jpg")], field_dir, known_dhashes=near, dhash_fn=lambda im: int(dhash_of(im), 16))
    assert any("quasi-doublon" in e for e in errors)
    far = [("Tomato___z/3.jpg", int(dhash_of(Image.open(field_dir / "2.jpg")), 16) ^ ((1 << 20) - 1))]
    assert errors_of([make_row("2.jpg")], field_dir, known_dhashes=far, dhash_fn=lambda im: int(dhash_of(im), 16)) == []


def test_a_plant_cannot_be_in_both_dev_and_test(field_dir) -> None:
    rows = [make_row("1.jpg", subject_id="p1", split="dev"), make_row("2.jpg", subject_id="p1", split="test")]
    assert any("dev ET test" in e for e in errors_of(rows, field_dir))


def test_read_manifest_strips_whitespace(tmp_path) -> None:
    path = tmp_path / "m.csv"
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(make_row("x").keys()))
        writer.writeheader()
        writer.writerow(make_row(" 1.jpg ", label=" a "))
    row = read_manifest(path)[0]
    assert row["path"] == "1.jpg" and row["label"] == "a"


# ---------- sélection et métriques ----------

def make_rows(labels, subjects=None, **overrides):
    return [make_row(f"{i}.jpg", label=label, subject_id=(subjects[i] if subjects else f"p{i}"), **overrides)
            for i, label in enumerate(labels)]


def one_hot(predictions, num=3, confidence=0.9):
    probabilities = np.full((len(predictions), num), (1 - confidence) / (num - 1))
    for i, p in enumerate(predictions):
        probabilities[i, p] = confidence
    return probabilities


def test_select_rows_by_split_and_certainty() -> None:
    rows = [make_row("0.jpg"), make_row("1.jpg", label_certainty="probable"), make_row("2.jpg", label_certainty="uncertain"),
            make_row("3.jpg", split="test")]
    assert select_rows(rows, "dev", "certain") == ([0], 2)
    assert select_rows(rows, "dev", "probable") == ([0, 1], 1)
    assert select_rows(rows, "test") == ([3], 0)


def test_in_scope_metrics_match_hand_computation() -> None:
    rows = make_rows(["a", "a", "a", "b", "b", "c"])
    probabilities = one_hot([0, 0, 1, 1, 1, 2])  # 1 erreur sur 6 (a prédit b)
    result = evaluate_field(rows, list(range(6)), probabilities, CLASSES, threshold=0.8, resamples=50)
    scope = result["in_scope"]
    assert scope["accuracy"] == pytest.approx(5 / 6)
    assert scope["per_class"]["a"]["recall"] == pytest.approx(2 / 3)
    assert scope["per_class"]["b"]["precision"] == pytest.approx(2 / 3)
    assert scope["confusion_matrix"][0] == [2, 1, 0]
    assert scope["mean_confidence_wrong"] == pytest.approx(0.9)
    assert result["n_out_of_distribution"] == 0 and "out_of_distribution" not in result


def test_macro_f1_ignores_classes_without_images() -> None:
    matrix = confusion_matrix(np.array([0, 0, 1]), np.array([0, 0, 1]), 3)  # classe c absente
    report = classification_report(matrix, CLASSES)
    assert report["macro_f1"] < 1.0 and macro_f1_present(report) == pytest.approx(1.0)


def test_selective_accuracy_and_coverage_at_fixed_threshold() -> None:
    rows = make_rows(["a", "a", "b", "b"])
    probabilities = np.array([[0.95, 0.03, 0.02], [0.60, 0.30, 0.10], [0.1, 0.85, 0.05], [0.5, 0.3, 0.2]])
    result = evaluate_field(rows, [0, 1, 2, 3], probabilities, CLASSES, threshold=0.8, resamples=20)
    selective = result["in_scope"]["selective"]
    assert selective["n_answered"] == 2 and selective["coverage"] == 0.5
    assert selective["accuracy_answered"] == 1.0  # les deux réponses gardées sont justes


def test_out_of_distribution_false_acceptance() -> None:
    rows = make_rows(["a", "out_of_scope", "out_of_scope", "other_disease", "other_disease"])
    probabilities = np.array([
        [0.9, 0.05, 0.05],   # a, juste
        [0.95, 0.03, 0.02],  # hors périmètre accepté à tort
        [0.40, 0.35, 0.25],  # hors périmètre correctement incertain
        [0.99, 0.005, 0.005],  # autre maladie acceptée à tort
        [0.34, 0.33, 0.33],  # incertain
    ])
    ood = evaluate_field(rows, list(range(5)), probabilities, CLASSES, threshold=0.8, resamples=20)["out_of_distribution"]
    assert ood["n"] == 4 and ood["false_acceptance_rate"] == pytest.approx(0.5)
    assert ood["by_label"]["out_of_scope"] == {"n": 2, "accepted_at_threshold": 1, "mean_confidence": pytest.approx(0.675)}
    assert ood["by_label"]["other_disease"]["accepted_at_threshold"] == 1
    assert ood["false_acceptance_ci95"][0] < 0.5 < ood["false_acceptance_ci95"][1]


def test_only_out_of_distribution_images() -> None:
    rows = make_rows(["out_of_scope", "out_of_scope"])
    result = evaluate_field(rows, [0, 1], one_hot([0, 1]), CLASSES, threshold=0.8, resamples=10)
    assert "in_scope" not in result and result["out_of_distribution"]["false_acceptance_rate"] == 1.0


def test_cluster_bootstrap_is_deterministic_and_resamples_plants() -> None:
    rng = np.random.default_rng(0)
    y_true = rng.integers(0, 3, 90)
    y_pred = np.where(rng.random(90) < 0.8, y_true, (y_true + 1) % 3)
    subjects = np.repeat(np.arange(30), 3)  # 30 plantes, 3 photos chacune
    first = cluster_bootstrap(y_true, y_pred, subjects, 3, CLASSES, resamples=200, seed=42)
    again = cluster_bootstrap(y_true, y_pred, subjects, 3, CLASSES, resamples=200, seed=42)
    assert first == again
    accuracy = float((y_true == y_pred).mean())
    low, high = first["accuracy_ci95"]
    assert low <= accuracy <= high and high - low > 0.02
    # Peu de plantes => intervalle plus large qu'avec beaucoup de plantes à effectif égal
    few = cluster_bootstrap(y_true, y_pred, np.repeat(np.arange(6), 15), 3, CLASSES, resamples=200, seed=42)["accuracy_ci95"]
    assert (few[1] - few[0]) > (high - low)


def test_breakdown_flags_low_support_groups() -> None:
    rows = [make_row(f"{i}.jpg", lighting="full_sun" if i < 25 else "shade") for i in range(30)]
    correct = np.array([True] * 20 + [False] * 5 + [True] * 5)
    groups = breakdown(rows, list(range(30)), correct, "lighting")
    assert groups["full_sun"]["n"] == 25 and groups["full_sun"]["accuracy"] == pytest.approx(0.8)
    assert groups["full_sun"]["low_support"] is False
    assert groups["shade"]["n"] == 5 and groups["shade"]["low_support"] is True


def test_strip_exif_removes_gps_without_touching_the_source(field_dir) -> None:
    from strip_exif import strip

    exif = Image.Exif()
    exif[0x8825] = {1: "N", 2: (34.0, 1.0, 2.0), 3: "W", 4: (6.0, 3.0, 4.0)}
    source = field_dir / "with_gps.jpg"
    write_image(source, 11, exif=exif)
    before = source.read_bytes()

    cleaned = field_dir / "clean" / "with_gps.jpg"
    strip(source, cleaned)

    assert has_gps_metadata(source) is True and source.read_bytes() == before  # original intact
    assert has_gps_metadata(cleaned) is False
    with Image.open(source) as a, Image.open(cleaned) as b:
        assert a.size == b.size
        difference = np.abs(np.asarray(a.convert("RGB")).astype(int) - np.asarray(b.convert("RGB")).astype(int)).mean()
    assert difference < 12  # recompression JPEG d'un bruit aléatoire (pire cas) : écart moyen faible
    assert errors_of([make_row("clean/with_gps.jpg")], field_dir) == []
