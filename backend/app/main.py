"""Application FastAPI : /api/v1/health, /api/v1/model/info, /api/v1/predictions."""

from __future__ import annotations

from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

from fastapi import APIRouter, Depends, FastAPI, File, Request, UploadFile
from fastapi.middleware.cors import CORSMiddleware

from app.config import Settings
from app.errors import ApiError, register_error_handlers
from app.image_validation import decode_image
from app.inference import PREPROCESSING_SUMMARY, ModelService, load_model_service
from app.schemas import (
    ErrorResponse,
    HealthResponse,
    ModelInfoResponse,
    PredictionResponse,
)

ERROR_RESPONSES = {
    400: {"model": ErrorResponse}, 413: {"model": ErrorResponse}, 415: {"model": ErrorResponse},
    422: {"model": ErrorResponse}, 503: {"model": ErrorResponse},
}


def get_model_service(request: Request) -> ModelService:
    service: ModelService | None = request.app.state.model_service
    if service is None:
        raise ApiError(503, "model_unavailable", "Le modèle n'est pas disponible.")
    return service


def get_settings(request: Request) -> Settings:
    return request.app.state.settings


router = APIRouter(prefix="/api/v1")


@router.get("/health", response_model=HealthResponse)
def health(request: Request) -> HealthResponse:
    return HealthResponse(status="ok", model_loaded=request.app.state.model_service is not None)


@router.get("/model/info", response_model=ModelInfoResponse, responses=ERROR_RESPONSES)
def model_info(
    service: ModelService = Depends(get_model_service), settings: Settings = Depends(get_settings)
) -> ModelInfoResponse:
    return ModelInfoResponse(
        model_version=service.model_version,
        supported_classes=service.class_names,
        input_height=service.input_height,
        input_width=service.input_width,
        preprocessing=PREPROCESSING_SUMMARY,
        confidence_is_calibrated=False,
        confidence_threshold=settings.confidence_threshold,
        out_of_scope_detection=False,
    )


@router.post("/predictions", response_model=PredictionResponse, responses=ERROR_RESPONSES)
def create_prediction(
    image: UploadFile = File(...),
    service: ModelService = Depends(get_model_service),
    settings: Settings = Depends(get_settings),
) -> PredictionResponse:
    rgb = decode_image(image, settings)
    result = service.predict(rgb)
    uncertain = settings.confidence_threshold is not None and result.top_score < settings.confidence_threshold
    return PredictionResponse(
        prediction_id=result.prediction_id,
        status="uncertain" if uncertain else "prediction_available",
        predicted_class=None if uncertain else result.top_class,
        confidence=result.top_score,
        scores=result.class_scores,
        model_version=service.model_version,
    )


def create_app(settings: Settings | None = None, model_service: ModelService | None = None) -> FastAPI:
    """`model_service` permet d'injecter un service déjà chargé (tests) ; sinon chargé au démarrage."""
    settings = settings or Settings()

    @asynccontextmanager
    async def lifespan(app: FastAPI) -> AsyncIterator[None]:
        app.state.model_service = model_service or load_model_service(settings.model_dir)
        yield

    app = FastAPI(title="AgriScan AI API", version="0.1.0", lifespan=lifespan)
    app.state.settings = settings
    app.state.model_service = None
    register_error_handlers(app)
    if settings.cors_origins:
        app.add_middleware(CORSMiddleware, allow_origins=settings.cors_origins, allow_methods=["GET", "POST"],
                           allow_headers=["*"])
    app.include_router(router)
    return app


app = create_app()
