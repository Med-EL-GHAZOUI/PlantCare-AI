import io
import json
import os
from pathlib import Path

os.environ.setdefault("TF_CPP_MIN_LOG_LEVEL", "2")

import keras
import numpy as np
import pytest
from fastapi.testclient import TestClient
from PIL import Image

from app.config import Settings
from app.inference import ModelService
from app.main import create_app

CLASSES = ["alpha", "beta", "gamma"]


@pytest.fixture(scope="session")
def tiny_model_dir(tmp_path_factory) -> Path:
    """Vrai petit modèle Keras (poids aléatoires) pour tester le chemin d'inférence réel hors-ligne.
    Ses prédictions n'ont aucun sens agronomique ; seuls le contrat et la mécanique sont testés."""
    directory = tmp_path_factory.mktemp("tiny_model")
    keras.utils.set_random_seed(0)
    inputs = keras.Input(shape=(32, 32, 3), name="image")
    x = keras.layers.Rescaling(1 / 255)(inputs)
    x = keras.layers.Conv2D(4, 3, activation="relu")(x)
    x = keras.layers.GlobalAveragePooling2D()(x)
    outputs = keras.layers.Dense(len(CLASSES), activation="softmax")(x)
    keras.Model(inputs, outputs, name="tiny").save(directory / "model.keras")
    (directory / "class_names.json").write_text(json.dumps(CLASSES), encoding="utf-8")
    (directory / "config.json").write_text(
        json.dumps({"preprocess": {"image_height": 32, "image_width": 32}}), encoding="utf-8")
    return directory


@pytest.fixture(scope="session")
def model_service(tiny_model_dir) -> ModelService:
    return ModelService(tiny_model_dir)


@pytest.fixture
def client(model_service):
    with TestClient(create_app(Settings(), model_service=model_service)) as test_client:
        yield test_client


@pytest.fixture
def make_client(model_service):
    """Fabrique un client avec des réglages personnalisés."""
    clients = []

    def factory(**overrides) -> TestClient:
        test_client = TestClient(create_app(Settings(**overrides), model_service=model_service),
                                 raise_server_exceptions=False)
        test_client.__enter__()
        clients.append(test_client)
        return test_client

    yield factory
    for test_client in clients:
        test_client.__exit__(None, None, None)


def image_bytes(fmt: str = "JPEG", size: tuple[int, int] = (64, 48), color=(30, 160, 60), noise: bool = False) -> bytes:
    """Image unie, ou bruit aléatoire (incompressible) quand noise=True."""
    if noise:
        pixels = np.random.default_rng(0).integers(0, 256, (size[1], size[0], 3), dtype=np.uint8)
    else:
        pixels = np.full((size[1], size[0], 3), color, dtype=np.uint8)
    buffer = io.BytesIO()
    Image.fromarray(pixels).save(buffer, fmt)
    return buffer.getvalue()
