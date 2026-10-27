"""Évalue un modèle entraîné sur un découpage et écrit métriques + matrice de confusion.

Par défaut : validation. Le jeu de test est réservé à l'évaluation finale : il exige --final.

Usage (depuis ml/) :
    .venv\\Scripts\\python.exe scripts/evaluate.py --model-dir artifacts/baseline
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
from agriscan_ml.metrics import classification_report, confusion_matrix


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--model-dir", type=Path, default=Path("artifacts/baseline"))
    parser.add_argument("--splits-dir", type=Path, default=Path("data/splits"))
    parser.add_argument("--image-root", type=Path, default=Path("data/raw/plantvillage_tomato"))
    parser.add_argument("--split", choices=["val", "test"], default="val")
    parser.add_argument("--final", action="store_true", help="Requis pour évaluer le jeu de test")
    parser.add_argument("--batch-size", type=int, default=64)
    args = parser.parse_args()

    if args.split == "test" and not args.final:
        raise SystemExit("Le jeu de test est réservé à l'évaluation finale : ajouter --final en connaissance de cause.")

    class_names = json.loads((args.model_dir / "class_names.json").read_text(encoding="utf-8"))
    saved = json.loads((args.model_dir / "config.json").read_text(encoding="utf-8"))
    preprocess = PreprocessConfig(
        image_height=saved["preprocess"]["image_height"], image_width=saved["preprocess"]["image_width"]
    )

    paths, labels = read_split(args.splits_dir / f"{args.split}.csv", args.image_root)
    y_true = encode_labels(labels, class_names)
    dataset = make_dataset(paths, y_true, preprocess, args.batch_size, training=False)

    model = keras.models.load_model(args.model_dir / "model.keras")
    y_pred = np.argmax(model.predict(dataset, verbose=0), axis=1)

    matrix = confusion_matrix(y_true, y_pred, len(class_names))
    report = classification_report(matrix, class_names)
    report["split"] = args.split
    report["model_dir"] = str(args.model_dir)

    out_json = args.model_dir / f"metrics_{args.split}.json"
    out_json.write_text(json.dumps(report, indent=2, ensure_ascii=False), encoding="utf-8")
    out_csv = args.model_dir / f"confusion_{args.split}.csv"
    with out_csv.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.writer(handle)
        writer.writerow(["true\\pred", *class_names])
        for name, row in zip(class_names, matrix.tolist(), strict=True):
            writer.writerow([name, *row])

    print(f"Split : {args.split} ({report['num_samples']} images)")
    print(f"Accuracy : {report['accuracy']:.4f} | macro-F1 : {report['macro_f1']:.4f}")
    for name, values in report["per_class"].items():
        print(f"  {name:48s} P={values['precision']:.3f} R={values['recall']:.3f} "
              f"F1={values['f1']:.3f} n={values['support']}")
    print(f"Écrit : {out_json}, {out_csv}")


if __name__ == "__main__":
    main()
