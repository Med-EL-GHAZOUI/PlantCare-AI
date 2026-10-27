"""Entraîne MobileNetV2 en deux phases : tête seule (base gelée) puis fine-tuning partiel.

Sans --train, effectue seulement un contrôle à blanc. Le téléchargement des poids ImageNet
(Keras, ~9 Mo) a lieu à la construction du modèle avec weights="imagenet".

    .venv\\Scripts\\python.exe scripts/train_mobilenet.py --train
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

import keras

from agriscan_ml.config import SEED, AugmentationConfig, PreprocessConfig
from agriscan_ml.data import balanced_class_weights, class_names_from, encode_labels, make_dataset, read_split
from agriscan_ml.models import build_mobilenetv2, unfreeze_for_finetuning


def early_stopping(patience: int) -> keras.callbacks.EarlyStopping:
    return keras.callbacks.EarlyStopping(monitor="val_loss", patience=patience, restore_best_weights=True)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--splits-dir", type=Path, default=Path("data/splits"))
    parser.add_argument("--image-root", type=Path, default=Path("data/raw/plantvillage_tomato"))
    parser.add_argument("--out-dir", type=Path, default=Path("artifacts/mobilenetv2"))
    parser.add_argument("--batch-size", type=int, default=32)
    parser.add_argument("--head-epochs", type=int, default=6)
    parser.add_argument("--head-lr", type=float, default=1e-3)
    parser.add_argument("--finetune-epochs", type=int, default=10)
    parser.add_argument("--finetune-lr", type=float, default=1e-5)
    parser.add_argument("--finetune-layers", type=int, default=30)
    parser.add_argument("--train", action="store_true", help="Lance réellement l'entraînement")
    args = parser.parse_args()

    keras.utils.set_random_seed(SEED)
    preprocess = PreprocessConfig(image_height=224, image_width=224)
    augmentation = AugmentationConfig()

    train_paths, train_labels = read_split(args.splits_dir / "train.csv", args.image_root)
    val_paths, val_labels = read_split(args.splits_dir / "val.csv", args.image_root)
    class_names = class_names_from(train_labels)
    y_train = encode_labels(train_labels, class_names)
    y_val = encode_labels(val_labels, class_names)

    train_ds = make_dataset(train_paths, y_train, preprocess, args.batch_size, True, augmentation)
    val_ds = make_dataset(val_paths, y_val, preprocess, args.batch_size, False)
    model = build_mobilenetv2(len(class_names), preprocess, weights="imagenet", learning_rate=args.head_lr)
    print(f"Paramètres : {model.count_params()} (entraînables : {sum(w.shape.num_elements() for w in model.trainable_weights)})")

    if not args.train:
        print("Contrôle à blanc terminé : aucun entraînement lancé (utiliser --train).")
        return

    args.out_dir.mkdir(parents=True, exist_ok=True)
    (args.out_dir / "class_names.json").write_text(json.dumps(class_names, indent=2), encoding="utf-8")
    (args.out_dir / "config.json").write_text(
        json.dumps({"seed": SEED, "preprocess": preprocess.as_dict(), "augmentation": augmentation.as_dict(),
                    "batch_size": args.batch_size, "backbone": "MobileNetV2 (ImageNet)",
                    "head_epochs": args.head_epochs, "head_lr": args.head_lr,
                    "finetune_epochs": args.finetune_epochs, "finetune_lr": args.finetune_lr,
                    "finetune_layers": args.finetune_layers}, indent=2), encoding="utf-8")

    weights = balanced_class_weights(y_train, len(class_names))
    head = model.fit(train_ds, validation_data=val_ds, epochs=args.head_epochs, class_weight=weights,
                     callbacks=[early_stopping(2)])
    unfrozen = unfreeze_for_finetuning(model, args.finetune_layers, args.finetune_lr)
    print(f"Fine-tuning : {unfrozen} couches dégelées (hors BatchNorm), lr={args.finetune_lr}")
    fine = model.fit(train_ds, validation_data=val_ds, epochs=args.finetune_epochs, class_weight=weights,
                     callbacks=[early_stopping(3)])

    model.save(args.out_dir / "model.keras")
    (args.out_dir / "history.json").write_text(
        json.dumps({"head": head.history, "finetune": fine.history}, indent=2), encoding="utf-8")


if __name__ == "__main__":
    main()
