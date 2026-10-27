# Dataset Card — AgriScan AI

## 1. Objectif

Documenter chaque source de données utilisée pour entraîner, sélectionner ou tester le classifieur de feuilles de tomate.

## 2. Sources candidates

- **PlantVillage** : candidat pour une première expérience de classification sur des images de feuilles.
- **PlantDoc** : candidat pour étudier des images plus variées, prises dans des conditions plus proches du terrain.
- **Images locales collectées indépendamment** : utiles pour une évaluation externe au Maroc, avec les autorisations nécessaires.

Ces sources sont des candidates. Vérifier la licence de la version exacte téléchargée, les conditions d'accès et l'usage commercial autorisé. Ne pas présumer qu'une page de téléchargement autorise automatiquement la redistribution ou la commercialisation.

## 3. Informations à enregistrer

Pour chaque dataset :
- nom officiel et URL ;
- version et date de téléchargement ;
- licence et restrictions ;
- nombre réel d'images téléchargées ;
- noms des classes et nombre d'images par classe ;
- dimensions et formats ;
- images corrompues, manquantes ou dupliquées ;
- méthode de collecte ;
- biais connus et conditions de prise de vue ;
- provenance et autorisations des images locales.

## 4. Découpage des données

Créer des ensembles distincts :
- entraînement ;
- validation ;
- test final.

Éviter les fuites : regrouper les doublons et les images issues de la même capture ou d'une série très proche avant de répartir les données lorsque c'est pertinent. Les augmentations ne doivent être appliquées qu'aux images d'entraînement. Le test final ne sert pas à choisir le modèle ou les seuils.

## 5. Prétraitement

Documenter :
- dimensions d'entrée ;
- ordre des canaux couleur ;
- normalisation des pixels ;
- mapping label-indice ;
- transformations d'augmentation ;
- prétraitement d'entraînement et d'inférence.

Le prétraitement en production doit correspondre exactement à celui attendu par le modèle.

## 6. Évaluation

Rapporter des mesures réellement calculées :
- accuracy ;
- précision et rappel par classe ;
- F1-score par classe ;
- macro-F1 ;
- matrice de confusion ;
- résultats sur des images réelles indépendantes, si disponibles.

Ne pas inventer de métriques ni présenter les résultats d'un dataset public comme une garantie de performance sur le terrain.

## 7. Limites

Les images contrôlées peuvent différer des images prises dans les champs marocains : éclairage, arrière-plan, appareil photo, variété de plante, stade de maladie et maladies simultanées. Une évaluation locale est nécessaire avant de revendiquer une fiabilité pratique.

## Documents liés

- [Project Context](PROJECT_CONTEXT.md)
- [Architecture](ARCHITECTURE.md)
- [Model Card](MODEL_CARD.md)
- [Security](SECURITY.md)
