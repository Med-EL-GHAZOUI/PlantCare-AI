import io
import json
import os
from pathlib import Path

from alembic import command
from alembic.config import Config
from sqlalchemy import create_engine, text
from sqlalchemy.engine import make_url

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
    with TestClient(create_app(Settings(_env_file=None), model_service=model_service)) as test_client:
        yield test_client


@pytest.fixture
def make_client(model_service):
    """Fabrique un client avec des réglages personnalisés."""
    clients = []

    def factory(**overrides) -> TestClient:
        test_client = TestClient(create_app(Settings(_env_file=None, **overrides), model_service=model_service),
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


# ---------- PostgreSQL de test (migrations Alembic réellement appliquées) ----------

BACKEND_DIR = Path(__file__).resolve().parents[1]
JWT_SECRET = "test-secret-" + "x" * 40


def _test_database_url() -> str | None:
    url = os.environ.get("AGRISCAN_TEST_DATABASE_URL")
    env_file = BACKEND_DIR / ".env"
    if not url and env_file.exists():
        for line in env_file.read_text(encoding="utf-8").splitlines():
            if line.startswith("AGRISCAN_TEST_DATABASE_URL="):
                url = line.split("=", 1)[1].strip()
    return url


def alembic_config(url: str) -> Config:
    config = Config(str(BACKEND_DIR / "alembic.ini"))
    config.set_main_option("script_location", str(BACKEND_DIR / "migrations"))
    config.set_main_option("sqlalchemy.url", url.replace("%", "%%"))
    return config


def _ensure_database(url: str) -> bool:
    """Crée la base cible si besoin. Retourne False si le serveur est injoignable (échec rapide)."""
    target = make_url(url)
    admin = create_engine(target.set(database="postgres"), isolation_level="AUTOCOMMIT",
                          connect_args={"connect_timeout": 3})
    try:
        with admin.connect() as connection:
            exists = connection.scalar(text("SELECT 1 FROM pg_database WHERE datname = :n"), {"n": target.database})
            if not exists:
                connection.execute(text(f'CREATE DATABASE "{target.database}"'))
        return True
    except Exception:  # noqa: BLE001
        return False
    finally:
        admin.dispose()


@pytest.fixture(scope="session")
def database_url(tmp_path_factory):
    """URL d'une base PostgreSQL dédiée aux tests.

    1. AGRISCAN_TEST_DATABASE_URL (serveur existant, ex. Docker) si elle répond ;
    2. sinon un PostgreSQL 16 embarqué par `pgserver` (éphémère, dans un dossier temporaire) ;
    3. sinon les tests PostgreSQL sont ignorés.
    """
    url = _test_database_url()
    if url and _ensure_database(url):
        yield url
        return
    try:
        import pgserver
    except ImportError:
        pytest.skip("Aucun PostgreSQL disponible (ni AGRISCAN_TEST_DATABASE_URL, ni pgserver)")
    server = pgserver.get_server(tmp_path_factory.mktemp("pgdata"), cleanup_mode="stop")
    try:
        embedded = make_url(server.get_uri()).set(drivername="postgresql+psycopg", database="agriscan_test")
        embedded_url = embedded.render_as_string(hide_password=False)
        assert _ensure_database(embedded_url)
        yield embedded_url
    finally:
        server.cleanup()


@pytest.fixture(scope="session")
def migrated_engine(database_url):
    config = alembic_config(database_url)
    command.downgrade(config, "base")
    command.upgrade(config, "head")
    engine = create_engine(database_url)
    yield engine
    engine.dispose()


@pytest.fixture
def db_engine(migrated_engine):
    with migrated_engine.begin() as connection:
        connection.execute(text("TRUNCATE analyses, model_versions, users CASCADE"))
    return migrated_engine


@pytest.fixture
def auth_client(db_engine, database_url, model_service):
    settings = Settings(_env_file=None, database_url=database_url, jwt_secret=JWT_SECRET)
    with TestClient(create_app(settings, model_service=model_service), raise_server_exceptions=False) as test_client:
        yield test_client
