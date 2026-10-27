"""Chargement unique du modèle et inférence réelle.

Le prétraitement reproduit celui de l'entraînement (ml/agriscan_ml/data.py::decode_and_resize) :
RGB, redimensionnement bilinéaire tf.image.resize vers la taille du modèle, float32 dans [0, 255].
La mise à l'échelle des pixels est incluse dans le modèle.
"""

from __future__ import annotations

import hashlib
import json
import logging
import threading
import uuid
from dataclasses import dataclass
from pathlib import Path

import numpy as np

logger = logging.getLogger("agriscan.inference")

PREPROCESSING_SUMMARY = "RGB, redimensionnement bilinéaire, pixels float32 [0, 255] ; mise à l'échelle dans le modèle"


@dataclass(frozen=True)
class Prediction:
    prediction_id: str
    class_scores: dict[str, float]
    top_class: str
    top_score: float


class ModelUnavailableError(RuntimeError):
    pass


class ModelService:
    """Charge le modèle une seule fois ; l'inférence est sérialisée par un verrou."""

    def __init__(self, model_dir: Path) -> None:
        import keras  # import tardif : l'API démarre même si TensorFlow est indisponible

        self.model_dir = Path(model_dir)
        model_path = self.model_dir / "model.keras"
        self.class_names: list[str] = json.loads((self.model_dir / "class_names.json").read_text(encoding="utf-8"))
        saved = json.loads((self.model_dir / "config.json").read_text(encoding="utf-8"))
        self.input_height = int(saved["preprocess"]["image_height"])
        self.input_width = int(saved["preprocess"]["image_width"])
        self.model = keras.models.load_model(model_path, compile=False)
        self.model_version = f"{self.model.name}-{_sha256_prefix(model_path)}"
        if self.model.output_shape[-1] != len(self.class_names):
            raise ValueError("Le nombre de classes du modèle ne correspond pas à class_names.json")
        self._lock = threading.Lock()
        self.predict(np.zeros((self.input_height, self.input_width, 3), dtype=np.uint8))  # préchauffage
        logger.info("Modèle chargé : %s", self.model_version)

    def preprocess(self, rgb: np.ndarray) -> np.ndarray:
        import tensorflow as tf

        resized = tf.image.resize(rgb[np.newaxis, ...], (self.input_height, self.input_width), method="bilinear")
        return tf.cast(resized, tf.float32).numpy()

    def predict(self, rgb: np.ndarray) -> Prediction:
        batch = self.preprocess(rgb)
        with self._lock:
            probabilities = np.asarray(self.model(batch, training=False))[0]
        scores = {name: float(p) for name, p in zip(self.class_names, probabilities, strict=True)}
        top_index = int(np.argmax(probabilities))
        return Prediction(
            prediction_id=str(uuid.uuid4()),
            class_scores=scores,
            top_class=self.class_names[top_index],
            top_score=float(probabilities[top_index]),
        )


def _sha256_prefix(path: Path, length: int = 12) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1 << 20), b""):
            digest.update(chunk)
    return digest.hexdigest()[:length]


def load_model_service(model_dir: Path) -> ModelService | None:
    """Retourne le service, ou None si le modèle ne peut pas être chargé (readiness fausse)."""
    try:
        return ModelService(model_dir)
    except Exception as exc:  # noqa: BLE001 — l'API doit démarrer et signaler l'indisponibilité
        logger.error("Modèle indisponible : %s", type(exc).__name__)
        return None
