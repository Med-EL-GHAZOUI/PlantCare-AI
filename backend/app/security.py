"""Hachage des mots de passe (Argon2id) et jetons d'accès JWT signés (HS256)."""

from __future__ import annotations

import uuid
from datetime import UTC, datetime, timedelta

import jwt
from argon2 import PasswordHasher
from argon2.exceptions import InvalidHashError, VerificationError

_hasher = PasswordHasher()
# Hash factice : permet de dépenser le même temps de calcul quand l'email est inconnu.
DUMMY_HASH = _hasher.hash("dummy-password-for-timing-equalisation")
JWT_ALGORITHM = "HS256"
MIN_SECRET_LENGTH = 32


def hash_password(password: str) -> str:
    return _hasher.hash(password)


def verify_password(password_hash: str, password: str) -> bool:
    try:
        return _hasher.verify(password_hash, password)
    except (VerificationError, InvalidHashError):
        return False


def needs_rehash(password_hash: str) -> bool:
    return _hasher.check_needs_rehash(password_hash)


def create_access_token(user_id: uuid.UUID, secret: str, expires_minutes: int) -> str:
    now = datetime.now(UTC)
    claims = {"sub": str(user_id), "iat": now, "exp": now + timedelta(minutes=expires_minutes), "typ": "access"}
    return jwt.encode(claims, secret, algorithm=JWT_ALGORITHM)


def decode_access_token(token: str, secret: str) -> uuid.UUID | None:
    """Retourne l'identifiant utilisateur, ou None si le jeton est invalide, expiré ou mal formé."""
    try:
        claims = jwt.decode(token, secret, algorithms=[JWT_ALGORITHM], options={"require": ["exp", "sub"]})
        if claims.get("typ") != "access":
            return None
        return uuid.UUID(claims["sub"])
    except (jwt.PyJWTError, ValueError):
        return None
