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

### MobileNetV2 (transfer learning) — résultats sur la **validation** (2026-10-27)

Code : `ml/agriscan_ml/models.py` (`build_mobilenetv2`, `unfreeze_for_finetuning`), `ml/scripts/train_mobilenet.py`. Entrée 224×224 RGB ; conversion `x/127.5 − 1` dans le modèle ; poids ImageNet de Keras (`mobilenet_v2_weights_tf_dim_ordering_tf_kernels_1.0_224_no_top.h5`). Graine 42, CPU Windows.

- Phase 1 : base gelée, tête seule (12 810 paramètres entraînables), lr 1e-3, 6 époques (val_accuracy 0,804 → 0,867).
- Phase 2 : 19 couches finales dégelées (les BatchNorm restent gelées), lr 1e-5, 10 époques (val_accuracy 0,896 → 0,939). La perte de validation baissait encore à la dernière époque (0,181) : l'entraînement s'est arrêté au maximum d'époques fixé, pas par convergence.
- Poids de classes équilibrés ; augmentation sur l'entraînement uniquement.

| Métrique (validation) | Baseline CNN | MobileNetV2 |
|---|---|---|
| Accuracy | 0,7825 | **0,9391** |
| Macro-F1 | 0,7450 | **0,9211** |

| Classe | Précision | Rappel | F1 | Support |
|---|---|---|---|---|
| Bacterial spot | 0,942 | 0,915 | 0,928 | 319 |
| Early blight | 0,897 | 0,693 | 0,782 | 150 |
| Late blight | 0,934 | 0,944 | 0,939 | 287 |
| Leaf Mold | 0,944 | 0,937 | 0,940 | 143 |
| Septoria leaf spot | 0,911 | 0,929 | 0,920 | 266 |
| Spider mites | 0,939 | 0,913 | 0,926 | 252 |
| Target Spot | 0,799 | 0,962 | 0,873 | 211 |
| Yellow Leaf Curl Virus | 0,996 | 0,980 | 0,988 | 804 |
| Mosaic virus | 0,915 | 0,964 | 0,939 | 56 |
| healthy | 0,956 | 0,996 | 0,975 | 239 |

Principales confusions restantes : early blight pris pour target spot (17 sur 150) ou late blight (11) ; spider mites pris pour target spot (13). Early blight reste la classe la plus faible (rappel 0,693).

Précautions : une seule exécution, validation PlantVillage uniquement (fond uniforme, fuite résiduelle possible), aucun intervalle de confiance. La validation a servi à l'arrêt anticipé ; le choix final du modèle doit donc être confirmé sur le **test**, qui n'a pas été utilisé. Non mesuré : performance sur photos de terrain, latence, calibration.

### MobileNetV2 — évaluation finale sur le **test** (2026-10-27)

Évaluation unique (`scripts/evaluate.py --split test --final`) sur `test.csv` (2 721 images), après le choix du modèle sur la validation. Le modèle (`model.keras`, SHA-256 débutant par `10a733ad75f033ea`, identique avant et après l'évaluation) n'a pas été modifié ni ré-entraîné ensuite ; aucun réglage n'a été fait à partir de ces résultats.

| Métrique (test) | Résultat |
|---|---|
| Accuracy | **0,9449** |
| Macro-F1 | **0,9325** |

| Classe | Précision | Rappel | F1 | Support |
|---|---|---|---|---|
| Bacterial spot | 0,939 | 0,962 | 0,950 | 319 |
| Early blight | 0,940 | 0,727 | 0,820 | 150 |
| Late blight | 0,935 | 0,955 | 0,945 | 286 |
| Leaf Mold | 0,958 | 0,958 | 0,958 | 143 |
| Septoria leaf spot | 0,925 | 0,932 | 0,929 | 265 |
| Spider mites | 0,928 | 0,920 | 0,924 | 251 |
| Target Spot | 0,806 | 0,948 | 0,871 | 210 |
| Yellow Leaf Curl Virus | 0,994 | 0,970 | 0,982 | 803 |
| Mosaic virus | 0,981 | 0,946 | 0,964 | 56 |
| healthy | 0,975 | 0,992 | 0,983 | 238 |

Confusions principales : early blight pris pour target spot (14 sur 150) ou late blight (11) ; spider mites pris pour target spot (16 sur 251) ; yellow leaf curl virus pris pour bacterial spot (12 sur 803). Matrice complète : `ml/artifacts/mobilenetv2/confusion_test.csv` (non versionnée). Les résultats test sont cohérents avec la validation (0,9391 / 0,9211), sans écart suspect.

Limites : une seule exécution et un seul découpage, sans intervalle de confiance ; les classes à faible effectif (mosaic virus : 56 images) donnent des estimations bruitées. Le test provient de PlantVillage (même distribution que l'entraînement, fuite résiduelle possible entre photos d'une même feuille, voir DATASET_CARD) : **ces scores ne prouvent pas la performance sur des photos de terrain**, qui reste à mesurer avec des images indépendantes. Latence et calibration : non mesurées.

### Seuil d'incertitude — analyse sur la **validation** (2026-10-27)

Méthode : `ml/scripts/threshold_analysis.py` (fonctions dans `ml/agriscan_ml/selective.py`, 5 tests). Pour chaque seuil de 0,00 à 0,99 (pas de 0,01), une image est « répondue » si son score softmax maximal est ≥ seuil, sinon « incertaine ». On mesure la **couverture** (part répondue) et la **précision sélective** (accuracy sur les images répondues, intervalle de Wilson à 95 %). Les 2 727 images de validation ont été utilisées ; **le test n'est pas lu** par le script. Fichiers produits (non versionnés) : `artifacts/mobilenetv2/threshold_curve_val.csv` et `threshold_val.json`.

| Seuil | Couverture | Précision sélective [IC 95 %] | Erreurs gardées |
|---|---|---|---|
| 0,00 (aucun) | 1,000 | 0,9391 [0,930 ; 0,947] | 166 |
| 0,50 | 0,985 | 0,9464 [0,937 ; 0,954] | 144 |
| 0,60 | 0,961 | 0,9592 [0,951 ; 0,966] | 107 |
| 0,70 | 0,926 | 0,9719 [0,965 ; 0,978] | 71 |
| **0,80** | **0,887** | **0,9806 [0,974 ; 0,985]** | **47** |
| 0,85 | 0,865 | 0,9852 [0,979 ; 0,989] | 35 |
| 0,90 | 0,827 | 0,9902 [0,985 ; 0,994] | 22 |
| 0,95 | 0,761 | 0,9933 [0,989 ; 0,996] | 14 |
| 0,98 | 0,675 | 0,9962 [0,992 ; 0,998] | 7 |
| 0,99 | 0,606 | 0,9982 [0,995 ; 0,999] | 3 |

Règle fixée avant de lire la courbe : plus petit seuil dont la précision sélective atteint 0,97 avec une couverture ≥ 0,80. Résultat brut : **0,69** (couverture 0,931, précision 0,9712, IC95 [0,964 ; 0,977]).

**Seuil proposé : 0,80.** Le seuil 0,69 atteint la cible de 0,97 avec 0,0012 de marge seulement, sur un seul découpage : il est instable. Arrondir à 0,80 donne une marge nette (précision sélective 0,981, soit 47 erreurs gardées contre 166 sans seuil) pour 11,3 % d'images déclarées incertaines. C'est un choix de produit modifiable : 0,90 donnerait 0,990 de précision pour 17,3 % d'incertitudes.

Coût par classe à 0,69 (couverture de chaque classe) : early blight 0,787 (la plus touchée, c'est aussi la plus faible du modèle), bacterial spot 0,887, septoria 0,891, contre 0,981 pour yellow leaf curl virus et 0,987 pour healthy. À 0,80, davantage d'images de ces classes passeraient en « incertain ».

Limites : (1) la validation a servi à l'arrêt anticipé et au choix du seuil, donc la précision sélective annoncée est légèrement optimiste ; elle doit être **confirmée une fois sur le test** avant de la citer comme résultat final, et sur des images de terrain. (2) Le score softmax n'est pas calibré (aucune évaluation de calibration) : le seuil est un point de fonctionnement empirique, pas une probabilité de 80 %. (3) Ce seuil ne détecte **pas** les images hors périmètre : une photo qui n'est pas une feuille de tomate peut obtenir un score élevé. (4) Il filtre des cas incertains sur PlantVillage, pas nécessairement sur des photos de terrain.

Activation dans l'API : `AGRISCAN_CONFIDENCE_THRESHOLD=0.80` (désactivé par défaut tant que le choix n'est pas validé).

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
