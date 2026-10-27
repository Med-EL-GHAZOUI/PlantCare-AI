# API Specification — AgriScan AI

## 1. Principes

- Préfixe de version : `/api/v1`.
- Transport HTTPS en production.
- JSON pour les réponses.
- `multipart/form-data` pour l'envoi d'une image.
- Schémas Pydantic pour valider les requêtes et réponses.
- Les exemples ci-dessous sont illustratifs et doivent être alignés sur le code réel.

## 2. `GET /api/v1/health`

Vérifie que le processus API répond.

Exemple :
```json
{
  "status": "ok"
}
```

Un statut `ok` ne prouve pas à lui seul que le modèle et la base de données sont prêts. Une vérification de readiness peut être ajoutée.

## 3. `GET /api/v1/model/info`

Renvoie la version du modèle et les classes supportées.

Exemple :
```json
{
  "model_version": "baseline-1",
  "supported_classes": ["healthy", "early_blight", "late_blight"]
}
```

Les labels doivent correspondre exactement au mapping du modèle entraîné ; cet exemple n'affirme pas que toutes ces classes seront retenues.

## 4. `POST /api/v1/predictions`

Entrée :
- champ `image` obligatoire dans une requête `multipart/form-data`.

Traitement :
1. Vérifier la taille et le contenu du fichier.
2. Décoder l'image et rejeter les fichiers invalides.
3. Appliquer le prétraitement attendu.
4. Exécuter le modèle.
5. Appliquer la politique d'incertitude documentée.
6. Retourner une réponse structurée.

Exemple de réponse :
```json
{
  "prediction_id": "example-id",
  "predicted_class": "healthy",
  "confidence": 0.91,
  "status": "prediction_available",
  "model_version": "baseline-1",
  "disclaimer": "Résultat de dépistage par IA, pas un diagnostic confirmé."
}
```

Les valeurs sont fictives et servent uniquement à illustrer le contrat.

Statuts envisagés :
- `prediction_available`
- `uncertain`
- `unsupported_input`

La réponse d'un cas incertain peut ne pas inclure de classe prédite. Un score de confiance n'est pas nécessairement une probabilité calibrée.

## 4 bis. État réel de l'implémentation (Phase 3, 2026-10-27)

Code : `backend/app/`. Les exemples ci-dessus restent illustratifs ; le contrat réel est le suivant.

**Critères d'acceptation** (tous vérifiés par `backend/tests/`) :
1. `GET /api/v1/health` répond 200 `{"status":"ok","model_loaded":bool}` même sans modèle.
2. `GET /api/v1/model/info` renvoie la version (`<nom>-<12 premiers caractères du SHA-256 de model.keras>`), les classes exactement comme dans `class_names.json`, la taille d'entrée, `confidence_is_calibrated: false`, `out_of_scope_detection: false` et le seuil d'incertitude actif ; 503 si le modèle est indisponible.
3. `POST /api/v1/predictions` (champ `image`, JPEG ou PNG) renvoie 200 avec `prediction_id`, `status`, `predicted_class`, `confidence`, `scores` (toutes les classes, somme ≈ 1), `model_version`, `disclaimer`.
4. Le modèle est chargé une seule fois au démarrage (lifespan) et réutilisé ; l'inférence est protégée par un verrou.
5. Entrées invalides rejetées avec le format d'erreur commun : fichier absent (422 `invalid_request`), type déclaré non pris en charge ou format réel autre que JPEG/PNG (415 `unsupported_media_type`), fichier vide (400 `empty_file`), contenu corrompu ou tronqué (400 `invalid_image`), trop volumineux (413 `file_too_large`, lecture interrompue dès la limite), image trop petite ou trop grande en pixels (422 `image_too_small` / `image_dimensions_too_large`).
6. Aucune stack trace, chemin ou secret dans les erreurs ; erreur inattendue = 500 `internal_error` générique.
7. Prétraitement d'inférence cohérent avec l'entraînement (test avec le vrai modèle : même classe prédite, écart de probabilité maximal mesuré 0,034 sur 45 images de test, dû aux décodeurs JPEG différents ; test automatisé sur 8 images de validation avec tolérance 0,06).
8. Aucune prédiction simulée : les tests de contrat utilisent un vrai petit modèle Keras créé à la volée (poids aléatoires, sans valeur agronomique), le test de bout en bout utilise le vrai modèle.

**Format d'erreur** : `{"error": {"code": "<code>", "message": "<texte>"}}`.

**Politique d'incertitude** : `AGRISCAN_CONFIDENCE_THRESHOLD` (désactivé par défaut). Si défini et que le score softmax maximal lui est inférieur, la réponse est `status: "uncertain"` avec `predicted_class: null`. Aucun seuil n'a été choisi sur les données de validation : tant que ce n'est pas fait, toute image reçoit une classe. Le statut `unsupported_input` n'est **pas implémenté** : le modèle n'a pas de détection hors périmètre (une photo qui n'est pas une feuille de tomate recevra quand même une classe de tomate).

**Données** : l'image envoyée n'est ni stockée ni journalisée ; elle n'existe qu'en mémoire pendant la requête. Le nom de fichier du client est ignoré. Pas d'authentification à ce stade (routes d'historique non implémentées). CORS désactivé sauf `AGRISCAN_CORS_ORIGINS`.

**Mesure réelle** : latence médiane d'inférence ≈ 135 ms par image (CPU Windows, 45 images, hors décodage HTTP) ; chargement du modèle ≈ 1,5 s. Mesure ponctuelle, à refaire sur le matériel de déploiement.

**Lancer** (depuis `backend/`) :
```powershell
python -m venv .venv; .\.venv\Scripts\python.exe -m pip install -r requirements-dev.txt
.\.venv\Scripts\python.exe -m uvicorn app.main:app --port 8000
.\.venv\Scripts\python.exe -m pytest -q
```
Configuration : `backend/.env.example`. La documentation interactive est disponible sur `/docs`.

## 5. Historique protégé

### `GET /api/v1/analyses`
Renvoie uniquement l'historique autorisé de l'utilisateur authentifié.

### `GET /api/v1/analyses/{prediction_id}`
Renvoie une analyse si l'utilisateur a le droit d'y accéder.

### `DELETE /api/v1/analyses/{prediction_id}`
Supprime l'analyse autorisée selon la politique de rétention. La suppression d'une image stockée, si elle existe, doit être coordonnée.

Ces routes privées ne doivent être activées qu'après mise en place et test de l'authentification et de l'autorisation.

## 6. Erreurs

Prévoir des réponses cohérentes pour :
- format non pris en charge ;
- fichier trop volumineux ;
- image corrompue ;
- modèle indisponible ;
- authentification manquante ou invalide ;
- accès interdit ;
- ressource inexistante ;
- erreur interne.

Ne pas exposer de stack trace, de secret ou de chemin interne.

## 7. Tests de contrat

Les tests doivent vérifier les codes HTTP, la structure des réponses, les cas invalides et le respect des droits d'accès.

## Documents liés

- [Architecture](ARCHITECTURE.md)
- [Database](DATABASE.md)
- [Security](SECURITY.md)
- [Model Card](MODEL_CARD.md)
