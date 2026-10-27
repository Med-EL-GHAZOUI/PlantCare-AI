"""Tests avec le vrai modèle entraîné ; ignorés si les artefacts (non versionnés) sont absents.

Ils vérifient la cohérence du prétraitement d'inférence avec celui de l'entraînement, pas la
performance du modèle (mesurée dans docs/MODEL_CARD.md). Les images viennent de val.csv.
"""

import csv
from pathlib import Path

import numpy as np
import pytest
import tensorflow as tf
from fastapi.testclient import TestClient
from PIL import Image

from app.config import DEFAULT_MODEL_DIR, Settings
from app.inference import ModelService
from app.main import create_app

REPO = Path(__file__).resolve().parents[2]
IMAGE_ROOT = REPO / "ml" / "data" / "raw" / "plantvillage_tomato"
VAL_CSV = REPO / "ml" / "data" / "splits" / "val.csv"

pytestmark = pytest.mark.skipif(
    not ((DEFAULT_MODEL_DIR / "model.keras").exists() and VAL_CSV.exists() and IMAGE_ROOT.exists()),
    reason="modèle ou données locales absents",
)


@pytest.fixture(scope="module")
def real_service() -> ModelService:
    return ModelService(DEFAULT_MODEL_DIR)


def sample_paths(count: int = 8) -> list[Path]:
    with VAL_CSV.open(newline="", encoding="utf-8") as handle:
        rows = list(csv.DictReader(handle))
    return [IMAGE_ROOT / row["path"] for row in rows[:: len(rows) // count][:count]]


def test_inference_preprocessing_matches_training_pipeline(real_service) -> None:
    for path in sample_paths():
        ours = real_service.predict(np.asarray(Image.open(path).convert("RGB")))
        decoded = tf.io.decode_image(tf.io.read_file(str(path)), channels=3, expand_animations=False)
        reference = tf.image.resize(decoded, (224, 224), method="bilinear")
        expected = real_service.model(tf.cast(reference, tf.float32)[None], training=False).numpy()[0]
        got = np.array(list(ours.class_scores.values()))
        assert np.argmax(got) == np.argmax(expected)
        assert np.abs(got - expected).max() < 0.06  # écart mesuré : 0,034 (décodeurs JPEG différents)


def test_endpoint_with_real_model_end_to_end(real_service) -> None:
    path = sample_paths(1)[0]
    with TestClient(create_app(Settings(), model_service=real_service)) as client:
        response = client.post("/api/v1/predictions", files={"image": ("leaf.jpg", path.read_bytes(), "image/jpeg")})
        info = client.get("/api/v1/model/info").json()
    assert response.status_code == 200
    body = response.json()
    assert body["predicted_class"] in info["supported_classes"]
    assert len(info["supported_classes"]) == 10
    assert sum(body["scores"].values()) == pytest.approx(1.0, abs=1e-3)
