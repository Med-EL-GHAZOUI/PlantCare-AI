"""Lance les vérifications rapides d'un composant (hook pre-push).

Usage : python scripts/hooks/run_component_checks.py {ml|backend|mobile}

- ml, backend : pytest dans l'environnement virtuel du composant (<composant>/.venv).
- mobile      : `flutter analyze` puis `flutter test` (Flutter doit être dans le PATH ou FLUTTER_BIN).

Échoue explicitement si un outil manque (jamais d'échec silencieux). Aucune de ces commandes ne lance
d'entraînement ni ne télécharge de données.
"""

from __future__ import annotations

import os
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def venv_python(component: str) -> Path:
    scripts = "Scripts" if os.name == "nt" else "bin"
    exe = "python.exe" if os.name == "nt" else "python"
    return ROOT / component / ".venv" / scripts / exe


def run(command: list[str], cwd: Path, env: dict[str, str] | None = None) -> int:
    print(f"$ ({cwd.relative_to(ROOT)}) {' '.join(command)}", flush=True)
    return subprocess.call(command, cwd=cwd, env=env)


def python_tests(component: str) -> int:
    python = venv_python(component)
    if not python.exists():
        print(f"ERREUR : environnement virtuel introuvable : {python}\n"
              f"Créez-le (voir docs/ENVIRONMENT.md) ou contournez ce hook : SKIP={component}-tests git push",
              file=sys.stderr)
        return 1
    env = dict(os.environ, TF_CPP_MIN_LOG_LEVEL="2")
    return run([str(python), "-m", "pytest", "-q", "-x"], ROOT / component, env)


def flutter_checks() -> int:
    flutter = os.environ.get("FLUTTER_BIN") or shutil.which("flutter")
    if not flutter:
        print("ERREUR : `flutter` introuvable (PATH ou variable FLUTTER_BIN).\n"
              "Contournement : SKIP=mobile-checks git push", file=sys.stderr)
        return 1
    mobile = ROOT / "mobile"
    return run([flutter, "analyze"], mobile) or run([flutter, "test", "--reporter", "failures-only"], mobile)


def main() -> int:
    if len(sys.argv) != 2 or sys.argv[1] not in {"ml", "backend", "mobile"}:
        print(__doc__, file=sys.stderr)
        return 2
    component = sys.argv[1]
    return flutter_checks() if component == "mobile" else python_tests(component)


if __name__ == "__main__":
    sys.exit(main())
