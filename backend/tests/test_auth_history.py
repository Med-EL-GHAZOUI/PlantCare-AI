"""Comptes, jetons et historique protégé. Nécessite PostgreSQL (migrations Alembic appliquées)."""

import uuid
from datetime import UTC, datetime, timedelta

import jwt
import pytest
from fastapi.testclient import TestClient
from sqlalchemy import text

from app.config import Settings
from app.main import create_app
from app.security import create_access_token
from tests.conftest import JWT_SECRET, image_bytes

PASSWORD = "correct horse battery"
OTHER_PASSWORD = "another passphrase 42"


def register(client, email="alice@example.com", password=PASSWORD):
    return client.post("/api/v1/auth/register", json={"email": email, "password": password})


def login(client, email="alice@example.com", password=PASSWORD):
    return client.post("/api/v1/auth/login", json={"email": email, "password": password})


def bearer(client, email="alice@example.com", password=PASSWORD) -> dict:
    register(client, email, password)
    return {"Authorization": f"Bearer {login(client, email, password).json()['access_token']}"}


def predict(client, headers=None):
    return client.post("/api/v1/predictions", headers=headers or {},
                       files={"image": ("leaf.jpg", image_bytes(), "image/jpeg")})


def error_code(response) -> str:
    return response.json()["error"]["code"]


# ---------- inscription et connexion ----------

def test_register_returns_user_without_password_and_stores_argon2_hash(auth_client, db_engine) -> None:
    response = register(auth_client, "Alice@Example.COM")
    assert response.status_code == 201
    body = response.json()
    assert body["email"] == "alice@example.com" and body["role"] == "user" and "password" not in str(body).lower()
    with db_engine.connect() as connection:
        stored = connection.scalar(text("SELECT password_hash FROM users WHERE email = 'alice@example.com'"))
    assert stored.startswith("$argon2id$") and PASSWORD not in stored


def test_register_rejects_duplicate_weak_password_and_bad_email(auth_client) -> None:
    assert register(auth_client).status_code == 201
    assert error_code(register(auth_client, "ALICE@example.com")) == "email_already_registered"
    assert register(auth_client, "bob@example.com", "short").status_code == 422
    assert register(auth_client, "not-an-email").status_code == 422


def test_login_success_and_uniform_failures(auth_client) -> None:
    register(auth_client)
    ok = login(auth_client)
    assert ok.status_code == 200 and ok.json()["token_type"] == "bearer" and ok.json()["expires_in"] == 1800
    wrong = login(auth_client, password="wrong password!!")
    unknown = login(auth_client, email="nobody@example.com")
    assert wrong.status_code == unknown.status_code == 401
    assert wrong.json() == unknown.json()  # aucune différence permettant d'énumérer les comptes


def test_login_is_throttled_after_repeated_failures(auth_client) -> None:
    register(auth_client)
    for _ in range(5):
        assert login(auth_client, password="wrong password!!").status_code == 401
    blocked = login(auth_client)  # même le bon mot de passe est refusé pendant le blocage
    assert blocked.status_code == 429 and error_code(blocked) == "too_many_attempts"


def test_inactive_user_cannot_login_or_use_token(auth_client, db_engine) -> None:
    headers = bearer(auth_client)
    with db_engine.begin() as connection:
        connection.execute(text("UPDATE users SET is_active = false"))
    assert login(auth_client).status_code == 401
    assert auth_client.get("/api/v1/auth/me", headers=headers).status_code == 401


# ---------- jetons ----------

def test_me_requires_a_valid_token(auth_client) -> None:
    headers = bearer(auth_client)
    me = auth_client.get("/api/v1/auth/me", headers=headers)
    assert me.status_code == 200 and me.json()["email"] == "alice@example.com"
    assert error_code(auth_client.get("/api/v1/auth/me")) == "not_authenticated"
    assert auth_client.get("/api/v1/auth/me", headers={"Authorization": "Bearer garbage"}).status_code == 401


def test_expired_foreign_and_orphan_tokens_are_rejected(auth_client) -> None:
    user_id = uuid.UUID(register(auth_client).json()["id"])
    expired = jwt.encode({"sub": str(user_id), "exp": datetime.now(UTC) - timedelta(minutes=1), "typ": "access"},
                         JWT_SECRET, algorithm="HS256")
    foreign = create_access_token(user_id, "another-secret-" + "y" * 40, 30)
    orphan = create_access_token(uuid.uuid4(), JWT_SECRET, 30)  # utilisateur inexistant
    unsigned = jwt.encode({"sub": str(user_id), "typ": "access"}, key=None, algorithm="none")
    for token in (expired, foreign, orphan, unsigned):
        response = auth_client.get("/api/v1/auth/me", headers={"Authorization": f"Bearer {token}"})
        assert response.status_code == 401, token


# ---------- prédictions et historique ----------

def test_anonymous_prediction_is_not_stored(auth_client, db_engine) -> None:
    assert predict(auth_client).status_code == 200
    with db_engine.connect() as connection:
        assert connection.scalar(text("SELECT count(*) FROM analyses")) == 0


def test_invalid_token_on_prediction_is_401_not_silently_anonymous(auth_client) -> None:
    assert predict(auth_client, {"Authorization": "Bearer garbage"}).status_code == 401


def test_authenticated_prediction_is_saved_in_own_history(auth_client, db_engine) -> None:
    headers = bearer(auth_client)
    result = predict(auth_client, headers).json()
    history = auth_client.get("/api/v1/analyses", headers=headers).json()
    assert history["total"] == 1
    item = history["items"][0]
    assert item["id"] == result["prediction_id"] and item["predicted_class"] == result["predicted_class"]
    assert item["scores"] == pytest.approx(result["scores"]) and item["model_version"] == result["model_version"]
    with db_engine.connect() as connection:
        assert connection.scalar(text("SELECT image_reference FROM analyses")) is None  # aucune image conservée
        assert connection.scalar(text("SELECT count(*) FROM model_versions")) == 1


def test_model_version_row_is_reused(auth_client, db_engine) -> None:
    headers = bearer(auth_client)
    for _ in range(3):
        predict(auth_client, headers)
    with db_engine.connect() as connection:
        assert connection.scalar(text("SELECT count(*) FROM model_versions")) == 1
        assert connection.scalar(text("SELECT count(*) FROM analyses")) == 3


def test_history_pagination_order_and_validation(auth_client) -> None:
    headers = bearer(auth_client)
    ids = [predict(auth_client, headers).json()["prediction_id"] for _ in range(3)]
    page = auth_client.get("/api/v1/analyses?limit=2", headers=headers).json()
    assert page["total"] == 3 and len(page["items"]) == 2 and page["limit"] == 2
    assert [i["id"] for i in page["items"]] == ids[::-1][:2]  # plus récentes d'abord
    rest = auth_client.get("/api/v1/analyses?limit=2&offset=2", headers=headers).json()
    assert [i["id"] for i in rest["items"]] == ids[::-1][2:]
    assert auth_client.get("/api/v1/analyses?limit=0", headers=headers).status_code == 422
    assert auth_client.get("/api/v1/analyses?limit=1000", headers=headers).status_code == 422


def test_history_routes_require_authentication(auth_client) -> None:
    some_id = uuid.uuid4()
    for method, url in (("get", "/api/v1/analyses"), ("get", f"/api/v1/analyses/{some_id}"),
                        ("delete", f"/api/v1/analyses/{some_id}")):
        assert getattr(auth_client, method)(url).status_code == 401, url


def test_user_cannot_read_list_or_delete_another_users_analysis(auth_client) -> None:
    alice, bob = bearer(auth_client), bearer(auth_client, "bob@example.com", OTHER_PASSWORD)
    alice_id = predict(auth_client, alice).json()["prediction_id"]
    assert auth_client.get("/api/v1/analyses", headers=bob).json() == {"items": [], "total": 0, "limit": 20, "offset": 0}
    assert auth_client.get(f"/api/v1/analyses/{alice_id}", headers=bob).status_code == 404
    assert auth_client.delete(f"/api/v1/analyses/{alice_id}", headers=bob).status_code == 404
    assert auth_client.get(f"/api/v1/analyses/{alice_id}", headers=alice).status_code == 200  # toujours là
    # Même réponse pour « appartient à un autre » et « n'existe pas » : pas de fuite d'existence
    missing = auth_client.get(f"/api/v1/analyses/{uuid.uuid4()}", headers=bob)
    assert missing.json() == auth_client.get(f"/api/v1/analyses/{alice_id}", headers=bob).json()


def test_delete_own_analysis_then_404(auth_client) -> None:
    headers = bearer(auth_client)
    analysis_id = predict(auth_client, headers).json()["prediction_id"]
    assert auth_client.delete(f"/api/v1/analyses/{analysis_id}", headers=headers).status_code == 204
    assert auth_client.get(f"/api/v1/analyses/{analysis_id}", headers=headers).status_code == 404
    assert auth_client.get("/api/v1/analyses/not-a-uuid", headers=headers).status_code == 422


def test_delete_account_removes_user_and_cascades_analyses(auth_client, db_engine) -> None:
    headers = bearer(auth_client)
    bob = bearer(auth_client, "bob@example.com", OTHER_PASSWORD)
    predict(auth_client, headers)
    predict(auth_client, bob)
    assert auth_client.delete("/api/v1/auth/me", headers=headers).status_code == 204
    assert auth_client.get("/api/v1/auth/me", headers=headers).status_code == 401
    with db_engine.connect() as connection:
        assert connection.scalar(text("SELECT count(*) FROM users")) == 1
        assert connection.scalar(text("SELECT count(*) FROM analyses")) == 1  # celles de Bob restent


def test_uncertain_prediction_is_saved_without_class(db_engine, database_url, model_service) -> None:
    settings = Settings(_env_file=None, database_url=database_url, jwt_secret=JWT_SECRET, confidence_threshold=1.0)
    with TestClient(create_app(settings, model_service=model_service)) as client:
        headers = bearer(client)
        predict(client, headers)
        item = client.get("/api/v1/analyses", headers=headers).json()["items"][0]
    assert item["status"] == "uncertain" and item["predicted_class"] is None and item["confidence_score"] > 0


# ---------- configuration absente (ne nécessite pas PostgreSQL) ----------

def test_auth_and_history_unavailable_without_database_or_secret(model_service) -> None:
    with TestClient(create_app(Settings(_env_file=None), model_service=model_service)) as client:
        assert error_code(register(client)) == "database_unavailable"
        assert error_code(client.get("/api/v1/analyses")) == "database_unavailable"
        assert predict(client).status_code == 200  # la prédiction anonyme continue de fonctionner
        assert predict(client, {"Authorization": "Bearer x"}).status_code == 503


def test_short_jwt_secret_is_rejected_at_startup() -> None:
    with pytest.raises(ValueError):
        Settings(_env_file=None, jwt_secret="too-short")
