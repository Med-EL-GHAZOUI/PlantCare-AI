"""Courbe précision/couverture selon le seuil de confiance, calculée sur la VALIDATION uniquement.

Le jeu de test n'est jamais lu par ce script (aucune option pour le choisir).

Usage (depuis ml/) :
    .venv\\Scripts\\python.exe scripts/threshold_analysis.py --model-dir artifacts/mobilenetv2
"""

from __future__ import annotations

import argparse
import csv
import json
from pathlib import Path

import keras
import numpy as np

from agriscan_ml.config import PreprocessConfig
from agriscan_ml.data import encode_labels, make_dataset, read_split
from agriscan_ml.selective import choose_threshold, per_class_coverage, selective_curve

TARGETS = (0.95, 0.97, 0.98, 0.99)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--model-dir", type=Path, default=Path("artifacts/mobilenetv2"))
    parser.add_argument("--splits-dir", type=Path, default=Path("data/splits"))
    parser.add_argument("--image-root", type=Path, default=Path("data/raw/plantvillage_tomato"))
    parser.add_argument("--target-accuracy", type=float, default=0.97, help="Précision sélective visée")
    parser.add_argument("--min-coverage", type=float, default=0.80, help="Couverture minimale acceptable")
    parser.add_argument("--batch-size", type=int, default=64)
    args = parser.parse_args()

    class_names = json.loads((args.model_dir / "class_names.json").read_text(encoding="utf-8"))
    saved = json.loads((args.model_dir / "config.json").read_text(encoding="utf-8"))
    preprocess = PreprocessConfig(
        image_height=saved["preprocess"]["image_height"], image_width=saved["preprocess"]["image_width"])

    paths, labels = read_split(args.splits_dir / "val.csv", args.image_root)
    y_true = encode_labels(labels, class_names)
    dataset = make_dataset(paths, y_true, preprocess, args.batch_size, training=False)
    model = keras.models.load_model(args.model_dir / "model.keras")
    probabilities = model.predict(dataset, verbose=0)

    confidences = probabilities.max(axis=1)
    correct = probabilities.argmax(axis=1) == y_true
    thresholds = np.round(np.arange(0.0, 1.0, 0.01), 2)
    curve = selective_curve(confidences, correct, thresholds)

    with (args.model_dir / "threshold_curve_val.csv").open("w", newline="", encoding="utf-8") as handle:
        writer = csv.writer(handle)
        writer.writerow(["threshold", "n_answered", "coverage", "accuracy_answered", "ci95_low", "ci95_high"])
        for row in curve:
            ci = row["accuracy_ci95"] or ["", ""]
            writer.writerow([row["threshold"], row["n_answered"], f"{row['coverage']:.4f}",
                             "" if row["accuracy_answered"] is None else f"{row['accuracy_answered']:.4f}", *ci])

    options = {}
    for target in TARGETS:
        row = choose_threshold(curve, target)
        options[str(target)] = row
    chosen = choose_threshold(curve, args.target_accuracy, args.min_coverage)
    summary = {
        "split": "val", "n_samples": len(y_true),
        "overall_accuracy_no_threshold": float(correct.mean()),
        "rule": f"plus petit seuil (grille 0,01) avec précision sélective >= {args.target_accuracy} "
                f"et couverture >= {args.min_coverage}",
        "chosen": chosen,
        "alternatives_by_target_accuracy": options,
        "per_class_coverage_at_chosen": (
            per_class_coverage(confidences, y_true, class_names, chosen["threshold"]) if chosen else None),
    }
    (args.model_dir / "threshold_val.json").write_text(json.dumps(summary, indent=2, ensure_ascii=False),
                                                       encoding="utf-8")

    print(f"Validation : {len(y_true)} images, accuracy sans seuil = {correct.mean():.4f}")
    print("seuil | couverture | précision sélective [IC95 %] | erreurs gardées")
    for threshold in (0.0, 0.5, 0.6, 0.7, 0.8, 0.85, 0.9, 0.95, 0.98, 0.99):
        row = next(r for r in curve if abs(r["threshold"] - threshold) < 1e-9)
        ci = row["accuracy_ci95"]
        print(f" {threshold:.2f} |   {row['coverage']:.3f}   | {row['accuracy_answered']:.4f} "
              f"[{ci[0]:.3f}, {ci[1]:.3f}] | {row['errors_answered']}")
    print("\nSeuil minimal par précision visée (sans contrainte de couverture) :")
    for target, row in options.items():
        print(f"  >= {target}: " + ("aucun" if row is None else
              f"seuil {row['threshold']:.2f}, couverture {row['coverage']:.3f}, précision {row['accuracy_answered']:.4f}"))
    print(f"\nRègle retenue : {summary['rule']}")
    if chosen is None:
        print("Aucun seuil ne satisfait la règle.")
        return
    print(f"=> seuil {chosen['threshold']:.2f} : couverture {chosen['coverage']:.3f}, "
          f"précision {chosen['accuracy_answered']:.4f}, IC95 [{chosen['accuracy_ci95'][0]:.3f}, "
          f"{chosen['accuracy_ci95'][1]:.3f}]")
    print("Couverture par classe au seuil retenu :")
    for name, values in summary["per_class_coverage_at_chosen"].items():
        print(f"  {name:48s} {values['answered']}/{values['support']} = {values['coverage']:.3f}")


if __name__ == "__main__":
    main()
