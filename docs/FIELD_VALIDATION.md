# Validation terrain — protocole et outillage

État au 2026-11-05 (Phase 7 de la [Roadmap](ROADMAP.md)).

**Ce qui est fait** : le protocole de collecte et d'évaluation, les scripts de contrôle et de mesure, leurs tests, et des modèles de documents ([field/TEMPLATES.md](field/TEMPLATES.md), [field/manifest_template.csv](field/manifest_template.csv)).
**Ce qui n'est PAS fait** : aucune image de terrain n'a été collectée et **aucune performance hors PlantVillage n'a été mesurée**. Les scores de la [Model Card](MODEL_CARD.md) (accuracy test 0,9449, précision sélective 0,9778 au seuil 0,80) concernent PlantVillage ; il faut s'attendre à ce qu'ils baissent sur des photos réelles (hypothèse à vérifier, ampleur inconnue). Le rapport de validation terrain et la décision de correction (critères de sortie de la phase) restent à produire après la collecte.

## 1. Questions auxquelles la validation répond

1. Quelle est la performance sur les 10 classes de tomate avec des photos prises dans des conditions réelles (lumière, fond, appareil) ?
2. Que fait le modèle devant une image **hors périmètre** (autre culture, autre maladie, pas de feuille) ? Le modèle n'a pas de détection hors périmètre : on mesure avec quelle fréquence il propose quand même une classe.
3. Le seuil de confiance 0,80 (choisi sur PlantVillage) se comporte-t-il de façon acceptable sur ces images ? On l'**observe** ; on ne le règle pas sur le jeu de test.
4. Quelles conditions dégradent les résultats (lumière, fond, appareil, expertise de l'étiqueteur) ?
5. L'application est-elle comprise et utilisable (retours d'utilisateurs, [questionnaire](field/TEMPLATES.md)) ?

## 2. Principes (non négociables)

- **Indépendance** : aucune image PlantVillage. Le script de validation bloque tout doublon exact ou quasi-doublon (empreinte perceptuelle à 2 bits) d'une image de `ml/data/manifest.csv`.
- **Consentement** : chaque image a un consentement documenté (`consent = yes`) ; sans lui, le manifeste est refusé.
- **Vie privée** : pas de personnes sur les photos ; les coordonnées GPS EXIF sont **refusées** par le validateur (outil de nettoyage : `ml/scripts/strip_exif.py`) ; le site est un code, pas une adresse ; les images et le manifeste restent hors Git (`ml/data/*` est ignoré, seuls `ml/data/splits/` sont versionnés).
- **Étiquetage indépendant du modèle** : par un expert (agronome, technicien), jamais d'après la prédiction du modèle (biais de confirmation). Deux experts si possible ; désaccord = arbitrage, sinon `label_certainty = uncertain` (image exclue des métriques par défaut).
- **Une plante, un seul découpage** : `dev` (comprendre les erreurs, éventuellement ré-entraîner) et `test` (une seule évaluation finale). Le validateur refuse un `subject_id` présent dans les deux.
- **Critères fixés avant de regarder les résultats** (section 6).
- **Aucune recommandation de traitement ni dosage**, quel que soit le résultat.

## 3. Plan de collecte

**Sources autorisées** (à identifier avec l'encadrant) : exploitations, serres, coopératives, établissement d'enseignement agricole, techniciens partenaires, avec accord écrit (modèle de consentement dans [field/TEMPLATES.md](field/TEMPLATES.md), à faire relire). Les images prises par l'équipe ou fournies avec droits clairs uniquement ; ne pas récupérer d'images sur Internet sans vérifier la licence.

**Effectifs de référence** (propositions, pas des seuils de validité) :

| Cible | Repère minimal | Pourquoi |
|---|---|---|
| Par classe (10 classes) | 30 images de 10 plantes au moins | avec 27 réussites sur 30 (0,90), l'IC à 95 % est [0,74 ; 0,97] (largeur 0,22) ; avec 90 sur 100 : [0,83 ; 0,94] (largeur 0,12) — chiffres calculés par `wilson_interval` |
| Hors périmètre | 100 images environ, trois familles : autres cultures, tomates avec maladie/carence hors des 10 classes, non-feuilles (sol, main, fond) | estimer un taux de fausses acceptations à ± 10 points près |
| Diversité | 2 sites au moins, 2 appareils au moins, lumière et fonds variés, plusieurs stades | un seul site ou appareil ne représente pas le terrain |

Plus de plantes vaut mieux que plus de photos par plante : les photos d'une même plante sont corrélées. Les classes rares (virus de la mosaïque, par exemple) peuvent ne pas atteindre le repère : le rapport doit alors dire « non évaluable de façon fiable » plutôt que donner un chiffre.

**Consignes de prise de vue** : [field/TEMPLATES.md](field/TEMPLATES.md), section 2.

## 4. Préparer et contrôler les données

Arborescence (hors Git) :

```text
ml/data/field/
  images/            photos nettoyées (sans EXIF)
  manifest.csv       une ligne par image (modèle : docs/field/manifest_template.csv)
```

Colonnes obligatoires : `path`, `label` (nom d'une des 10 classes du modèle, `out_of_scope` ou `other_disease`), `subject_id` (une plante ou une feuille), `split` (`dev` ou `test`), `site`, `capture_date` (AAAA-MM-JJ), `device`, `lighting` (`full_sun`, `shade`, `overcast`, `indoor`, `flash`), `background` (`plain`, `soil`, `foliage`, `hand`, `other`), `labeler`, `labeler_expertise` (`agronomist`, `technician`, `farmer`, `student`), `label_certainty` (`certain`, `probable`, `uncertain`), `consent` (`yes`), `source`.

Depuis `C:\Users\Victus\Desktop\AgriScan AI\ml` :

```powershell
# 1. Retirer les métadonnées (GPS) des photos brutes, sans toucher aux originaux
.\.venv\Scripts\python.exe scripts/strip_exif.py --src data/field/raw_photos --dst data/field/images
# 2. Valider le manifeste et les fichiers : consentement, GPS, doublons, fuite PlantVillage, effectifs
$env:PYTHONPATH="."; .\.venv\Scripts\python.exe scripts/validate_field_manifest.py --manifest data/field/manifest.csv
```

Le validateur échoue (code 1) sur : colonne ou valeur invalide, consentement absent, fichier manquant/illisible/trop petit (< 64 px), GPS présent, doublon exact, image identique ou quasi identique à PlantVillage, plante présente dans `dev` et `test`. Il avertit (sans échouer) quand une classe est sous le repère d'effectif.

## 5. Mesurer

```powershell
# dev : comprendre les erreurs (autant de fois que nécessaire)
.\.venv\Scripts\python.exe scripts/evaluate_external.py --split dev
# test : une seule exécution finale ; refuse de se relancer et exige --final
.\.venv\Scripts\python.exe scripts/evaluate_external.py --split test --final
```

Sorties dans `ml/artifacts/mobilenetv2/field/` (hors Git) : `field_eval_<split>.json` et `field_report_<split>.md`. Le script revalide le manifeste, n'évalue que les images de `label_certainty = certain` (option `--min-certainty probable` pour inclure les probables), applique le seuil **fixé** `--threshold 0.80`, et rapporte :

- dans le périmètre : accuracy, précision/rappel/F1 par classe, macro-F1 sur les classes **présentes**, matrice de confusion, confiance moyenne des bonnes et des mauvaises réponses, **intervalle à 95 % par rééchantillonnage des plantes** (1 000 tirages, graine 42) ;
- au seuil : couverture et précision sélective (intervalle de Wilson, naïf : il ignore le regroupement par plante et est donc optimiste) ;
- par condition : lumière, fond, appareil, expertise de l'étiqueteur, site (les groupes de moins de 20 images sont signalés « peu fiables ») ;
- hors périmètre : taux de **fausses acceptations** (une classe est proposée alors qu'aucune ne convient), par famille, avec intervalle de Wilson.

## 6. Critères de décision (à fixer avant la collecte)

Remplir ce tableau **avant** de lire un résultat, avec l'encadrant et, idéalement, un agronome. Les valeurs ci-dessous sont des exemples de format, pas des recommandations : le seuil acceptable dépend de l'usage prévu et des conséquences d'une erreur.

| Critère | Mesure | Seuil décidé par l'équipe |
|---|---|---|
| Performance globale | borne basse de l'IC 95 % du macro-F1 (classes présentes, test) | _à fixer_ |
| Fiabilité des réponses données | borne basse de l'IC de la précision sélective au seuil 0,80 | _à fixer_ |
| Classes critiques (par exemple mildiou) | rappel minimal par classe | _à fixer_ |
| Hors périmètre | taux maximal de fausses acceptations | _à fixer_ |
| Conditions | pire groupe d'éclairage/fond/appareil avec n ≥ 20 | _à fixer_ |

**Corrections possibles selon l'écart constaté** (chacune à valider sur un nouveau jeu test) : collecter davantage de photos pour les classes ou conditions faibles puis ré-entraîner ou affiner le modèle avec `dev` seulement ; relever le seuil de confiance (nouvelle courbe sur `dev`) ; ajouter une détection hors périmètre (classe « autre » ou seuil sur l'entropie) et la mesurer ; réduire les classes annoncées ; renforcer les consignes de prise de vue dans l'application ; renoncer à certains usages. **Jamais** de réglage sur le jeu `test` après l'avoir lu : s'il est utilisé pour décider, il faut en collecter un nouveau.

## 7. Rapport de validation terrain (à produire après la collecte)

Plan : contexte et dates ; sources, sites, appareils, effectifs par classe et par plante ; accord entre étiqueteurs ; résultats `dev` puis `test` (tableaux de `field_report_*.md`) ; erreurs les plus fréquentes avec exemples ; cas hors périmètre ; effet des conditions ; retours d'utilisateurs ; limites (représentativité, effectifs, un seul découpage) ; décision documentée sur les corrections (section 6) ; mise à jour de la [Model Card](MODEL_CARD.md).

## 8. Vérifications réelles de l'outillage

- `pytest` dans `ml/` : **66 tests réussis**, dont 30 pour cette phase (validation du manifeste : consentement, valeurs invalides, fichiers manquants/corrompus/trop petits, GPS, doublons exacts, fuite PlantVillage exacte et quasi-doublon, plante en `dev` et `test` ; métriques sur des cas calculés à la main : accuracy, précision/rappel, macro-F1 des classes présentes, précision sélective et couverture, fausses acceptations hors périmètre, bootstrap par plante déterministe, signalement des groupes à faible effectif, nettoyage EXIF). `ruff` sans remarque.
- Essai de bout en bout avec le **vrai modèle** sur un jeu de **bruit synthétique** (36 images, aucune valeur agronomique) : le validateur accepte le jeu sain, rejette une image copiée de PlantVillage (doublon exact et quasi-doublon), l'évaluation `dev` produit le rapport, `test` sans `--final` est refusé, `test --final` s'exécute une fois puis refuse de se relancer, et un manifeste invalide bloque l'évaluation. Les chiffres de ce jeu (accuracy 0) n'ont aucun sens et ne doivent pas être cités.

## 9. Limites de l'outillage

- Les images sont lues à pleine résolution puis redimensionnées à 224 px comme à l'entraînement ; l'application réduit d'abord à 1024 px et recompresse en JPEG (qualité 90). L'écart n'est pas mesuré.
- L'intervalle par plante suppose des plantes indépendantes ; deux plantes voisines d'un même site restent corrélées (effet de site non corrigé : voir la ventilation par site).
- Le validateur détecte les quasi-doublons à 2 bits d'écart seulement : une photo différente d'une feuille PlantVillage n'est pas repérée.
- Les étiquettes dépendent de l'expert ; l'accord entre étiqueteurs n'est pas calculé par les scripts (à faire à part si deux experts étiquettent).
- Aucune évaluation de la **calibration** n'est faite ; le score reste « score du modèle », pas une probabilité.
