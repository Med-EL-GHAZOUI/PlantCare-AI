# Model Card — AgriScan AI

## 1. Identification

- Nom : AgriScan AI Tomato Classifier
- Version : à renseigner après entraînement
- Type : classification d'images
- Famille : CNN
- Candidat initial : MobileNetV2 avec transfer learning
- Framework : TensorFlow/Keras
- Statut : en développement tant que l'évaluation n'est pas terminée

## 2. Usage prévu

Aider à examiner des images de feuilles de tomate et classer les images parmi les catégories réellement présentes dans le dataset et prises en charge par le modèle.

Le modèle ne constitue pas un diagnostic agricole confirmé et ne doit pas être utilisé seul pour décider d'un traitement coûteux ou risqué.

## 3. Données

Référencer la version exacte du dataset dans [Dataset Card](DATASET_CARD.md). Indiquer les classes, le nombre d'images, les licences, le découpage et les biais.

## 4. Prétraitement

Documenter après implémentation :
- format d'image accepté ;
- dimensions d'entrée ;
- conversion couleur ;
- normalisation ;
- mapping des labels ;
- version du code de prétraitement.

Le service d'inférence doit réutiliser le même prétraitement que le modèle d'entraînement.

## 5. Entraînement

Consigner :
- version Python et dépendances ;
- architecture et poids initiaux ;
- hyperparamètres ;
- graines aléatoires ;
- stratégie de fine-tuning ;
- nombre d'époques ;
- critères d'arrêt ;
- date et environnement d'entraînement.

## 6. Résultats

À compléter uniquement après une exécution réelle.

| Métrique | Résultat |
|---|---|
| Accuracy test | À mesurer |
| Macro-F1 test | À mesurer |
| Précision par classe | À mesurer |
| Rappel par classe | À mesurer |
| Matrice de confusion | À générer |
| Latence d'inférence | À mesurer sur matériel déclaré |

Ne pas remplacer « À mesurer » par des valeurs estimées ou inventées.

## 7. Incertitude et limites

Le score de sortie du modèle peut ne pas être une probabilité calibrée. Tout seuil d'incertitude doit être choisi à partir des données de validation et évalué.

Une classification standard peut attribuer une classe connue à une image hors périmètre. Le rejet des images inconnues nécessite une méthode explicite et une évaluation dédiée ; un seuil de confiance seul ne garantit pas la détection de toutes les images hors distribution.

## 8. Surveillance et mises à jour

Lorsqu'un modèle est remplacé :
- incrémenter sa version ;
- conserver le mapping de classes et le prétraitement ;
- exécuter les tests de régression ;
- comparer les métriques ;
- documenter les changements ;
- prévoir un retour à la version précédente.

## 9. Avertissement utilisateur

« Cette prédiction est une aide préliminaire et ne remplace pas l'avis d'un spécialiste agricole. La performance peut varier selon les conditions de prise de vue et les plantes observées. »

## Documents liés

- [Dataset Card](DATASET_CARD.md)
- [Architecture](ARCHITECTURE.md)
- [API Specification](API_SPECIFICATION.md)
- [Security](SECURITY.md)
