"""Entraîne la baseline CNN. Sans --train, ne fait qu'un contrôle à blanc (--dry-run implicite).

Contrôle à blanc (aucun entraînement) :
    .venv\\Scripts\\python.exe scripts/train_baseline.py

Entraînement réel (à ne lancer qu'après validation) :
    .venv\\Scripts\\python.exe scripts/train_baseline.py --train --epochs 15
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

import keras
import tensorflow as tf

from agriscan_ml.config import SEED, AugmentationConfig, PreprocessConfig
from agriscan_ml.data import balanced_class_weights, class_names_from, encode_labels, make_dataset, read_split
from agriscan_ml.models import build_baseline


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--splits-dir", type=Path, default=Path("data/splits"))
    parser.add_argument("--image-root", type=Path, default=Path("data/raw/plantvillage_tomato"))
    parser.add_argument("--out-dir", type=Path, default=Path("artifacts/baseline"))
    parser.add_argument("--batch-size", type=int, default=32)
    parser.add_argument("--epochs", type=int, default=15)
    parser.add_argument("--train", action="store_true", help="Lance réellement l'entraînement")
    args = parser.parse_args()

    keras.utils.set_random_seed(SEED)
    preprocess, augmentation = PreprocessConfig(), AugmentationConfig()

    train_paths, train_labels = read_split(args.splits_dir / "train.csv", args.image_root)
    val_paths, val_labels = read_split(args.splits_dir / "val.csv", args.image_root)
    class_names = class_names_from(train_labels)
    y_train = encode_labels(train_labels, class_names)
    y_val = encode_labels(val_labels, class_names)

    train_ds = make_dataset(train_paths, y_train, preprocess, args.batch_size, True, augmentation)
    val_ds = make_dataset(val_paths, y_val, preprocess, args.batch_size, False)
    model = build_baseline(len(class_names), preprocess)

    images, labels = next(iter(train_ds))
    print(f"Classes ({len(class_names)}): {class_names}")
    print(f"Train {len(train_paths)} / Val {len(val_paths)} images")
    print(f"Lot d'entraînement : {images.shape} {images.dtype}, min={float(tf.reduce_min(images)):.1f} "
          f"max={float(tf.reduce_max(images)):.1f}, labels={labels.shape}")
    print(f"Paramètres du modèle : {model.count_params()}")

    if not args.train:
        print("Contrôle à blanc terminé : aucun entraînement lancé (utiliser --train).")
        return

    args.out_dir.mkdir(parents=True, exist_ok=True)
    (args.out_dir / "class_names.json").write_text(json.dumps(class_names, indent=2), encoding="utf-8")
    (args.out_dir / "config.json").write_text(
        json.dumps({"seed": SEED, "preprocess": preprocess.as_dict(), "augmentation": augmentation.as_dict(),
                    "batch_size": args.batch_size, "epochs": args.epochs}, indent=2), encoding="utf-8")
    history = model.fit(
        train_ds,
        validation_data=val_ds,
        epochs=args.epochs,
        class_weight=balanced_class_weights(y_train, len(class_names)),
        callbacks=[keras.callbacks.EarlyStopping(monitor="val_loss", patience=3, restore_best_weights=True)],
    )
    model.save(args.out_dir / "model.keras")
    (args.out_dir / "history.json").write_text(json.dumps(history.history, indent=2), encoding="utf-8")


if __name__ == "__main__":
    main()
