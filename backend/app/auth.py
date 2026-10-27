"""Comptes locaux : inscription, connexion (jeton JWT), profil, suppression du compte."""

from __future__ import annotations

import uuid
from typing import Annotated

from fastapi import APIRouter, Depends, Request, Response
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from pydantic import BaseModel, EmailStr, Field, field_validator
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.config import Settings
from app.db import get_session
from app.errors import ApiError
from app.models import User
from app.security import (
    DUMMY_HASH,
    create_access_token,
    decode_access_token,
    hash_password,
    needs_rehash,
    verify_password,
)

router = APIRouter(prefix="/api/v1/auth", tags=["auth"])
bearer_scheme = HTTPBearer(auto_error=False)

SessionDep = Annotated[Session, Depends(get_session)]


class Credentials(BaseModel):
    email: EmailStr
    password: str = Field(min_length=10, max_length=128)

    @field_validator("email")
    @classmethod
    def normalise_email(cls, value: str) -> str:
        return value.strip().lower()


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    expires_in: int


class UserResponse(BaseModel):
    id: uuid.UUID
    email: str
    role: str


def _settings(request: Request) -> Settings:
    return request.app.state.settings


def _jwt_secret(request: Request) -> str:
    secret = _settings(request).jwt_secret
    if secret is None:
        raise ApiError(503, "auth_unavailable", "L'authentification n'est pas configurée.")
    return secret.get_secret_value()


def _unauthorized() -> ApiError:
    return ApiError(401, "not_authenticated", "Authentification requise ou jeton invalide.")


def user_from_credentials(
    request: Request, credentials: HTTPAuthorizationCredentials | None, session: Session
) -> User | None:
    if credentials is None:
        return None
    user_id = decode_access_token(credentials.credentials, _jwt_secret(request))
    user = session.get(User, user_id) if user_id else None
    if user is None or not user.is_active:
        raise _unauthorized()
    return user


def get_current_user(
    request: Request,
    session: SessionDep,
    credentials: Annotated[HTTPAuthorizationCredentials | None, Depends(bearer_scheme)],
) -> User:
    user = user_from_credentials(request, credentials, session)
    if user is None:
        raise _unauthorized()
    return user


CurrentUser = Annotated[User, Depends(get_current_user)]


@router.post("/register", response_model=UserResponse, status_code=201)
def register(body: Credentials, request: Request, session: SessionDep) -> User:
    _jwt_secret(request)  # refuse d'ouvrir des comptes si l'authentification n'est pas configurée
    user = User(email=body.email, password_hash=hash_password(body.password), role="user")
    session.add(user)
    try:
        session.commit()
    except IntegrityError:
        session.rollback()
        raise ApiError(409, "email_already_registered", "Cet email est déjà utilisé.") from None
    return user


@router.post("/login", response_model=TokenResponse)
def login(body: Credentials, request: Request, session: SessionDep) -> TokenResponse:
    secret = _jwt_secret(request)
    throttle = request.app.state.login_throttle
    client = request.client.host if request.client else "inconnu"
    keys = (f"email:{body.email}", f"ip:{client}")
    if any(throttle.is_blocked(key) for key in keys):
        raise ApiError(429, "too_many_attempts", "Trop de tentatives. Réessayez plus tard.")

    user = session.scalar(select(User).where(User.email == body.email))
    password_ok = verify_password(user.password_hash if user else DUMMY_HASH, body.password)
    if user is None or not user.is_active or not password_ok:
        for key in keys:
            throttle.record_failure(key)
        raise ApiError(401, "invalid_credentials", "Email ou mot de passe incorrect.")

    throttle.reset(keys[0])
    if needs_rehash(user.password_hash):
        user.password_hash = hash_password(body.password)
        session.commit()
    minutes = _settings(request).access_token_minutes
    return TokenResponse(access_token=create_access_token(user.id, secret, minutes), expires_in=minutes * 60)


@router.get("/me", response_model=UserResponse)
def me(user: CurrentUser) -> User:
    return user


@router.delete("/me", status_code=204)
def delete_account(user: CurrentUser, session: SessionDep) -> Response:
    """Supprime le compte et, en cascade, toutes ses analyses."""
    session.delete(user)
    session.commit()
    return Response(status_code=204)
