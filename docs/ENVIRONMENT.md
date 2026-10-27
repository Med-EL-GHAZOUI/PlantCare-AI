# Environnement de développement — AgriScan AI

Relevé réel effectué le 2026-10-27 (Phase 0 de la [Roadmap](ROADMAP.md)). À refaire si la machine change.

## 1. Machine

| Élément | Valeur relevée |
|---|---|
| Système | Windows 11 Famille 10.0.26300 |
| RAM | 15,7 Go |
| GPU | NVIDIA GeForce RTX 4060 Laptop (8 Go VRAM, pilote 621.01) + Intel UHD |
| Disque C: libre | 168 Go |
| Répertoire du projet | `C:\Users\Victus\Desktop\AgriScan AI` |

## 2. Outils

| Outil | État |
|---|---|
| Python | 3.11.9 (`python`) ; le lanceur `py` est absent |
| Git | 2.53.0 |
| Java | JDK 17.0.12 |
| Flutter / Dart | Flutter 3.41.0 stable ; `flutter doctor` : aucun problème (Android SDK 36, Chrome, Windows, 3 appareils) |
| Node.js | 22.17.0 ; Angular CLI (`ng`) présent (Phase 6 uniquement) |
| Docker | CLI présent, démon **arrêté** |
| PostgreSQL | **absent** (ni `psql` ni `pg_ctl`) |
| WSL2 | Seule la distribution `docker-desktop` existe |

## 3. Paquets Python (environnement global)

Présents : fastapi 0.136.3, uvicorn 0.41.0, pydantic 2.13.4, pydantic-settings, SQLAlchemy 2.0.50, alembic 1.18.4, psycopg 3.3.4, python-multipart, httpx, numpy 2.4.6, pandas 3.0.3, pillow 12.2.0, scikit-learn 1.9.0, opencv, black, keras 3.15.1, torch 2.12.1.

Absents : **tensorflow**, pytest, ruff, pre-commit.

## 4. Points d'attention

1. **TensorFlow n'est pas installé.** Keras 3 est présent mais sans backend TensorFlow (torch est installé, ce qui n'est pas le choix documenté). Installer TensorFlow dans un environnement virtuel dédié.
2. **Pas de GPU natif sous Windows pour TensorFlow récent** : sur Windows natif, TensorFlow ne s'exécute que sur CPU. Le GPU RTX 4060 n'est utilisable que via WSL2 (Ubuntu à installer). Pour un MobileNetV2 sur un dataset de feuilles, le CPU est possible mais lent ; décision à prendre avant la Phase 2.
3. **Environnement global mélangé** (torch, keras, opencv…) : créer un `.venv` par composant pour reproduire l'installation et éviter les conflits de versions.
4. **PostgreSQL** : installer localement ou démarrer Docker Desktop (Phase 4).
5. Les dossiers `backend/`, `ml/`, `mobile/`, `web/`, `infra/` sont vides.

## 5. Environnement ML (`ml/.venv`)

Décision : entraînement sur **CPU Windows natif** (le GPU reste inutilisé ; WSL2 pourra être envisagé plus tard).

Installation, depuis `C:\Users\Victus\Desktop\AgriScan AI\ml` :

```powershell
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements-dev.txt
```

Versions vérifiées le 2026-10-27 : `tensorflow-cpu` 2.21.0, Keras 3.15.1 (backend tensorflow), NumPy 2.4.6, pytest 9.1.1, ruff 0.17.3. Test réalisé : import de TensorFlow, construction de MobileNetV2 (`weights=None`, 3 classes, 2 261 827 paramètres) et passage avant sur une entrée de zéros ; il valide l'installation uniquement, pas un modèle. `tf.config.list_physical_devices('GPU')` renvoie une liste vide, comme attendu.

Pillow, scikit-learn, pandas et matplotlib seront ajoutés à `requirements.txt` quand le pipeline de données en aura besoin.

## 6. Décisions ouvertes

- PostgreSQL : installation locale ou conteneur Docker.
- Dataset : PlantVillage seul, ou PlantDoc en complément (licence à vérifier, voir [Dataset Card](DATASET_CARD.md)).
