"""Export d'une image annotée (résultat + filigrane optionnel).

L'inférence utilise l'image décodée d'origine ; le filigrane n'est ajouté qu'ensuite, sur une copie de
sortie. Rien n'est stocké : l'image annotée est renvoyée à l'appelant puis oubliée.
"""

from __future__ import annotations

import io
from typing import Annotated

from fastapi import APIRouter, File, Query, Request, Response, UploadFile
from PIL import Image

from app.config import Settings
from app.decision import decide
from app.errors import ApiError
from app.image_validation import decode_image
from app.inference import ModelService
from app.watermark import WatermarkConfig, build_caption, compose_annotated_image

router = APIRouter(prefix="/api/v1")


def watermark_config(settings: Settings) -> WatermarkConfig:
    """Configuration validée ; lève ValueError (au démarrage) si les réglages sont incohérents."""
    return WatermarkConfig(
        text=settings.watermark_text,
        position=settings.watermark_position,
        opacity=settings.watermark_opacity,
        size_ratio=settings.watermark_size_ratio,
        margin_ratio=settings.watermark_margin_ratio,
        enabled=settings.watermark_enabled,
    )


def _service(request: Request) -> ModelService:
    service = request.app.state.model_service
    if service is None:
        raise ApiError(503, "model_unavailable", "Le modèle n'est pas disponible.")
    return service


@router.post(
    "/predictions/annotated-image",
    response_class=Response,
    responses={200: {"content": {"image/png": {}}, "description": "Image PNG annotée"}},
)
def annotated_image(
    request: Request,
    image: Annotated[UploadFile, File()],
    watermark: Annotated[bool | None, Query(description="Surcharge ponctuelle de AGRISCAN_WATERMARK_ENABLED")] = None,
) -> Response:
    settings: Settings = request.app.state.settings
    service = _service(request)

    original = decode_image(image, settings)  # tableau RGB d'origine, jamais modifié
    result = service.predict(original)  # 1. inférence sur l'image d'origine
    status, predicted = decide(result.top_class, result.top_score, settings.confidence_threshold)

    config = request.app.state.watermark_config
    if watermark is not None:
        config = config.with_enabled(watermark)
    annotated, _ = compose_annotated_image(  # 2. ensuite seulement : copie annotée + filigrane
        Image.fromarray(original),
        build_caption(status, predicted, result.top_score),
        config,
        max_side=settings.export_max_side,
    )
    buffer = io.BytesIO()
    annotated.save(buffer, format="PNG")
    return Response(
        content=buffer.getvalue(),
        media_type="image/png",
        headers={
            "X-Prediction-Id": result.prediction_id,
            "X-Watermark": "applied" if config.enabled else "none",
            "Cache-Control": "no-store",
            "Content-Disposition": 'inline; filename="agriscan-result.png"',
        },
    )
