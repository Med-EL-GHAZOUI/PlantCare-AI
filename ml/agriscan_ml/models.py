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
    compile_model(model, learning_rate)
    return model


def compile_model(model: keras.Model, learning_rate: float) -> None:
    model.compile(
        optimizer=keras.optimizers.Adam(learning_rate),
        loss="sparse_categorical_crossentropy",
        metrics=["accuracy"],
    )


BACKBONE_NAME = "mobilenetv2_backbone"


def build_mobilenetv2(
    num_classes: int,
    config: PreprocessConfig,
    weights: str | None = "imagenet",
    learning_rate: float = 1e-3,
) -> keras.Model:
    """MobileNetV2 en transfer learning, base gelée (phase 1 : entraînement de la tête seule).

    Entrée : images RGB float32 dans [0, 255]. MobileNetV2 attend [-1, 1] : la conversion
    x/127.5 - 1 est faite DANS le modèle (couche Rescaling), comme pour la baseline.
    weights=None sert uniquement aux tests hors-ligne ; l'entraînement réel utilise "imagenet".
    """
    if num_classes < 2:
        raise ValueError("num_classes doit être >= 2")

    backbone = keras.applications.MobileNetV2(
        input_shape=(*config.image_size, config.channels), include_top=False, weights=weights, name=BACKBONE_NAME
    )
    backbone.trainable = False

    inputs = keras.Input(shape=(*config.image_size, config.channels), name="image")
    x = keras.layers.Rescaling(1.0 / 127.5, offset=-1.0, name="rescaling")(inputs)
    x = backbone(x, training=False)  # BatchNorm en mode inférence, y compris pendant le fine-tuning
    x = keras.layers.GlobalAveragePooling2D()(x)
    x = keras.layers.Dropout(0.3)(x)
    outputs = keras.layers.Dense(num_classes, activation="softmax", name="probabilities")(x)

    model = keras.Model(inputs, outputs, name="mobilenetv2_classifier")
    compile_model(model, learning_rate)
    return model


def unfreeze_for_finetuning(model: keras.Model, num_layers: int, learning_rate: float = 1e-5) -> int:
    """Dégèle les `num_layers` dernières couches du backbone (hors BatchNorm) et recompile
    avec un taux d'apprentissage faible. Retourne le nombre de couches réellement dégelées."""
    if num_layers < 1:
        raise ValueError("num_layers doit être >= 1")
    backbone = model.get_layer(BACKBONE_NAME)
    backbone.trainable = True
    for layer in backbone.layers[:-num_layers]:
        layer.trainable = False
    unfrozen = 0
    for layer in backbone.layers[-num_layers:]:
        if isinstance(layer, keras.layers.BatchNormalization):
            layer.trainable = False
        else:
            unfrozen += 1
    compile_model(model, learning_rate)  # obligatoire après un changement de `trainable`
    return unfrozen
