"""Historique des analyses : strictement limité à l'utilisateur authentifié.

Une analyse d'un autre utilisateur est indiscernable d'une analyse inexistante (404) : connaître
un identifiant ne donne jamais accès à la ressource.
"""

from __future__ import annotations

import uuid
from datetime import datetime
from typing import Annotated

from fastapi import APIRouter, Query, Response
from pydantic import BaseModel, ConfigDict
from sqlalchemy import func, select

from app.auth import CurrentUser, SessionDep
from app.errors import ApiError
from app.models import Analysis

router = APIRouter(prefix="/api/v1/analyses", tags=["analyses"])


class AnalysisResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    status: str
    predicted_class: str | None
    confidence_score: float | None
    scores: dict[str, float]
    model_version: str
    created_at: datetime

    @classmethod
    def from_analysis(cls, analysis: Analysis) -> AnalysisResponse:
        return cls(
            id=analysis.id, status=analysis.status, predicted_class=analysis.predicted_class,
            confidence_score=analysis.confidence_score, scores=analysis.scores,
            model_version=analysis.model_version.version, created_at=analysis.created_at,
        )


class AnalysisPage(BaseModel):
    items: list[AnalysisResponse]
    total: int
    limit: int
    offset: int


def _owned_analysis(session: SessionDep, user: CurrentUser, analysis_id: uuid.UUID) -> Analysis:
    analysis = session.scalar(
        select(Analysis).where(Analysis.id == analysis_id, Analysis.user_id == user.id)
    )
    if analysis is None:
        raise ApiError(404, "not_found", "Analyse introuvable.")
    return analysis


@router.get("", response_model=AnalysisPage)
def list_analyses(
    session: SessionDep,
    user: CurrentUser,
    limit: Annotated[int, Query(ge=1, le=100)] = 20,
    offset: Annotated[int, Query(ge=0)] = 0,
) -> AnalysisPage:
    base = select(Analysis).where(Analysis.user_id == user.id)
    total = session.scalar(select(func.count()).select_from(base.subquery())) or 0
    rows = session.scalars(base.order_by(Analysis.created_at.desc(), Analysis.id).limit(limit).offset(offset)).all()
    return AnalysisPage(items=[AnalysisResponse.from_analysis(a) for a in rows], total=total, limit=limit,
                        offset=offset)


@router.get("/{analysis_id}", response_model=AnalysisResponse)
def get_analysis(analysis_id: uuid.UUID, session: SessionDep, user: CurrentUser) -> AnalysisResponse:
    return AnalysisResponse.from_analysis(_owned_analysis(session, user, analysis_id))


@router.delete("/{analysis_id}", status_code=204)
def delete_analysis(analysis_id: uuid.UUID, session: SessionDep, user: CurrentUser) -> Response:
    session.delete(_owned_analysis(session, user, analysis_id))
    session.commit()
    return Response(status_code=204)
