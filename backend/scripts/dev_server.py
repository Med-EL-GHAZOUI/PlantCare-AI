"""Serveur de développement local : PostgreSQL embarqué (pgserver) + migrations Alembic + API.

Usage (depuis backend/) :
    .\\.venv\\Scripts\\python.exe scripts/dev_server.py                 # 127.0.0.1:8000 (USB + adb reverse)
    .\\.venv\\Scripts\\python.exe scripts/dev_server.py --host 0.0.0.0  # accessible sur le réseau local

Les données (comptes, analyses) sont conservées dans backend/.devdata/ (ignoré par Git) entre deux
lancements. Le secret JWT est généré une fois et stocké dans backend/.devdata/jwt_secret. Pour tout
effacer : arrêter le script puis supprimer le dossier backend/.devdata/.

OUTIL DE DÉVELOPPEMENT UNIQUEMENT : pas de HTTPS, base sans mot de passe (écoute locale seulement),
pas de sauvegarde. Ne jamais l'exposer sur Internet.
"""

from __future__ import annotations

import argparse
import os
import secrets
import subprocess
import sys
import time
from pathlib import Path

import pgserver
from sqlalchemy import create_engine, text
from sqlalchemy.engine import make_url

BACKEND = Path(__file__).resolve().parents[1]
DATABASE = "agriscan_dev"


def ensure_database(admin_url) -> None:
    engine = create_engine(admin_url, isolation_level="AUTOCOMMIT")
    with engine.connect() as connection:
        exists = connection.scalar(text("SELECT 1 FROM pg_database WHERE datname = :n"), {"n": DATABASE})
        if not exists:
            connection.execute(text(f'CREATE DATABASE "{DATABASE}"'))
    engine.dispose()


def load_or_create_secret(path: Path) -> str:
    if path.exists():
        return path.read_text(encoding="utf-8").strip()
    secret = secrets.token_urlsafe(48)
    path.write_text(secret, encoding="utf-8")
    return secret


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=8000)
    parser.add_argument("--data-dir", type=Path, default=BACKEND / ".devdata")
    args = parser.parse_args()

    args.data_dir.mkdir(parents=True, exist_ok=True)
    server = pgserver.get_server(args.data_dir / "pg", cleanup_mode="stop")
    admin_url = make_url(server.get_uri()).set(drivername="postgresql+psycopg")
    ensure_database(admin_url)

    env = dict(
        os.environ,
        AGRISCAN_DATABASE_URL=admin_url.set(database=DATABASE).render_as_string(hide_password=False),
        AGRISCAN_JWT_SECRET=load_or_create_secret(args.data_dir / "jwt_secret"),
        TF_CPP_MIN_LOG_LEVEL="2",
    )
    subprocess.run([sys.executable, "-m", "alembic", "upgrade", "head"], cwd=BACKEND, env=env, check=True)

    api = subprocess.Popen(
        [sys.executable, "-m", "uvicorn", "app.main:app", "--host", args.host, "--port", str(args.port)],
        cwd=BACKEND,
        env=env,
    )
    print(f"\nAPI de développement : http://{args.host}:{args.port}  (santé : /api/v1/health, docs : /docs)", flush=True)
    print(f"Données conservées dans : {args.data_dir}  — Ctrl+C pour arrêter.\n", flush=True)
    try:
        while api.poll() is None:
            time.sleep(1)
    except KeyboardInterrupt:
        pass
    finally:
        api.terminate()
        try:
            api.wait(timeout=10)
        except subprocess.TimeoutExpired:
            api.kill()
        server.cleanup()


if __name__ == "__main__":
    main()
