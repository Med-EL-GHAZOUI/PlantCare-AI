# Hooks de développement — AgriScan AI

État au 2026-11-05. Configuration : `.pre-commit-config.yaml`, `.markdownlint-cli2.yaml`, `.secrets.baseline`, `scripts/hooks/run_component_checks.py`.

Les hooks détectent les erreurs courantes avant qu'elles n'entrent dans l'historique. **Ils ne remplacent ni une intégration continue ni une revue de code** : ils tournent sur la machine du développeur et se contournent (voir section 5). Aucune intégration continue n'existe encore dans ce dépôt.

## 1. Ce qui est vérifié

Composants présents : Python (`ml/`, `backend/`), Dart/Flutter (`mobile/`), documentation Markdown. `web/` (Angular) est vide : **aucun hook Angular** tant que ce composant n'existe pas.

| Étape | Hook | Rôle |
|---|---|---|
| pre-commit (quelques secondes, fichiers indexés) | `trailing-whitespace`, `end-of-file-fixer` | corrige espaces en fin de ligne et fin de fichier (hors `AGENTS.md`, fichiers générés, `mobile/android`, `mobile/ios`, `ml/data`) |
| | `check-merge-conflict`, `check-case-conflict` | marqueurs de conflit, noms ne différant que par la casse |
| | `check-added-large-files` (1 Mo) | bloque modèles `.keras`, jeux de données, archives |
| | `check-yaml`, `check-toml`, `check-json` | syntaxe des fichiers de configuration et des traductions `.arb` |
| | `detect-private-key` | clés privées en clair |
| | `ruff-check` | lint Python de `ml/` et `backend/` (règles lues dans leur `pyproject.toml`) |
| | `detect-secrets` | secrets probables (jetons, mots de passe, chaînes à forte entropie) comparés à `.secrets.baseline` |
| | `markdownlint-cli2` | structure des documents Markdown (nécessite Node.js) |
| | `forbid-secret-files` | refuse `.env`, `.env.*` (sauf `.env.example`), `key.properties`, `google-services.json`, `jwt_secret`, `*.jks`, `*.keystore`, `*.pem`, `*.p12`, `*.pfx` |
| pre-push (≈ 3 minutes pour les trois composants) | `ml-tests` | `pytest` dans `ml/.venv` si des fichiers de `ml/` changent |
| | `backend-tests` | `pytest` dans `backend/.venv` (inclut PostgreSQL embarqué `pgserver`) si `backend/` change |
| | `mobile-checks` | `flutter analyze` puis `flutter test` si `mobile/lib`, `mobile/test` ou `pubspec.yaml` changent |

Jamais dans un hook : entraînement de modèle, téléchargement de données, lancement d'émulateur ou de test d'intégration sur appareil.

## 2. Installation (une fois par clone)

Prérequis : Git, Python 3.11, Node.js (pour `markdownlint`), les environnements `ml/.venv` et `backend/.venv` (voir [ENVIRONMENT.md](ENVIRONMENT.md)), Flutter dans le `PATH` pour le hook mobile. Depuis la racine du dépôt :

```powershell
backend\.venv\Scripts\python.exe -m pip install -r backend\requirements-dev.txt   # inclut pre-commit et detect-secrets
backend\.venv\Scripts\python.exe -m pre_commit install                            # installe pre-commit ET pre-push
```

La première exécution télécharge les dépôts de hooks (GitHub, npm) et prend une à deux minutes ; elles sont ensuite mises en cache. `pre-commit install` écrit `.git/hooks/pre-commit` et `.git/hooks/pre-push` ; il **refuse d'écraser un hook existant non géré par pre-commit** (avant installation ici, `.git/hooks` ne contenait que les fichiers `.sample` de Git).

## 3. Utilisation

```powershell
backend\.venv\Scripts\python.exe -m pre_commit run --all-files                          # étape pre-commit sur tout le dépôt
backend\.venv\Scripts\python.exe -m pre_commit run --hook-stage pre-push --all-files    # inclut les tests (≈ 3 min)
backend\.venv\Scripts\python.exe -m pre_commit run ruff-check --all-files               # un seul hook
backend\.venv\Scripts\python.exe -m pre_commit autoupdate                               # mettre à jour les versions épinglées (puis relire le diff)
```

Les hooks s'exécutent automatiquement à `git commit` et `git push`. Les correcteurs (`trailing-whitespace`, `end-of-file-fixer`) modifient les fichiers et font échouer le commit : relancer `git add` puis `git commit`.

## 4. Mesures réelles (2026-11-05, ce PC)

- Dépôt entier, étape pre-commit, environnements en cache : **10 secondes**.
- Étape pre-push complète (ML + API + Flutter, tous les fichiers concernés) : **184 secondes**, tous les hooks réussis.
- Essais négatifs avec des fichiers jetables : un fichier `backend/.env.local` est refusé ; un `import` inutilisé est signalé par `ruff-check` (F401) ; une fausse clé AWS d'exemple est signalée par `detect-secrets` ; un espace en fin de ligne dans un `.md` est corrigé automatiquement. Les fichiers de test ont été supprimés.
- `git push` réel non exercé (aucun push effectué) : l'étape pre-push n'a été exécutée que via `pre-commit run --hook-stage pre-push`.

## 5. Contournement et limites

- `git commit --no-verify` et `git push --no-verify` désactivent tous les hooks. `SKIP=ml-tests,backend-tests git push` ignore des hooks précis (noms de la colonne « Hook »). Ces contournements sont légitimes ponctuellement mais **rien ne les empêche ni ne les signale** : seule une intégration continue côté serveur ferait foi.
- Un hook ne vérifie que l'état de la machine locale : versions d'outils et environnements virtuels peuvent différer d'un poste à l'autre.
- `detect-secrets` produit des faux positifs et des faux négatifs. `.secrets.baseline` liste 17 détections **revues à la main le 2026-11-05** (valeurs factices de test, libellés d'interface « mot de passe », identifiants Xcode et révision Flutter, image JPEG synthétique en base64) ; aucune n'est un vrai secret. Après un nouveau faux positif légitime : `backend\.venv\Scripts\detect-secrets.exe scan --baseline .secrets.baseline`, relire, puis marquer `is_secret: false` ou corriger. Un vrai secret déjà commité doit être **révoqué**, pas seulement supprimé (voir [SECURITY.md](SECURITY.md)).
- `forbid-secret-files` et `.gitignore` ne protègent que des noms de fichiers connus.
- Les tests de `pre-push` ne s'exécutent que si des fichiers du composant changent dans l'ensemble des fichiers examinés par pre-commit ; un changement de dépendance dans un autre composant peut passer inaperçu.

## 6. Choix de conception

- **`ruff check` seulement, pas `ruff format` ni `dart format`** : le code existant n'est pas formaté automatiquement ; imposer un formateur provoquerait un énorme diff sans valeur de sécurité. À reprendre en un commit dédié si l'équipe le souhaite.
- **Règles Markdown allégées** : les règles de lignes vides, de style de tableau et d'URL nues sont désactivées (≈ 170 avertissements purement cosmétiques sur les documents existants). Les règles de structure restent actives.
- **`AGENTS.md` exclu des correcteurs et de `markdownlint`** : c'est le fichier d'instructions du projet, il ne doit pas être réécrit automatiquement (la première exécution l'avait modifié sur 90 lignes ; la modification a été annulée).
- **Tests au `pre-push`, pas au `pre-commit`** : 3 minutes à chaque commit découragerait de commiter souvent.
- **`pgserver` pour les tests API** : voir [ENVIRONMENT.md](ENVIRONMENT.md) ; Docker n'est pas nécessaire.
- Dépendances ajoutées et coût de maintenance : `pre-commit` et `detect-secrets` (dev uniquement, versions épinglées dans `backend/requirements-dev.txt`), dépôts de hooks épinglés par version dans `.pre-commit-config.yaml` ; prévoir un `autoupdate` périodique.

## 7. Dépannage

| Symptôme | Cause probable | Action |
|---|---|---|
| `pre-commit : commande introuvable` | outil installé seulement dans `backend/.venv` | appeler `backend\.venv\Scripts\python.exe -m pre_commit …`, ou activer l'environnement |
| Hook mobile : « `flutter` introuvable » | Flutter absent du `PATH` de Git | ajouter Flutter au `PATH` ou définir `FLUTTER_BIN` |
| Hook ML/API : « environnement virtuel introuvable » | `ml/.venv` ou `backend/.venv` absent | recréer l'environnement ([ENVIRONMENT.md](ENVIRONMENT.md)) ou `SKIP=ml-tests` |
| `markdownlint-cli2` échoue à l'installation | Node.js absent ou réseau coupé | installer Node.js ; le hook peut être ignoré avec `SKIP=markdownlint-cli2` |
| Le commit échoue avec « files were modified by this hook » | un correcteur a réparé des fichiers | `git add` puis relancer `git commit` |
| `detect-secrets` signale une chaîne légitime | faux positif | auditer et mettre à jour `.secrets.baseline` (section 5) |
| Premier lancement très long | téléchargement des dépôts de hooks | normal, une seule fois |
