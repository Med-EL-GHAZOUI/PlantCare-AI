"""Chargement des découpages CSV et construction des pipelines tf.data."""

from __future__ import annotations

import csv
from collections import Counter
from pathlib import Path

import numpy as np
import tensorflow as tf

from agriscan_ml.config import SEED, AugmentationConfig, PreprocessConfig


def read_split(csv_path: Path, image_root: Path) -> tuple[list[str], list[str]]:
    """Lit un CSV de découpage (colonnes path, label) et retourne (chemins absolus, labels texte)."""
    paths: list[str] = []
    labels: list[str] = []
    with csv_path.open(newline="", encoding="utf-8") as handle:
        for row in csv.DictReader(handle):
            paths.append(str(image_root / row["path"]))
            labels.append(row["label"])
    return paths, labels


def class_names_from(labels: list[str]) -> list[str]:
    """Mapping label -> indice figé : ordre alphabétique des classes du jeu d'entraînement."""
    return sorted(set(labels))


def encode_labels(labels: list[str], class_names: list[str]) -> np.ndarray:
    index = {name: i for i, name in enumerate(class_names)}
    unknown = set(labels) - set(index)
    if unknown:
        raise ValueError(f"Classes absentes du mapping : {sorted(unknown)}")
    return np.array([index[label] for label in labels], dtype=np.int32)


def balanced_class_weights(encoded: np.ndarray, num_classes: int) -> dict[int, float]:
    """Poids n_total / (n_classes * n_classe), à calculer sur le jeu d'entraînement uniquement."""
    counts = Counter(int(v) for v in encoded)
    total = len(encoded)
    return {c: total / (num_classes * counts[c]) for c in range(num_classes) if counts[c] > 0}


def decode_and_resize(path: tf.Tensor, config: PreprocessConfig) -> tf.Tensor:
    """Décodage RGB + redimensionnement bilinéaire ; sortie float32 dans [0, 255]."""
    data = tf.io.read_file(path)
    image = tf.io.decode_image(data, channels=config.channels, expand_animations=False)
    image.set_shape([None, None, config.channels])
    image = tf.image.resize(image, config.image_size, method=config.resize_method)
    return tf.cast(image, tf.float32)


def build_augmenter(aug: AugmentationConfig, seed: int = SEED) -> tf.keras.Sequential:
    import keras

    layers = []
    if aug.horizontal_flip or aug.vertical_flip:
        mode = "horizontal_and_vertical" if aug.horizontal_flip and aug.vertical_flip else (
            "horizontal" if aug.horizontal_flip else "vertical")
        layers.append(keras.layers.RandomFlip(mode, seed=seed))
    if aug.rotation_factor:
        layers.append(keras.layers.RandomRotation(aug.rotation_factor, seed=seed))
    if aug.zoom_factor:
        layers.append(keras.layers.RandomZoom(aug.zoom_factor, seed=seed))
    if aug.brightness_factor:
        layers.append(keras.layers.RandomBrightness(aug.brightness_factor, value_range=(0, 255), seed=seed))
    if aug.contrast_factor:
        layers.append(keras.layers.RandomContrast(aug.contrast_factor, seed=seed))
    return keras.Sequential(layers, name="augmentation")


def make_dataset(
    paths: list[str],
    encoded_labels: np.ndarray,
    config: PreprocessConfig,
    batch_size: int,
    training: bool,
    augmentation: AugmentationConfig | None = None,
    seed: int = SEED,
) -> tf.data.Dataset:
    """Pipeline tf.data.

    training=True : mélange (graine fixe) puis augmentation. training=False : ordre conservé,
    aucune transformation aléatoire (validation, test et inférence).
    """
    dataset = tf.data.Dataset.from_tensor_slices((paths, encoded_labels))
    if training:
        dataset = dataset.shuffle(len(paths), seed=seed, reshuffle_each_iteration=True)
    dataset = dataset.map(
        lambda p, y: (decode_and_resize(p, config), y), num_parallel_calls=tf.data.AUTOTUNE, deterministic=not training
    )
    dataset = dataset.batch(batch_size)
    if training and augmentation is not None:
        augmenter = build_augmenter(augmentation, seed)
        dataset = dataset.map(
            lambda x, y: (tf.clip_by_value(augmenter(x, training=True), 0.0, 255.0), y),
            num_parallel_calls=tf.data.AUTOTUNE,
        )
    return dataset.prefetch(tf.data.AUTOTUNE)
