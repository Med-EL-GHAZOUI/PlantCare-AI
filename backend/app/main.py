"""Application FastAPI : /api/v1/health, /api/v1/model/info, /api/v1/predictions."""

from __future__ import annotations

import uuid
from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

from fastapi import APIRouter, Depends, FastAPI, File, Request, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import HTTPAuthorizationCredentials
from sqlalchemy import select
from sqlalchemy.dialects.postgresql import insert

from app import auth, history
from app.config import Settings
from app.db import create_session_factory
from app.errors import ApiError, register_error_handlers
from app.image_validation import decode_image
from app.inference import PREPROCESSING_SUMMARY, PREPROCESSING_VERSION, ModelService, load_model_service
from app.models import Analysis, ModelVersion, User
from app.schemas import (
    ErrorResponse,
    HealthResponse,
    ModelInfoResponse,
    PredictionResponse,
)
from app.throttle import LoginThrottle

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


def optional_user(request: Request, credentials: HTTPAuthorizationCredentials | None = Depends(auth.bearer_scheme)):
    """Utilisateur authentifié, ou None sans en-tête Authorization. Un jeton fourni mais invalide = 401."""
    if credentials is None:
        return None
    factory = request.app.state.session_factory
    if factory is None:
        raise ApiError(503, "database_unavailable", "La base de données n'est pas configurée.")
    with factory() as session:
        user = auth.user_from_credentials(request, credentials, session)
        if user is not None:
            session.expunge(user)
        return user


def store_analysis(factory, user: User, service: ModelService, result, status: str, predicted: str | None) -> None:
    """Enregistre le résultat (jamais l'image) pour l'utilisateur authentifié."""
    with factory() as session:
        session.execute(
            insert(ModelVersion).values(
                version=service.model_version, class_mapping=service.class_names,
                preprocessing_version=PREPROCESSING_VERSION,
            ).on_conflict_do_nothing(index_elements=["version"])
        )
        version_id = session.scalar(select(ModelVersion.id).where(ModelVersion.version == service.model_version))
        session.add(Analysis(
            id=uuid.UUID(result.prediction_id), user_id=user.id, model_version_id=version_id,
            predicted_class=predicted, status=status, confidence_score=result.top_score, scores=result.class_scores,
        ))
        session.commit()


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
    request: Request,
    image: UploadFile = File(...),
    service: ModelService = Depends(get_model_service),
    settings: Settings = Depends(get_settings),
    user: User | None = Depends(optional_user),
) -> PredictionResponse:
    rgb = decode_image(image, settings)
    result = service.predict(rgb)
    uncertain = settings.confidence_threshold is not None and result.top_score < settings.confidence_threshold
    status = "uncertain" if uncertain else "prediction_available"
    predicted = None if uncertain else result.top_class
    if user is not None:  # utilisateur authentifié : l'analyse est ajoutée à son historique
        store_analysis(request.app.state.session_factory, user, service, result, status, predicted)
    return PredictionResponse(
        prediction_id=result.prediction_id,
        status=status,
        predicted_class=predicted,
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
        if database is not None:
            database[0].dispose()

    database = create_session_factory(settings)
    app = FastAPI(title="AgriScan AI API", version="0.1.0", lifespan=lifespan)
    app.state.settings = settings
    app.state.model_service = None
    app.state.session_factory = database[1] if database else None
    app.state.login_throttle = LoginThrottle(settings.login_max_failures, settings.login_window_seconds)
    register_error_handlers(app)
    if settings.cors_origins:
        app.add_middleware(CORSMiddleware, allow_origins=settings.cors_origins, allow_methods=["GET", "POST"],
                           allow_headers=["*"])
    app.include_router(router)
    app.include_router(auth.router)
    app.include_router(history.router)
    return app


app = create_app()
