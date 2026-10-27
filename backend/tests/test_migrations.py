"""Migrations Alembic : schéma attendu, contraintes, cohérence avec les modèles, retour arrière."""

import uuid

import pytest
from alembic import command
from alembic.autogenerate import compare_metadata
from alembic.migration import MigrationContext
from sqlalchemy import inspect, text
from sqlalchemy.exc import IntegrityError

from app.models import Base
from tests.conftest import alembic_config


def test_schema_has_expected_tables_columns_and_indexes(migrated_engine) -> None:
    inspector = inspect(migrated_engine)
    assert {"users", "model_versions", "analyses"} <= set(inspector.get_table_names())
    assert {"id", "email", "password_hash", "role", "is_active", "created_at"} <= {
        c["name"] for c in inspector.get_columns("users")}
    assert {"id", "user_id", "model_version_id", "predicted_class", "status", "confidence_score",
            "image_reference", "created_at"} <= {c["name"] for c in inspector.get_columns("analyses")}
    indexed = {tuple(i["column_names"]) for i in inspector.get_indexes("analyses")}
    assert ("user_id",) in indexed and ("user_id", "created_at") in indexed
    assert any(u["column_names"] == ["version"] for u in inspector.get_unique_constraints("model_versions"))
    assert any(u["column_names"] == ["email"] for u in inspector.get_unique_constraints("users"))


def test_models_match_migrations(migrated_engine) -> None:
    with migrated_engine.connect() as connection:
        diff = compare_metadata(MigrationContext.configure(connection), Base.metadata)
    assert diff == []


def test_database_rejects_invalid_values(migrated_engine) -> None:
    user_id, version_id = uuid.uuid4(), uuid.uuid4()
    with migrated_engine.begin() as connection:
        connection.execute(text("TRUNCATE analyses, model_versions, users CASCADE"))
        connection.execute(text("INSERT INTO users (id, email, password_hash) VALUES (:i, 'a@x.io', 'h')"),
                           {"i": user_id})
        connection.execute(text("INSERT INTO model_versions (id, version, class_mapping, preprocessing_version) "
                                "VALUES (:i, 'v1', '[]', 'p')"), {"i": version_id})
    insert = ("INSERT INTO analyses (id, user_id, model_version_id, status, confidence_score, scores) "
              "VALUES (:id, :u, :m, :s, :c, '{}')")
    base = {"u": user_id, "m": version_id, "s": "prediction_available", "c": 0.5}
    bad_cases = [
        {**base, "s": "made_up_status"},
        {**base, "c": 1.5},
        {**base, "u": uuid.uuid4()},
    ]
    for case in bad_cases:
        with pytest.raises(IntegrityError), migrated_engine.begin() as connection:
            connection.execute(text(insert), {"id": uuid.uuid4(), **case})
    with pytest.raises(IntegrityError), migrated_engine.begin() as connection:
        connection.execute(
            text("INSERT INTO users (id, email, password_hash, role) VALUES (:i, 'b@x.io', 'h', 'root')"),
            {"i": uuid.uuid4()})
    with pytest.raises(IntegrityError), migrated_engine.begin() as connection:
        connection.execute(text("INSERT INTO model_versions (id, version, class_mapping, preprocessing_version) "
                                "VALUES (:i, 'v1', '[]', 'p')"), {"i": uuid.uuid4()})  # version déjà utilisée


def test_downgrade_then_upgrade_round_trip(migrated_engine, database_url) -> None:
    config = alembic_config(database_url)
    command.downgrade(config, "base")
    assert "analyses" not in inspect(migrated_engine).get_table_names()
    command.upgrade(config, "head")
    assert "analyses" in inspect(migrated_engine).get_table_names()
