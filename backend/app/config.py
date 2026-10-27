"""Configuration lue depuis l'environnement (préfixe AGRISCAN_) ou un fichier .env non versionné."""

from __future__ import annotations

from pathlib import Path

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict

DEFAULT_MODEL_DIR = Path(__file__).resolve().parents[2] / "ml" / "artifacts" / "mobilenetv2"


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_prefix="AGRISCAN_", env_file=".env", extra="ignore")

    model_dir: Path = DEFAULT_MODEL_DIR
    max_upload_bytes: int = Field(default=5 * 1024 * 1024, gt=0)
    max_image_pixels: int = Field(default=25_000_000, gt=0)
    min_image_side: int = Field(default=32, gt=0)
    # Seuil d'incertitude sur le score softmax maximal. None = désactivé : aucun seuil n'a encore
    # été choisi sur des données de validation (voir docs/MODEL_CARD.md).
    confidence_threshold: float | None = Field(default=None, gt=0.0, le=1.0)
    # Origines CORS autorisées, séparées par des virgules dans l'environnement ; vide = CORS désactivé.
    cors_origins: list[str] = []
