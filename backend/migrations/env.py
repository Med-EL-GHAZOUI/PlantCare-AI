"""Environnement Alembic : l'URL provient de la configuration applicative (variable d'environnement)."""

from alembic import context
from sqlalchemy import create_engine, pool

from app.config import Settings
from app.models import Base

config = context.config
target_metadata = Base.metadata


def database_url() -> str:
    explicit = config.get_main_option("sqlalchemy.url")  # permet aux tests de cibler une base dédiée
    if explicit:
        return explicit
    url = Settings().database_url
    if url is None:
        raise SystemExit("AGRISCAN_DATABASE_URL n'est pas défini.")
    return url.get_secret_value()


def run_migrations_offline() -> None:
    context.configure(url=database_url(), target_metadata=target_metadata, literal_binds=True)
    with context.begin_transaction():
        context.run_migrations()


def run_migrations_online() -> None:
    engine = create_engine(database_url(), poolclass=pool.NullPool)
    with engine.connect() as connection:
        context.configure(connection=connection, target_metadata=target_metadata)
        with context.begin_transaction():
            context.run_migrations()
    engine.dispose()


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
