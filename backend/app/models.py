"""Modèles SQLAlchemy (voir docs/DATABASE.md). Le schéma évolue uniquement via Alembic."""

from __future__ import annotations

import uuid
from datetime import datetime

from sqlalchemy import CheckConstraint, DateTime, Float, ForeignKey, Index, MetaData, String, func
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column, relationship

ANALYSIS_STATUSES = ("prediction_available", "uncertain")
USER_ROLES = ("user", "admin")


class Base(DeclarativeBase):
    # Noms de contraintes déterministes : ils doivent correspondre à ceux des migrations Alembic.
    metadata = MetaData(naming_convention={
        "uq": "uq_%(table_name)s_%(column_0_name)s",
        "fk": "fk_%(table_name)s_%(column_0_name)s",
    })


class User(Base):
    __tablename__ = "users"
    __table_args__ = (CheckConstraint("role IN ('user', 'admin')", name="ck_users_role"),)

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    email: Mapped[str] = mapped_column(String(320), unique=True, nullable=False)
    password_hash: Mapped[str] = mapped_column(String(255), nullable=False)
    role: Mapped[str] = mapped_column(String(16), nullable=False, default="user", server_default="user")
    is_active: Mapped[bool] = mapped_column(nullable=False, default=True, server_default="true")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), nullable=False)

    analyses: Mapped[list[Analysis]] = relationship(back_populates="user", cascade="all, delete-orphan",
                                                    passive_deletes=True)


class ModelVersion(Base):
    __tablename__ = "model_versions"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    version: Mapped[str] = mapped_column(String(128), unique=True, nullable=False)
    class_mapping: Mapped[list[str]] = mapped_column(JSONB, nullable=False)
    preprocessing_version: Mapped[str] = mapped_column(String(64), nullable=False)
    # Pas de chemin d'artefact ni de métriques inventées : renseignés plus tard, seulement si mesurés.
    artifact_uri: Mapped[str | None] = mapped_column(String(512))
    metrics_summary: Mapped[dict | None] = mapped_column(JSONB)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), nullable=False)


class Analysis(Base):
    __tablename__ = "analyses"
    __table_args__ = (
        CheckConstraint("status IN ('prediction_available', 'uncertain')", name="ck_analyses_status"),
        CheckConstraint("confidence_score IS NULL OR (confidence_score >= 0 AND confidence_score <= 1)",
                        name="ck_analyses_confidence_range"),
        Index("ix_analyses_user_id", "user_id"),
        Index("ix_analyses_user_created", "user_id", "created_at"),
    )

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    # Les analyses anonymes ne sont pas stockées : user_id est donc obligatoire.
    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    model_version_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("model_versions.id"), nullable=False)
    predicted_class: Mapped[str | None] = mapped_column(String(128))
    status: Mapped[str] = mapped_column(String(32), nullable=False)
    confidence_score: Mapped[float | None] = mapped_column(Float)
    scores: Mapped[dict[str, float]] = mapped_column(JSONB, nullable=False)
    # Les images ne sont pas conservées (politique par défaut) : toujours NULL aujourd'hui.
    image_reference: Mapped[str | None] = mapped_column(String(512))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), nullable=False)

    user: Mapped[User] = relationship(back_populates="analyses")
    model_version: Mapped[ModelVersion] = relationship()
