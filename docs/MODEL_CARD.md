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

### Prétraitement implémenté (baseline, code dans `ml/agriscan_ml/`)

- Décodage JPEG/PNG en **RGB** (3 canaux), redimensionnement **bilinéaire** en **128×128** (`PreprocessConfig`), sortie float32 dans [0, 255].
- La division par 255 est faite **dans le modèle** (couche `Rescaling`) : l'inférence n'a donc qu'à décoder et redimensionner.
- Mapping des labels : indices attribués par ordre alphabétique des 10 classes présentes dans `train.csv` ; sauvegardé dans `class_names.json` à l'entraînement.
- Augmentation (**entraînement uniquement**) : flips horizontal/vertical, rotation ±0,1 tour, zoom 0,1, luminosité 0,1, contraste 0,1 (`AugmentationConfig`). Validation et test : aucune transformation aléatoire (vérifié par tests).
- Déséquilibre : poids de classes `n / (K × n_classe)` calculés sur l'entraînement seulement.

## 5 bis. Baseline CNN (non entraînée à ce jour)

3 blocs Conv2D(16/32/64, 3×3)+MaxPooling, GlobalAveragePooling, Dropout 0,3, Dense softmax ; 24 234 paramètres, entraîné de zéro, Adam 1e-3, graine 42, arrêt anticipé sur `val_loss`. Les scores softmax ne sont pas calibrés. **Aucune métrique n'existe encore** : la section 6 reste vide tant qu'aucun entraînement réel n'a eu lieu.

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

### Baseline CNN — résultats sur la **validation** (2026-10-27)

Entraînement réel sur CPU Windows (`scripts/train_baseline.py --train`, graine 42, 15 époques maximum) : arrêt anticipé après 14 époques, poids restaurés à la meilleure `val_loss` (0,675, époque 11). Évaluation avec `scripts/evaluate.py` sur `val.csv` (2 727 images). Le **jeu de test n'a pas été utilisé** (le script le verrouille derrière `--final`).

| Métrique (validation) | Résultat |
|---|---|
| Accuracy | 0,7825 |
| Macro-F1 | 0,7450 |

| Classe | Précision | Rappel | F1 | Support |
|---|---|---|---|---|
| Bacterial spot | 0,820 | 0,812 | 0,816 | 319 |
| Early blight | 0,694 | 0,500 | 0,581 | 150 |
| Late blight | 0,864 | 0,686 | 0,765 | 287 |
| Leaf Mold | 0,767 | 0,713 | 0,739 | 143 |
| Septoria leaf spot | 0,897 | 0,624 | 0,736 | 266 |
| Spider mites | 0,544 | 0,742 | 0,628 | 252 |
| Target Spot | 0,583 | 0,768 | 0,663 | 211 |
| Yellow Leaf Curl Virus | 0,952 | 0,866 | 0,907 | 804 |
| Mosaic virus | 0,643 | 0,964 | 0,771 | 56 |
| healthy | 0,738 | 0,987 | 0,844 | 239 |

Confusions principales (matrice complète : `artifacts/baseline/confusion_val.csv`, non versionnée) : early blight pris pour target spot (35 sur 150) ; late blight pris pour spider mites (37) ; yellow leaf curl virus pris pour spider mites (69) ou bacterial spot (32) ; target spot pris pour healthy (38).

Lecture prudente : ces chiffres proviennent d'une seule exécution, de la validation PlantVillage (conditions contrôlées, fuite résiduelle possible, voir DATASET_CARD) et d'un modèle volontairement simple. Ils ne mesurent pas la performance sur des photos de terrain. Les rangs de confusion servent de point de départ pour comparer MobileNetV2. Précision/rappel/F1 test, latence et calibration restent « À mesurer ».

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
