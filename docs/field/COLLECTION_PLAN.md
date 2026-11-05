# Plan de collecte terrain — 2 semaines

Complète le [protocole de validation terrain](../FIELD_VALIDATION.md) ; documents types : [TEMPLATES.md](TEMPLATES.md). Ce plan est une **proposition** à adapter aux contraintes réelles (saison, accès aux sites, disponibilité des experts). Rien ici n'a été validé auprès de partenaires : aucun partenaire, site ni date n'est connu à ce jour.

## 1. Objectif chiffré

Atteindre les repères du protocole, mesurables avec `scripts/field_progress.py` :

| Cible | Quantité | Détail |
|---|---|---|
| Dans le périmètre | 10 classes × 30 images ≈ **300 images** | 10 plantes par classe, 3 photos par plante |
| Hors périmètre | **≈ 100 images** | autres cultures, tomates avec maladie ou carence hors des 10 classes, non-feuilles (sol, main, fond) |
| Total | **≈ 400 images, ≈ 140 plantes** | 2 sites et 2 appareils au moins |

Rythme : 8 jours de terrain × **≈ 50 images par jour** (≈ 17 plantes × 3 photos, soit environ 1 h de prise de vue hors déplacements). Les plantes d'une classe doivent venir de plusieurs sites et de plusieurs jours.

**Réalité à anticiper** : la présence d'une maladie dépend de la saison et du site, et personne ne peut la planifier. Certaines classes (virus de la mosaïque, tache cible, acariens…) risquent de ne pas atteindre 30 images en deux semaines. Il ne faut ni forcer ni provoquer une maladie : on photographie ce qui existe, et le rapport indiquera « non évaluable de façon fiable » pour les classes sous le repère.

## 2. Rôles

| Rôle | Tâches | Qui |
|---|---|---|
| Responsable de collecte | contacts, planning, prise de vue, manifeste, validation quotidienne | vous |
| Expert étiqueteur 1 | pose le diagnostic **sur la plante**, indique la certitude | technicien ou agronome du site (à trouver) |
| Expert étiqueteur 2 | étiquette en aveugle un lot de photos (accord entre experts) | agronome / enseignant (à trouver) |
| Encadrant | fixe les critères de décision (section 6 du protocole), valide l'éthique et le consentement | à solliciter dès la semaine 0 |
| Testeurs de l'application | 5 à 8 utilisateurs, questionnaire de retour | agriculteurs, techniciens, étudiants volontaires |

## 3. Calendrier

| Période | Actions | Livrable |
|---|---|---|
| **Semaine 0 (avant le jour 1)** | contacter 2 sites au moins (messages section 6) ; obtenir l'accord écrit (consentement) ; faire relire le consentement ; **fixer avec l'encadrant les critères de décision** ; préparer 2 appareils ; créer `ml/data/field/` et tester la chaîne avec 5 photos | accords signés, critères écrits et datés |
| **Jours 1 à 5** (semaine 1) | collecte : 2 à 3 plantes de chaque classe disponible par jour, plus 5 à 10 images hors périmètre ; étiquetage sur site par l'expert 1 ; routine du soir (section 5) | ≈ 250 images, premier `field_progress` |
| **Jour 5 (fin de semaine)** | point d'avancement : classes manquantes, diversité (sites, appareils, éclairage, fonds) ; décider où aller en semaine 2 | liste des manques |
| **Jours 6 à 8** (semaine 2) | collecte ciblée sur les classes et conditions manquantes ; essais utilisateurs de l'application (questionnaire) | ≈ 400 images au total si possible |
| **Jour 9** | second expert : étiquetage en aveugle d'un lot (au moins 20 % des images, toutes les classes rares) puis `label_agreement.py` ; arbitrage des désaccords ; `validate_field_manifest.py` sans erreur ; évaluation `dev` pour comprendre les erreurs | rapport `dev`, accord entre experts |
| **Jour 10** | rappel des critères (déjà écrits en semaine 0) ; **évaluation `test` unique** (`--final`) ; début du rapport de validation | `field_report_test.md`, brouillon du rapport |

Si le calendrier glisse, on prolonge la collecte plutôt que de réduire les repères sans le dire. Le découpage `dev` / `test` se décide **par plante, avant** de lancer une évaluation (par exemple une plante sur deux, en veillant à avoir des deux découpages dans chaque classe).

## 4. Prise de vue : routine sur le terrain

1. Se présenter, rappeler la finalité, vérifier que le consentement est signé pour ce site.
2. Pour chaque plante : attribuer `subject_id` = `<code-site>-<numéro>` (par exemple `serreA-017`) ; l'écrire dans le carnet (pas d'étiquette collée sur la plante) ; l'expert 1 donne le diagnostic et sa certitude.
3. Prendre **3 photos** de la même feuille (distances ou angles différents) avec l'appareil photo du téléphone en mode normal : consignes de [TEMPLATES.md](TEMPLATES.md), section 2. Alterner les appareils, les éclairages et les fonds entre plantes.
4. Noter pour chaque plante : appareil, éclairage, fond, certitude, remarques (stade, plusieurs symptômes).
5. Hors périmètre : photographier aussi des feuilles d'autres cultures, des tomates avec maladie ou carence hors classes (l'expert l'indique : `other_disease`), des fonds sans feuille, des mains, du sol (`out_of_scope`).
6. **Hygiène** : se désinfecter les mains et nettoyer les chaussures entre deux sites, pour ne pas propager de maladie. Ne jamais toucher aux traitements, ne rien recommander (ni produit ni dosage) : « le résultat est une aide au dépistage, pas un diagnostic ».

## 5. Routine du soir (15 à 20 minutes)

Depuis `C:\Users\Victus\Desktop\AgriScan AI\ml`, avec les photos copiées dans `data/field/raw_photos/<site>/<date>/` :

```powershell
# 1. nettoyer les métadonnées (GPS) sans toucher aux originaux
.\.venv\Scripts\python.exe scripts/strip_exif.py --src data/field/raw_photos --dst data/field/images
# 2. compléter data/field/manifest.csv (UTF-8, modèle docs/field/manifest_template.csv)
# 3. contrôler : consentement, GPS, doublons, fuite PlantVillage, plante dans dev et test
$env:PYTHONPATH="."; .\.venv\Scripts\python.exe scripts/validate_field_manifest.py
# 4. mesurer l'avancement vers les repères
.\.venv\Scripts\python.exe scripts/field_progress.py
```

Règles de nommage : fichiers `<site>_<AAAA-MM-JJ>_<plante>_<n>.jpg` ; le `path` du manifeste est relatif à `data/field/images`. Sauvegarder chaque soir sur un second support (disque externe) ; **ne rien ajouter à Git** (`ml/data/*` est ignoré ; le validateur et les hooks bloquent aussi les fichiers sensibles). Un souci de consentement, un site qui se rétracte : retirer les photos du site et du manifeste le jour même.

## 6. Messages types (à personnaliser)

### 6.1 À une coopérative, un technicien ou une exploitation — français

> **Objet : Autorisation de photographier des feuilles de tomate pour un projet étudiant d'aide au dépistage**
>
> Bonjour [Nom],
>
> Je m'appelle [Prénom Nom], étudiant(e) à [établissement], et je réalise mon projet de fin d'études sur AgriScan AI, une application mobile qui aide à repérer des maladies de la feuille de tomate à partir d'une photo. L'outil est un **aide au dépistage, pas un diagnostic**, et ne propose aucun traitement.
>
> Pour savoir s'il fonctionne dans des conditions réelles, j'ai besoin de photographier des feuilles de tomate (saines ou atteintes) sur [2 à 3 demi-journées entre le … et le …]. Je souhaiterais, si possible, être accompagné(e) d'un technicien ou d'un agronome pour confirmer ce que nous photographions.
>
> Ce que je m'engage à faire : ne photographier que des feuilles (aucune personne), retirer les coordonnées GPS, ne pas publier les photos (seuls des résultats chiffrés agrégés apparaîtront), supprimer les photos de votre site si vous le demandez, respecter vos règles d'hygiène pour ne pas propager de maladie.
>
> Pourrions-nous en parler [par téléphone / sur place] cette semaine ? Je vous enverrai une courte fiche de consentement.
>
> Merci d'avance. [Prénom Nom] — [téléphone / courriel]

### 6.2 Même message — arabe

> **الموضوع: طلب إذن لتصوير أوراق الطماطم في إطار مشروع طلابي للكشف الأولي عن الأمراض**
>
> السلام عليكم [الاسم]،
>
> أنا [الاسم الكامل]، طالب(ة) في [المؤسسة]، وأنجز مشروع نهاية الدراسة حول AgriScan AI، وهو تطبيق للهاتف يساعد على الكشف الأولي عن أمراض أوراق الطماطم انطلاقًا من صورة. الأداة **مساعدة على الكشف وليست تشخيصًا**، ولا تقترح أي علاج.
>
> لمعرفة مدى نجاحها في الظروف الحقيقية، أحتاج إلى تصوير أوراق طماطم (سليمة أو مصابة) خلال [نصف يوم إلى ثلاثة أنصاف أيام بين … و…]. أودّ، إن أمكن، أن يرافقني تقني أو مهندس فلاحي لتأكيد ما نصوّره.
>
> أتعهد بما يلي: تصوير الأوراق فقط (دون أشخاص)، وحذف إحداثيات الموقع من الصور، وعدم نشر الصور (ستظهر نتائج رقمية مجمَّعة فقط)، وحذف صور موقعكم إن طلبتم ذلك، واحترام قواعد النظافة لديكم حتى لا أنقل أي مرض.
>
> هل يمكننا الحديث [هاتفيًا / في عين المكان] هذا الأسبوع؟ سأرسل لكم ورقة موافقة قصيرة.
>
> شكرًا مسبقًا. [الاسم الكامل] — [الهاتف / البريد]

### 6.3 À l'encadrant (semaine 0)

> Bonjour [Nom], avant de commencer la collecte, pouvez-vous valider (1) le texte de consentement, (2) le plan (2 sites, ≈ 400 images, 2 experts) et (3) les **critères de décision** à fixer avant de regarder les résultats (tableau de la section 6 du protocole : macro-F1, précision sélective au seuil 0,80, rappel des classes critiques, fausses acceptations hors périmètre, pire condition) ? Je les consignerai par écrit avec la date. Merci.

### 6.4 Présentation orale sur site (30 secondes)

« Je teste une application qui aide à repérer des maladies de la feuille de tomate. Je photographie des feuilles, sans photographier de personnes, pour vérifier si elle fonctionne dans de vraies conditions. Les photos ne seront pas publiées et vous pouvez me demander de les supprimer. Ce n'est pas un diagnostic et je ne donne aucun conseil de traitement. »

## 7. Contrôle qualité et risques

| Risque | Mesure |
|---|---|
| Classe absente de la saison ou du site | élargir à d'autres sites ; sinon rapporter « non évaluable » ; ne pas créer d'images artificielles |
| Étiquette douteuse | `label_certainty = probable` ou `uncertain` ; second expert ; les désaccords restent exclus tant qu'ils ne sont pas tranchés |
| Biais d'étiquetage | l'expert ne voit jamais la prédiction du modèle ; le second expert travaille en aveugle |
| Un seul appareil ou un seul site domine | `field_progress.py` (section « Diversité ») ; équilibrer en semaine 2 |
| Fuite avec PlantVillage | le validateur refuse les doublons et quasi-doublons ; ne jamais copier d'images d'Internet |
| Données personnelles | pas de personnes sur les photos ; GPS retiré ; site codé ; stockage hors Git ; sauvegarde sur support personnel |
| Retrait de consentement | suppression immédiate des photos du site et des lignes du manifeste |
| Réglage du modèle sur `test` | interdit : `evaluate_external.py` refuse une seconde évaluation `test` ; si le test sert à décider, il faut un nouveau jeu |
| Propagation de maladie | désinfection entre sites |

## 8. Fin de collecte

Gel des données : plus aucune image n'est ajoutée ni réétiquetée après l'évaluation `test`. Archiver le manifeste, l'empreinte du modèle évalué (écrite dans `field_eval_test.json`) et les critères signés. Produire le rapport selon la section 7 du protocole et mettre à jour la [Model Card](../MODEL_CARD.md).
