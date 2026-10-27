"""Modèles Keras."""

from __future__ import annotations

import keras

from agriscan_ml.config import PreprocessConfig


def build_baseline(num_classes: int, config: PreprocessConfig, learning_rate: float = 1e-3) -> keras.Model:
    """CNN simple de référence, entraîné de zéro (sans poids pré-entraînés).

    Entrée : images RGB float32 dans [0, 255] ; la normalisation 1/255 est dans le modèle.
    Sortie : probabilités softmax (non calibrées) sur num_classes.
    """
    if num_classes < 2:
        raise ValueError("num_classes doit être >= 2")

    inputs = keras.Input(shape=(*config.image_size, config.channels), name="image")
    x = keras.layers.Rescaling(1.0 / 255, name="rescaling")(inputs)
    for filters in (16, 32, 64):
        x = keras.layers.Conv2D(filters, 3, padding="same", activation="relu")(x)
        x = keras.layers.MaxPooling2D()(x)
    x = keras.layers.GlobalAveragePooling2D()(x)
    x = keras.layers.Dropout(0.3)(x)
    outputs = keras.layers.Dense(num_classes, activation="softmax", name="probabilities")(x)

    model = keras.Model(inputs, outputs, name="baseline_cnn")
    model.compile(
        optimizer=keras.optimizers.Adam(learning_rate),
        loss="sparse_categorical_crossentropy",
        metrics=["accuracy"],
    )
    return model
