# Database Design — AgriScan AI

## 1. Objectif

PostgreSQL conserve les données structurées nécessaires à l'application. Les images ne doivent pas être stockées automatiquement dans la base : leur stockage doit faire l'objet d'une décision explicite tenant compte du coût, de la confidentialité et de la rétention.

## 2. Tables proposées

Le schéma ci-dessous est une proposition de départ. Il doit être adapté au système d'authentification choisi et aux exigences réelles.

### `users`
- `id` : UUID, clé primaire.
- `email` : unique, si l'email est utilisé pour l'identification.
- `password_hash` : hash sécurisé, uniquement si l'authentification locale est retenue.
- `role` : rôle contrôlé côté serveur.
- `created_at` : date de création.
- `is_active` : état du compte.

Ne jamais stocker de mot de passe en clair.

### `model_versions`
- `id` : UUID, clé primaire.
- `version` : identifiant unique de version.
- `artifact_uri` : référence contrôlée vers l'artefact du modèle.
- `class_mapping` : mapping des labels ou référence vers un fichier versionné.
- `preprocessing_version` : version du prétraitement.
- `metrics_summary` : résumé des métriques réellement mesurées.
- `created_at` : date de création.

Ne pas exposer publiquement les chemins privés ou les emplacements sensibles des artefacts.

### `analyses`
- `id` : UUID, clé primaire.
- `user_id` : clé étrangère vers `users`, nullable uniquement si les analyses anonymes sont explicitement autorisées.
- `model_version_id` : clé étrangère vers `model_versions`.
- `predicted_class` : label retourné, nullable en cas d'incertitude.
- `status` : état documenté de la prédiction.
- `confidence_score` : score numérique, nullable si indisponible.
- `image_reference` : référence privée optionnelle, pas une URL publique par défaut.
- `created_at` : date de création.

Ne conserver que les données nécessaires. Définir une politique de suppression des analyses et images.

## 3. Relations

- Un utilisateur peut avoir plusieurs analyses.
- Une version de modèle peut être utilisée par plusieurs analyses.
- Chaque analyse référence la version du modèle qui l'a produite.

## 4. Index et contraintes

- Index sur `analyses.user_id`.
- Index sur `analyses.created_at` si les historiques sont triés par date.
- Contrainte d'unicité sur `model_versions.version`.
- Contrôles serveur sur les valeurs de `status`.
- Contraintes de clés étrangères pour préserver l'intégrité.

## 5. Migrations et accès

Utiliser un outil de migrations tel qu'Alembic si SQLAlchemy est retenu. Ne pas modifier le schéma de production manuellement sans migration versionnée.

Toutes les requêtes sur l'historique doivent être limitées à l'utilisateur autorisé. Une simple connaissance de l'identifiant d'une analyse ne donne jamais le droit d'y accéder.

## 6. Variables d'environnement

La chaîne de connexion doit provenir d'une variable d'environnement, par exemple `DATABASE_URL`. La valeur réelle ne doit pas être committée.

## Documents liés

- [Architecture](ARCHITECTURE.md)
- [API Specification](API_SPECIFICATION.md)
- [Security](SECURITY.md)
