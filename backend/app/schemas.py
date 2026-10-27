"""Schémas Pydantic des réponses."""

from __future__ import annotations

from typing import Literal

from pydantic import BaseModel

DISCLAIMER = (
    "Résultat de dépistage par IA, pas un diagnostic confirmé. "
    "Faites vérifier par un spécialiste avant toute décision."
)


class HealthResponse(BaseModel):
    status: Literal["ok"]
    model_loaded: bool


class ModelInfoResponse(BaseModel):
    model_version: str
    supported_classes: list[str]
    input_height: int
    input_width: int
    preprocessing: str
    confidence_is_calibrated: bool
    confidence_threshold: float | None
    out_of_scope_detection: bool


class PredictionResponse(BaseModel):
    prediction_id: str
    status: Literal["prediction_available", "uncertain"]
    predicted_class: str | None
    confidence: float
    scores: dict[str, float]
    model_version: str
    disclaimer: str = DISCLAIMER


class ErrorBody(BaseModel):
    code: str
    message: str


class ErrorResponse(BaseModel):
    error: ErrorBody
