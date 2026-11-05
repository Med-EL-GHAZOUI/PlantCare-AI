# Organisation des branches Git — AgriScan AI

État au 2026-11-05. Dépôt : <https://github.com/Med-EL-GHAZOUI/PlantCare-AI>.

## 1. Modèle

| Branche | Rôle | Qui écrit dedans |
|---|---|---|
| `main` | version **stable** : tout ce qui y est passe les hooks et les tests ; chaque jalon (fin de phase) y est fusionné | fusions depuis `develop` uniquement |
| `develop` | **intégration** : on y réunit le travail des branches `feature/*` avant de le stabiliser | fusions depuis `feature/*` |
| `feature/ml` | modèle, jeux de données, entraînement, évaluation (`ml/`) | travail sur le machine learning |
| `feature/backend` | API FastAPI, base PostgreSQL, authentification, export filigrané (`backend/`, `infra/`) | travail sur l'API |
| `feature/mobile` | application Flutter (`mobile/`) | travail sur l'application mobile |
| `feature/field-validation` | validation terrain : collecte, protocole, évaluation externe (`docs/field/`, `ml/` côté terrain) | Phase 7 |
| `feature/web-dashboard` | tableau de bord Angular (`web/`), Phase 6 optionnelle | à démarrer après validation du parcours principal |
| `feature/deployment` | déploiement, HTTPS, sauvegardes, intégration continue (Phase 8) | à démarrer plus tard |

**À la création, toutes les branches pointent sur le même commit** : elles ne divergent pas encore. Les branches `feature/web-dashboard` et `feature/deployment` sont des points de départ réservés (`web/` est vide, rien n'est déployé).

## 2. Flux de travail

1. Partir de `develop` à jour : `git switch develop && git pull`.
2. Travailler dans la branche du composant (ou dans une sous-branche courte `feature/<composant>-<sujet>`, par exemple `feature/mobile-export-pdf`).
3. Commits petits et lisibles, message à l'impératif en anglais préfixé par le type : `feat(mobile): …`, `fix(api): …`, `docs(field): …`, `test(ml): …`, `build:`, `chore:`.
4. Les hooks locaux s'exécutent à chaque commit et à chaque push ([DEV_HOOKS.md](DEV_HOOKS.md)). Ne pas les contourner sans raison ; ils ne remplacent pas une revue.
5. Ouvrir une **pull request** de la branche vers `develop`, relire le diff (soi-même ou un tiers), puis fusionner.
6. En fin de phase, une pull request `develop` → `main` ; puis une étiquette de jalon, par exemple `git tag -a phase-4 -m "PostgreSQL et comptes"` et `git push origin phase-4`.

Règles : pas de commit direct sur `main` ni `develop` ; pas de `push --force` sur `main`, `develop` ni sur une branche partagée (sauf accord explicite de l'équipe, avec `--force-with-lease`) ; aucune donnée sensible, aucun `.env`, aucun modèle ni jeu de données dans Git.

## 3. Protéger les branches (réglage GitHub à faire par le propriétaire)

Ce réglage se fait dans GitHub, pas dans le dépôt : **Settings → Branches → Add branch ruleset** (ou règle de protection) pour `main` et `develop` : exiger une pull request avant fusion, bloquer les poussées forcées et les suppressions. Aucune intégration continue n'existe encore : on ne peut donc pas exiger de vérification automatique ; ajouter un workflow GitHub Actions rendrait cette exigence possible (travail de la Phase 8, voir la [feuille de route](ROADMAP.md)). Je n'ai pas pu appliquer ce réglage moi-même (pas d'outil GitHub authentifié ici).

## 4. Historique réécrit le 2026-11-05

Les messages de commit ont été réécrits (retrait d'une mention de co-auteur) et `main` a été poussée en force. Les commits antérieurs ont de nouveaux identifiants. Tout clone fait avant cette date doit être mis à jour : `git fetch origin && git reset --hard origin/main` (en sauvegardant d'abord le travail local non poussé).
