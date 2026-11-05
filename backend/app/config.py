"""Configuration lue depuis l'environnement (préfixe AGRISCAN_) ou un fichier .env non versionné."""

from __future__ import annotations

from pathlib import Path
from typing import Literal

from pydantic import Field, SecretStr, field_validator
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

    # Base PostgreSQL (ex. postgresql+psycopg://utilisateur:motdepasse@hote:5432/base). Absente = historique
    # et comptes désactivés (503) ; les prédictions anonymes restent disponibles.
    database_url: SecretStr | None = None
    # Secret de signature des jetons (>= 32 caractères). Jamais committé ; absent = authentification désactivée.
    jwt_secret: SecretStr | None = None
    access_token_minutes: int = Field(default=30, gt=0, le=1440)
    login_max_failures: int = Field(default=5, gt=0)
    login_window_seconds: int = Field(default=900, gt=0)

    # Filigrane des images annotées exportées (jamais appliqué avant l'inférence ni à l'image d'origine).
    watermark_enabled: bool = True
    watermark_text: str = Field(default="AgriScan AI", min_length=1, max_length=40)
    watermark_position: Literal["bottom-right", "bottom-left", "top-right", "top-left"] = "bottom-right"
    watermark_opacity: float = Field(default=0.6, ge=0.0, le=1.0)
    watermark_size_ratio: float = Field(default=0.04, gt=0.0, le=0.2)
    watermark_margin_ratio: float = Field(default=0.02, ge=0.0, le=0.1)
    export_max_side: int = Field(default=1024, ge=64, le=4096)

    @field_validator("jwt_secret")
    @classmethod
    def secret_long_enough(cls, value: SecretStr | None) -> SecretStr | None:
        if value is not None and len(value.get_secret_value()) < 32:
            raise ValueError("jwt_secret doit contenir au moins 32 caractères")
        return value
