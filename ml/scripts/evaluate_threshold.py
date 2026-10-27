"""Évalue un seuil de confiance DÉJÀ FIXÉ sur le jeu de test (évaluation finale, exige --final).

Le seuil est un argument obligatoire : il ne doit pas être ajusté à partir de ces résultats.

Usage (depuis ml/) :
    .venv\\Scripts\\python.exe scripts/evaluate_threshold.py --threshold 0.80 --final
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

import keras
import numpy as np

from agriscan_ml.config import PreprocessConfig
from agriscan_ml.data import encode_labels, make_dataset, read_split
from agriscan_ml.selective import per_class_coverage, selective_curve


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--model-dir", type=Path, default=Path("artifacts/mobilenetv2"))
    parser.add_argument("--splits-dir", type=Path, default=Path("data/splits"))
    parser.add_argument("--image-root", type=Path, default=Path("data/raw/plantvillage_tomato"))
    parser.add_argument("--threshold", type=float, required=True, help="Seuil fixé a priori sur la validation")
    parser.add_argument("--final", action="store_true", help="Requis : confirme l'évaluation finale sur le test")
    parser.add_argument("--batch-size", type=int, default=64)
    args = parser.parse_args()

    if not args.final:
        raise SystemExit("Le jeu de test est réservé à l'évaluation finale : ajouter --final en connaissance de cause.")
    out_path = args.model_dir / "threshold_test.json"
    if out_path.exists():
        raise SystemExit(f"{out_path} existe déjà : l'évaluation test a déjà été faite et ne doit pas être répétée.")

    class_names = json.loads((args.model_dir / "class_names.json").read_text(encoding="utf-8"))
    saved = json.loads((args.model_dir / "config.json").read_text(encoding="utf-8"))
    preprocess = PreprocessConfig(
        image_height=saved["preprocess"]["image_height"], image_width=saved["preprocess"]["image_width"])

    paths, labels = read_split(args.splits_dir / "test.csv", args.image_root)
    y_true = encode_labels(labels, class_names)
    dataset = make_dataset(paths, y_true, preprocess, args.batch_size, training=False)
    probabilities = keras.models.load_model(args.model_dir / "model.keras").predict(dataset, verbose=0)

    confidences = probabilities.max(axis=1)
    correct = probabilities.argmax(axis=1) == y_true
    row = selective_curve(confidences, correct, np.array([args.threshold]))[0]
    rejected = ~(confidences >= args.threshold)
    report = {
        "split": "test", "n_samples": len(y_true), "threshold": args.threshold,
        "accuracy_no_threshold": float(correct.mean()),
        "coverage": row["coverage"], "n_answered": row["n_answered"],
        "accuracy_answered": row["accuracy_answered"], "accuracy_ci95": row["accuracy_ci95"],
        "errors_answered": row["errors_answered"],
        "errors_total": int((~correct).sum()),
        "errors_among_rejected": int((~correct & rejected).sum()),
        "n_rejected": int(rejected.sum()),
        "accuracy_among_rejected": float(correct[rejected].mean()) if rejected.any() else None,
        "per_class_coverage": per_class_coverage(confidences, y_true, class_names, args.threshold),
    }
    out_path.write_text(json.dumps(report, indent=2, ensure_ascii=False), encoding="utf-8")

    ci = report["accuracy_ci95"]
    print(f"Test : {len(y_true)} images, seuil fixé = {args.threshold}")
    print(f"Accuracy sans seuil : {report['accuracy_no_threshold']:.4f} ({report['errors_total']} erreurs)")
    print(f"Couverture : {report['coverage']:.4f} ({report['n_answered']} répondues, {report['n_rejected']} incertaines)")
    print(f"Précision sélective : {report['accuracy_answered']:.4f} [IC95 {ci[0]:.3f} ; {ci[1]:.3f}], "
          f"{report['errors_answered']} erreurs gardées")
    print(f"Parmi les incertaines : {report['errors_among_rejected']} erreurs sur {report['n_rejected']} "
          f"(accuracy {report['accuracy_among_rejected']:.4f})")
    for name, values in report["per_class_coverage"].items():
        print(f"  {name:48s} {values['answered']}/{values['support']} = {values['coverage']:.3f}")
    print(f"Écrit : {out_path}")


if __name__ == "__main__":
    main()
