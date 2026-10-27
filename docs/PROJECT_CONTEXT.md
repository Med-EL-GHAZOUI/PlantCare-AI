# Project Context — AgriScan AI

## 1. Vision

Créer une plateforme qui aide à examiner des images de feuilles et à repérer des catégories de maladies prises en charge par un modèle de classification.

Le produit doit être compréhensible, testable et extensible. Sa pertinence commerciale au Maroc reste une hypothèse à vérifier par des entretiens utilisateurs et des essais sur le terrain.

## 2. MVP

Le premier MVP porte sur la tomate et sur les seules classes effectivement présentes dans le dataset retenu.

Fonctionnalités principales :
- Import d'une image depuis la galerie ou capture mobile.
- Validation de l'image.
- Inférence CNN via une API.
- Affichage de la classe prédite, des scores et des limites.
- Gestion des cas incertains ou hors périmètre si elle est évaluée.
- Historique pour les utilisateurs authentifiés.
- Documentation et tests reproductibles.

## 3. Utilisateurs cibles

- Agriculteurs et coopératives.
- Étudiants en agronomie.
- Techniciens agricoles.
- Administrateurs de la plateforme.

Ces profils sont des hypothèses de conception ; il faut confirmer leurs besoins avant de définir les fonctions payantes.

## 4. Stack cible

- Python et TensorFlow/Keras pour l'entraînement.
- MobileNetV2 comme candidat de transfer learning, comparé à une baseline.
- FastAPI pour l'API.
- PostgreSQL pour les métadonnées.
- Flutter pour l'application mobile.
- Angular pour un tableau de bord web ultérieur.

## 5. Principes produit

- Ne pas prétendre reconnaître une maladie absente des classes entraînées.
- Ne pas confondre un score de modèle avec une certitude médicale ou agronomique.
- Expliquer les limites et encourager une vérification par un spécialiste lorsque l'enjeu le justifie.
- Respecter les licences des données et les droits sur les images.
- Minimiser la collecte et la conservation des données personnelles.

## 6. Critères de réussite du MVP

- Entraînement reproductible.
- Évaluation documentée sur un test séparé.
- Endpoint d'inférence fonctionnel.
- Interface capable d'afficher les réponses et erreurs.
- Tests couvrant le parcours principal et les cas invalides.
- Installation documentée depuis un environnement propre.
- Limites et conditions d'utilisation explicites.

## Documents liés

- [Requirements](REQUIREMENTS.md)
- [Architecture](ARCHITECTURE.md)
- [Dataset Card](DATASET_CARD.md)
- [Model Card](MODEL_CARD.md)
- [API Specification](API_SPECIFICATION.md)
- [Roadmap](ROADMAP.md)
- [README principal](../README.md)
