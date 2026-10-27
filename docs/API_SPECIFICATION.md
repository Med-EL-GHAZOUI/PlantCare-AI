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
