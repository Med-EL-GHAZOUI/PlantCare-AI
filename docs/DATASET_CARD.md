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

## 4 bis. Vérification de licence — PlantVillage (état au 2026-10-27)

**Statut : licence NON confirmée à la source originale. Aucune image n'a encore été téléchargée.**

Constats issus de pages consultées :
- Le site d'origine (plantvillage.org) n'est plus disponible comme source de téléchargement, d'après la note de [TensorFlow Datasets](https://www.tensorflow.org/datasets/catalog/plant_village) : sa copie (54 303 images, 38 classes) provient d'un article tiers qui a republié les données. TFDS n'indique pas de licence propre au dataset.
- Le dépôt [spMohanty/PlantVillage-Dataset](https://github.com/spMohanty/PlantVillage-Dataset) (54 306 images, 14 espèces, dossiers `raw/color`, `raw/grayscale`, `raw/segmented`) n'affiche aucune licence.
- La publication [Mendeley Data tywbtsjrjv](https://data.mendeley.com/datasets/tywbtsjrjv/1) (Pandian & Gopal, 2019) est sous **CC0 1.0**, mais c'est un dérivé **augmenté** (61 486 images, 39 classes) : il ne convient pas pour un découpage sans fuite, car des variantes d'une même image peuvent se retrouver dans train et test.
- Des sources secondaires citent CC0 pour PlantVillage, sans lien vers un texte de licence d'origine ; la fiche OpenML de Meta-Album affiche des indications contradictoires (CC0 et CC BY-NC 4.0).
- Article de référence : [Hughes & Salathé, arXiv 1511.08060](https://arxiv.org/abs/1511.08060) ; Mohanty et al. (2016) pour l'usage en deep learning.

Conséquence : l'usage académique (PFE) est raisonnable, mais **l'usage commercial ne doit pas être présumé autorisé**. À faire avant toute commercialisation : contacter les auteurs/Penn State ou retrouver un texte de licence de la version exacte utilisée, et l'archiver dans ce document.

### Classes tomate attendues (10)

Bacterial spot, Early blight, Late blight, Leaf Mold, Septoria leaf spot, Spider mites (two-spotted), Target Spot, Yellow Leaf Curl Virus, Mosaic virus, healthy. Les effectifs varient selon la source (par ex. healthy : 1 589 à 1 591) ; les effectifs réels seront mesurés après téléchargement.

### Inventaire mesuré (2026-10-27)

Source : dépôt spMohanty, commit `7f7ecc7e1eaca78107e3affe7cb5abd9427e139a`, `raw/color/Tomato___*`, 324 Mo, dans `ml/data/raw/plantvillage_tomato/` (non versionné). Mesuré avec `ml/scripts/inspect_dataset.py`.

| Classe | Images |
|---|---|
| Bacterial spot | 2 127 |
| Early blight | 1 000 |
| Late blight | 1 909 |
| Leaf Mold | 952 |
| Septoria leaf spot | 1 771 |
| Spider mites (two-spotted) | 1 676 |
| Target Spot | 1 404 |
| Yellow Leaf Curl Virus | 5 357 |
| Mosaic virus | 373 |
| healthy | 1 591 |
| **Total** | **18 160** |

- Images corrompues : 0. Toutes en JPEG, RGB, 256×256.
- Doublons exacts (SHA-256) : 14 groupes, 14 images redondantes, aucun entre classes différentes. Les quasi-doublons (hash perceptuel `dhash` du manifeste) ne sont pas encore analysés.
- Déséquilibre marqué : de 373 (mosaic virus) à 5 357 (yellow leaf curl) images. Il faudra suivre le F1 par classe et envisager des poids de classes.
- Biais connu : images prises en conditions contrôlées, sur fond uniforme ; les performances sur photos de terrain ne sont pas démontrées.

Commande, depuis `ml/` : `.venv\Scripts\python.exe scripts/inspect_dataset.py data/raw/plantvillage_tomato --manifest data/manifest.csv`

### Découpage réalisé (2026-10-27)

Script : `ml/scripts/split_dataset.py` (graine 42, ratios 70/15/15). Depuis `ml/` :
`.venv\Scripts\python.exe scripts/split_dataset.py --manifest data/manifest.csv --out-dir data/splits`

- Groupes : union des doublons exacts (SHA-256) et des images dont le `dhash` diffère d'au plus **2 bits**. Seuil choisi après mesure sur le manifeste complet : à 0 bit, 14 groupes multiples ; à 2 bits, 23 ; à 4 bits, 57 dont 3 mêlant des classes différentes ; à 6 bits, 179 dont 28. Le seuil 2 évite les regroupements de classes différentes. Le seuil n'a pas été réglé sur le test.
- Résultat : train 12 712, val 2 727, test 2 721 images ; chaque classe est présente dans les trois ensembles (par exemple mosaic virus : 261 / 56 / 56). Détail dans `ml/data/splits/split_report.json`.
- Reproductibilité : deux exécutions successives produisent des fichiers CSV identiques (comparaison octet à octet).
- Les fichiers `train.csv`, `val.csv`, `test.csv` (chemin, classe, groupe) sont versionnés ; les images ne le sont pas.
- **Limite connue** : le hash perceptuel ne détecte que les images très proches. Des photos différentes de la même feuille (autre angle) ne sont pas regroupées, donc une fuite résiduelle est possible et les scores sur PlantVillage peuvent être optimistes. L'évaluation sur des images indépendantes reste nécessaire.

## 4 ter. Plan de téléchargement et de découpage (proposé)

1. **Source** : copier la version non augmentée (dossier `color`) via le dépôt spMohanty ou TFDS, enregistrer l'URL, le commit/la version, la date et le hash SHA-256 de l'archive. Les données vont dans `ml/data/raw/` (ignoré par Git).
2. **Inventaire** (`ml/scripts/inspect_dataset.py`) : lister classes et effectifs, vérifier que chaque image s'ouvre (Pillow), relever dimensions et formats, écrire un `manifest.csv` (chemin, classe, hash, taille).
3. **Doublons** : hash exact (SHA-256) puis hash perceptuel pour les quasi-doublons. PlantVillage contient plusieurs photos d'une même feuille ; l'identifiant de feuille n'étant pas fourni, on regroupe les images très proches en groupes.
4. **Découpage** : 70 % entraînement / 15 % validation / 15 % test, stratifié par classe, **par groupe** (jamais d'image d'un groupe sur deux ensembles), graine fixe (42). Résultat écrit dans `ml/data/splits/{train,val,test}.csv` et versionné (fichiers CSV légers, sans images).
5. **Contrôles automatiques** (pytest) : aucun chemin ni hash commun entre ensembles, toutes les classes présentes partout, proportions respectées.
6. **Augmentation** : uniquement à l'entraînement, dans le pipeline Keras, jamais sur val/test.
7. **Évaluation externe** : prévoir un jeu d'images réelles indépendantes (PlantDoc ou photos locales autorisées) car PlantVillage est pris en conditions contrôlées.

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
