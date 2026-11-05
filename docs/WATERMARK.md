# Filigrane des sorties générées — AgriScan AI

État au 2026-11-05. Code : `backend/app/watermark.py`, `backend/app/exports.py`, `backend/app/decision.py`. Tests : `backend/tests/test_watermark.py`, `backend/tests/test_exports.py`.

## 1. Sorties concernées

| Sortie | Filigrane | État |
|---|---|---|
| **Image annotée exportée** (`POST /api/v1/predictions/annotated-image`) | oui, optionnel et configurable | **implémenté** |
| Rapport PDF | non applicable aujourd'hui | **non implémenté** : aucun rapport PDF n'existe. `compose_annotated_image` retourne une image Pillow réutilisable si un PDF est ajouté plus tard (cela exigerait une bibliothèque PDF, donc un coût de maintenance à justifier à ce moment-là) |
| Image envoyée par l'utilisateur | **jamais** | reste inchangée |
| Entrée du modèle, réponses JSON, historique | **jamais** | aucun filigrane |

L'application mobile n'utilise pas encore l'export.

## 2. Critères d'acceptation et vérification

| # | Critère | Vérifié par |
|---|---|---|
| 1 | Le filigrane n'est ajouté qu'**après** l'inférence, jamais avant | `test_inference_runs_on_the_original_before_any_watermark` : ordre des appels `predict` puis `compose`, et le modèle reçoit exactement les pixels de l'image envoyée |
| 2 | L'image d'origine n'est jamais modifiée ; le filigrane est dessiné sur une copie | `test_apply_watermark_never_modifies_the_input_image`, `test_compose_never_modifies_the_input_image`, test d'export (zone de l'image identique pixel pour pixel à l'upload) |
| 3 | Optionnel et configurable : texte, position, opacité, taille, marges | `WatermarkConfig` validée au démarrage ; options `AGRISCAN_WATERMARK_*` ; paramètre de requête `watermark=false` |
| 4 | Il ne masque pas d'indice visuel | placé dans une **bannière** à côté de l'image, jamais sur la feuille : tests sur 4 positions × 5 tailles (de 32×32 à 640×480) : rectangle du filigrane dans la bannière, sans intersection avec l'image ni la légende, zone de l'image strictement égale à l'original |
| 5 | Placement exact | 4 coins, marges respectées, rien ne déborde du rectangle annoncé |
| 6 | Dimensions de sortie prévisibles | largeur = largeur de l'image (minimum 240 px, image centrée non agrandie), hauteur = image + bannière ; réduction à `AGRISCAN_EXPORT_MAX_SIDE` (1024 par défaut) |
| 7 | Transparence | opacité 0 = invisible (pixels identiques), 1 = couleur exacte, intermédiaire = mélange avec le fond ; visibilité croissante avec l'opacité |
| 8 | Aucun stockage | test : le dossier de travail reste vide ; réponse `Cache-Control: no-store` |
| 9 | Mêmes contrôles d'entrée que `/predictions` | 415, 400, 413, 422, 503 testés |
| 10 | Rendu réel contrôlé | export d'une image de validation PlantVillage avec le vrai modèle (test dédié + contrôle visuel) |

## 3. Utilisation

```text
POST /api/v1/predictions/annotated-image            (multipart, champ « image »)
POST /api/v1/predictions/annotated-image?watermark=false
```

Réponse : image PNG. En-têtes : `X-Prediction-Id`, `X-Watermark` (`applied` ou `none`), `Cache-Control: no-store`. Pas d'authentification requise (comme `/predictions`) ; l'export n'est pas ajouté à l'historique.

Configuration (variables d'environnement, voir `backend/.env.example`) :

| Variable | Défaut | Rôle |
|---|---|---|
| `AGRISCAN_WATERMARK_ENABLED` | `true` | active le filigrane (la requête peut le surcharger avec `?watermark=`) |
| `AGRISCAN_WATERMARK_TEXT` | `AgriScan AI` | 1 à 40 caractères, au moins un caractère latin |
| `AGRISCAN_WATERMARK_POSITION` | `bottom-right` | `bottom-right`, `bottom-left`, `top-right`, `top-left` (la bannière est en haut pour `top-*`) |
| `AGRISCAN_WATERMARK_OPACITY` | `0.6` | de 0 (invisible) à 1 (opaque) |
| `AGRISCAN_WATERMARK_SIZE_RATIO` | `0.04` | hauteur de police ÷ largeur de l'image (0 exclu à 0,2) |
| `AGRISCAN_WATERMARK_MARGIN_RATIO` | `0.02` | marge ÷ largeur de l'image (0 à 0,1) |
| `AGRISCAN_EXPORT_MAX_SIDE` | `1024` | plus grand côté de l'image exportée (64 à 4096) |

Des réglages invalides empêchent le démarrage de l'API (pas de valeur corrigée en silence).

## 4. Décisions de conception

- **Bannière plutôt que filigrane sur la feuille** : le critère « ne pas masquer d'indice visuel » prime. Conséquence : le filigrane est **facile à retirer** (il suffit de rogner la bannière). Un filigrane sur l'image le protégerait mieux mais abîmerait justement l'indice visuel (tache, bord de feuille). Un marquage invisible ou des métadonnées signées ne sont pas implémentés.
- **Légende dans la bannière** : classe proposée (ou « Résultat incertain »), score du modèle, et la mention « Dépistage par IA, pas un diagnostic confirmé ». Le score est celui du modèle, non calibré. La légende passe à la ligne (6 lignes au plus) dans l'espace laissé par le filigrane.
- **Accents retirés au dessin** : la police intégrée à Pillow rend mal les lettres accentuées (constaté sur un export réel : glyphes cassés). Le texte est dessiné sans accents (« Dépistage » → « Depistage »). Une police complète à embarquer (fichier et licence à gérer) permettrait de les conserver. Les écritures non latines (arabe) ne sont pas prises en charge dans l'image exportée.
- **Noms de classes** : étiquettes du modèle nettoyées (« Late blight »), pas les noms traduits de l'application mobile.
- **Pas de dépendance ajoutée** : Pillow est déjà utilisé pour la validation des images.

## 5. Résultats réels

- `backend` : **119 tests réussis** (dont 73 pour le filigrane et l'export), `ruff` sans remarque.
- Défauts trouvés par les tests ou le contrôle visuel, corrigés : (1) sur une image de 32 px de large, le filigrane débordait du cadre → largeur minimale de 240 px avec image centrée ; (2) accents mal rendus → retrait des accents au dessin ; (3) légende tronquée sur les images 256 px de PlantVillage → retour à la ligne ; (4) un découpage de mot trop long était quadratique (test à 5 000 caractères) → recherche dichotomique et texte borné.
- Contrôle visuel de deux exports réels (image de validation, vrai modèle, 256×300 px environ) : légende lisible sur plusieurs lignes, filigrane « AgriScan AI » en bas à droite, ou en haut à gauche avec bannière en haut, feuille intacte.

## 6. Limites, droits et vie privée

- **Un filigrane visible ne prouve pas l'authenticité** d'une image ou d'un rapport et n'empêche ni la modification ni le retrait ; il indique seulement que l'image a été produite par l'application. Ne pas le présenter comme une preuve.
- Le texte « AgriScan AI » identifie le **générateur**, pas le propriétaire de la photo ; ne pas y mettre une mention de droit d'auteur sans en avoir le droit.
- L'image envoyée est traitée en mémoire et renvoyée à l'appelant ; elle n'est ni stockée ni journalisée. La politique de conservation des images reste « aucune » (voir [SECURITY.md](SECURITY.md)).
- Les images du jeu PlantVillage n'ont pas de licence confirmée pour une redistribution ou un usage commercial (voir [DATASET_CARD.md](DATASET_CARD.md)) : ne pas diffuser d'exports de ces images.
- L'export ne contient aucun conseil de traitement ni dosage.
- L'export reste anonyme et non limité en débit au-delà des plafonds de taille de l'API ; l'inférence a le même coût qu'une prédiction.
