"""Connexion PostgreSQL (SQLAlchemy 2, sessions synchrones)."""

from __future__ import annotations

from collections.abc import Iterator

from fastapi import Request
from sqlalchemy import Engine, create_engine
from sqlalchemy.orm import Session, sessionmaker

from app.config import Settings
from app.errors import ApiError


def create_session_factory(settings: Settings) -> tuple[Engine, sessionmaker[Session]] | None:
    if settings.database_url is None:
        return None
    engine = create_engine(settings.database_url.get_secret_value(), pool_pre_ping=True)
    return engine, sessionmaker(bind=engine, expire_on_commit=False)


def get_session(request: Request) -> Iterator[Session]:
    factory: sessionmaker[Session] | None = request.app.state.session_factory
    if factory is None:
        raise ApiError(503, "database_unavailable", "La base de données n'est pas configurée.")
    with factory() as session:
        yield session
