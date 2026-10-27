# Application mobile Flutter — AgriScan AI

État au 2026-10-27 (Phase 5, parcours principal). Code : `mobile/`.

## 1. Périmètre

Implémenté : choix d'une photo (caméra ou galerie), validation locale, envoi à `POST /api/v1/predictions`, affichage du résultat, du statut incertain et des erreurs, français et arabe avec RTL.

**Non implémenté** (Phase 5 suite) : connexion, inscription, historique et suppression des analyses (routes déjà disponibles côté API), mémorisation de la langue, mode hors ligne, iOS testé sur appareil, publication sur les stores.

## 2. Critères d'acceptation et vérification

| # | Critère | Vérifié par |
|---|---|---|
| 1 | Prendre une photo ou en choisir une dans la galerie | tests widget (source caméra / galerie) ; sélecteur `image_picker` non exercé sur appareil réel |
| 2 | Images > 5 Mo, vides ou hors JPEG/PNG refusées avant l'envoi | tests contrôleur |
| 3 | Envoi multipart (champ `image`, type MIME correct) | tests `MockClient`, test d'intégration réel |
| 4 | Résultat : classe traduite, score du modèle, classes voisines, limites et avertissement toujours visibles | tests widget |
| 5 | Statut `uncertain` : message prudent, aucune classe affichée | tests widget, modèle |
| 6 | États chargement, succès, erreur, vide ; boutons désactivés pendant l'analyse | tests widget, contrôleur |
| 7 | Erreurs de l'API (413, 415, 400, 422, 503, 500), réseau coupé, délai dépassé, réponse invalide : message traduit, « Réessayer » seulement si utile | tests API et widget |
| 8 | Français et arabe, mise en page RTL en arabe, changement de langue à chaud sans perdre l'état | tests widget ; capture d'écran sur émulateur |
| 9 | Fichiers ARB cohérents : mêmes clés, aucune traduction vide, 10 classes nommées | `l10n_test.dart` |
| 10 | Aucune posologie ni conseil de traitement | `l10n_test.dart` (mots interdits) et relecture |
| 11 | Parcours réel : application → API → modèle → affichage | test d'intégration sur émulateur Android |

## 3. Architecture (interface / logique / réseau séparés)

- `lib/data/` : modèles (`Prediction`, `PickedImage`) et client HTTP (`HttpPredictionApi`) qui traduit les erreurs en `FailureKind`, sans texte ni langue.
- `lib/logic/` : `AnalysisController` (état et validation locale), `ImageSourceService` (caméra/galerie), `LocaleController`. Aucune dépendance aux widgets : tout est testable avec des faux.
- `lib/ui/` : écrans et vues ; les textes viennent de `lib/l10n/*.arb`, jamais en dur.
- Gestion d'état : `ChangeNotifier` + `ListenableBuilder` (intégrés à Flutter, aucune bibliothèque d'état ajoutée).
- Dépendances ajoutées : `http` (client HTTP, maintenu par l'équipe Dart), `http_parser` (type MIME du multipart), `image_picker` (caméra/galerie, package officiel Flutter), `intl` et `flutter_localizations` (traductions, formats de nombres arabes). Coût de maintenance : mises à jour régulières, surtout `image_picker` (code natif).

## 4. Configuration et lancement

L'URL de l'API se règle à la compilation (jamais de secret dans l'application) :

```powershell
# depuis mobile/
flutter run -d <appareil> --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

- `10.0.2.2` = machine hôte vue depuis l'émulateur Android. Sur un vrai téléphone, utiliser l'adresse IP ou le nom de domaine de l'API.
- Le HTTP en clair n'est autorisé qu'en **debug** (`android/app/src/debug/AndroidManifest.xml`). Les versions release exigent HTTPS.
- Démarrer l'API avant : `backend/` → `.\.venv\Scripts\python.exe -m uvicorn app.main:app --host 127.0.0.1 --port 8000`.
- Tests : `flutter test` (47 tests) ; analyse : `flutter analyze` ; intégration sur émulateur : `flutter test integration_test -d <id> --dart-define=API_BASE_URL=http://10.0.2.2:8000`.

## 5. Résultats réels

- `flutter analyze` : aucun problème. `flutter test` : 47 tests réussis.
- Un test a révélé un défaut corrigé : le contrôleur n'interceptait que les `Exception` ; une erreur inattendue (`StateError`, `TypeError`) aurait laissé l'écran en chargement. Il intercepte désormais toute erreur.
- Test d'intégration sur **émulateur Android Pixel 9 (API 37, x86_64)**, réseau réel vers l'API locale avec le vrai modèle MobileNetV2 : 2 tests réussis (image valide → résultat ou incertain avec avertissements ; API injoignable → message réseau et bouton Réessayer). Le journal de l'API confirme `POST /api/v1/predictions … 200`. L'image utilisée est **synthétique** : ce test valide le contrat et l'affichage, pas la justesse du diagnostic.
- Captures d'écran manuelles sur l'émulateur : écran d'accueil en français, puis en arabe après changement de langue (texte aligné à droite, boutons et icône de langue inversés).

## 6. Limites

- Le sélecteur de photos réel (caméra, galerie, permissions) n'a pas été exercé sur appareil : les tests utilisent un faux sélecteur. Un essai manuel sur téléphone reste à faire.
- Seul Android (émulateur) a été exécuté. Le projet iOS est généré avec les textes de permission mais n'a jamais été compilé (Windows).
- Les images sont réduites à 1024 px et recompressées (qualité 90) avant l'envoi ; le serveur les redimensionne ensuite à 224 px. L'effet de ce double redimensionnement sur la précision n'a pas été mesuré.
- Les traductions arabes (interface et noms de maladies) n'ont pas été relues par un locuteur natif ni par un agronome : à valider avant diffusion.
- L'application affiche un « score du modèle », jamais une probabilité ; le modèle n'a pas de détection hors périmètre et n'a été évalué que sur PlantVillage (voir MODEL_CARD.md).
- Le seuil d'incertitude est celui configuré côté API (désactivé par défaut) ; l'application ne le choisit pas.
- Le libellé du bouton « Choisir dans la galerie » passe sur deux lignes en français sur un écran étroit.
