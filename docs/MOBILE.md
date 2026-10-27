# Application mobile Flutter — AgriScan AI

État au 2026-10-27 (Phase 5 : parcours principal, puis comptes et historique). Code : `mobile/`.

## 1. Périmètre

Implémenté :
- choix d'une photo (caméra ou galerie), validation locale, envoi à `POST /api/v1/predictions`, affichage du résultat, du statut incertain et des erreurs ;
- français et arabe avec RTL ;
- **connexion et inscription**, jeton conservé dans le **stockage sécurisé** de l'appareil (Android Keystore / iOS Keychain via `flutter_secure_storage`), reprise automatique de la session au démarrage, déconnexion, suppression du compte (avec confirmation) ;
- **historique** paginé des analyses de l'utilisateur, **détail** d'une analyse et **suppression** (avec confirmation) ; les analyses faites en étant connecté sont ajoutées à l'historique côté serveur, jamais la photo.

**Non implémenté** : mémorisation de la langue, mode hors ligne (l'historique n'est pas mis en cache), réinitialisation de mot de passe et vérification d'e-mail (absentes aussi de l'API), iOS testé sur appareil, publication sur les stores.

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
| 12 | Connexion et inscription : validation locale (e-mail, 10 caractères minimum), mot de passe masqué, erreurs traduites (identifiants refusés, e-mail déjà utilisé, trop de tentatives), aucun jeton écrit en cas d'échec | tests widget et contrôleur |
| 13 | Jeton dans le stockage sécurisé uniquement, envoyé en en-tête `Authorization: Bearer`, jamais dans une URL ni affiché | `account_api_test.dart`, `session_controller_test.dart`, intégration (Keystore réel) |
| 14 | Session reprise au démarrage ; jeton expiré/rejeté (401) : effacé, retour déconnecté avec message ; hors ligne : jeton conservé | tests contrôleur et widget |
| 15 | Déconnexion efface le jeton ; suppression du compte avec confirmation (analyses supprimées en cascade côté serveur) | tests widget, intégration |
| 16 | Analyse connecté : jeton transmis, note « enregistré dans l'historique » ; anonyme : rien envoyé ni noté ; 401 pendant l'analyse : session fermée, réessai anonyme possible | tests contrôleur et widget |
| 17 | Historique : liste paginée (« Charger plus »), état vide, erreur avec « Réessayer », classes traduites, incertain sans classe, dates localisées, FR/AR en RTL | tests widget et contrôleur |
| 18 | Détail d'une analyse rechargé depuis le serveur ; suppression avec confirmation, depuis la liste ou le détail ; déjà supprimée ailleurs = succès | tests widget et contrôleur, intégration |
| 19 | Le serveur n'expose pas les analyses des autres utilisateurs (404) et l'application ne montre que celles reçues | tests backend (`test_auth_history.py`), pas de logique d'autorisation côté client |

## 3. Architecture (interface / logique / réseau séparés)

- `lib/data/` : modèles (`Prediction`, `AnalysisRecord`, `UserProfile`…), clients HTTP (`HttpPredictionApi`, `HttpAccountApi`) et `TokenStore` (stockage sécurisé). `api_errors.dart` traduit les réponses d'erreur et les pannes de transport en `FailureKind`, sans texte ni langue.
- `lib/logic/` : `AnalysisController` (analyse), `SessionController` (connexion, jeton, expiration), `HistoryController` et `DetailController` (historique), `ImageSourceService`, `LocaleController`. Aucune dépendance aux widgets : tout est testable avec des faux. `app_services.dart` assemble ces objets (production et tests).
- `lib/ui/` : écrans (`HomeScreen`, `AuthScreen`, `HistoryScreen`, `DetailScreen`) et vues ; les textes viennent de `lib/l10n/*.arb`, jamais en dur.
- Gestion d'état : `ChangeNotifier` + `ListenableBuilder` (intégrés à Flutter, aucune bibliothèque d'état ajoutée).
- Dépendances ajoutées : `http` (client HTTP, maintenu par l'équipe Dart), `http_parser` (type MIME du multipart), `image_picker` (caméra/galerie, package officiel Flutter), `intl` et `flutter_localizations` (traductions, formats de nombres arabes), `flutter_secure_storage` (jeton dans le Keystore Android / Keychain iOS ; code natif, version majeure récente à surveiller). `integration_test` (SDK Flutter) en développement uniquement. Coût de maintenance : mises à jour régulières, surtout `image_picker` et `flutter_secure_storage`.
- Sécurité du jeton : durée de vie 30 minutes côté serveur, sans jeton de rafraîchissement ; à expiration (401) l'application l'efface et demande une nouvelle connexion. Le jeton n'est jamais journalisé, affiché ni placé dans une URL.

## 4. Configuration et lancement

L'URL de l'API se règle à la compilation (jamais de secret dans l'application) :

```powershell
# depuis mobile/
flutter run -d <appareil> --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

- `10.0.2.2` = machine hôte vue depuis l'émulateur Android. Sur un vrai téléphone, utiliser l'adresse IP ou le nom de domaine de l'API.
- Le HTTP en clair n'est autorisé qu'en **debug** (`android/app/src/debug/AndroidManifest.xml`). Les versions release exigent HTTPS.
- Démarrer l'API avant : `backend/` → `.\.venv\Scripts\python.exe -m uvicorn app.main:app --host 127.0.0.1 --port 8000`. Les comptes et l'historique exigent en plus `AGRISCAN_DATABASE_URL` (PostgreSQL migré avec Alembic) et `AGRISCAN_JWT_SECRET` (voir `docs/DATABASE.md`) ; sans eux l'application fonctionne en mode anonyme et affiche « comptes indisponibles ».
- Tests : `flutter test` (121 tests) ; analyse : `flutter analyze` ; intégration sur émulateur : `flutter test integration_test -d <id> --dart-define=API_BASE_URL=http://10.0.2.2:8000` (l'API doit tourner avec sa base ; le test crée puis supprime son propre compte).

## 5. Résultats réels

- `flutter analyze` : aucun problème. `flutter test` : **121 tests réussis** (contrôleurs, clients HTTP simulés, widgets FR/AR, traductions).
- **Test d'intégration complet sur l'émulateur Android Pixel 9** avec l'API réelle, le vrai modèle, un **vrai PostgreSQL 16.2** (pgserver, éphémère, migrations Alembic appliquées) et le **vrai stockage sécurisé** : inscription depuis l'interface → analyse enregistrée (note affichée) → redémarrage simulé avec reprise de la session depuis le Keystore → historique (1 élément) → détail → suppression de l'analyse (liste vide) → suppression du compte (jeton effacé de l'appareil, connexion ensuite refusée par le serveur). Le journal de l'API confirme chaque appel (`register`, `login`, `me`, `predictions`, `analyses`, `DELETE`). Les 3 scénarios passent en environ 20 s : 3 exécutions réussies sur 3 après la correction du bouton « Supprimer », puis, avec la version finale du fichier de test, 1 exécution figée (voir limites) ; les exécutions interrompues par moi pendant une compilation Gradle lente ne comptent pas.
- Défauts trouvés et corrigés grâce aux tests : (1) le contrôleur d'analyse n'interceptait que les `Exception` (une `StateError` laissait l'écran en chargement) ; (2) le bouton « Supprimer » du détail était désactivé pendant le rechargement en arrière-plan, ce qui bloquait une suppression sur réseau lent ; une réponse tardive pouvait en outre « ressusciter » une analyse supprimée (test de non-régression ajouté) ; (3) l'e-mail de test en `.test` est refusé par la validation de l'API (domaine réservé), le test utilise `example.com`.
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
- **Test d'intégration intermittent sur l'émulateur** : sur une quinzaine d'exécutions, environ 4 se sont figées à des étapes différentes (historique, suppression), sans erreur applicative ni requête manquante côté serveur, parfois suivies de la disparition de l'émulateur. Cause non démontrée : l'image d'émulateur (Android 17 préversion, pages de 16 Ko) boucle sur un plantage du composant NFC (`SIGABRT` toutes les 5 s dans `logcat`) et la machine était presque saturée en mémoire (0,9 à 1,9 Go libres). La logique est vérifiée par les 121 tests locaux et par les exécutions réussies, mais ce test d'intégration ne doit pas encore servir d'intégration continue ; à rejouer sur un émulateur stable ou un vrai téléphone.
- Le stockage sécurisé n'a été exercé que sur émulateur ; son comportement après restauration de sauvegarde ou changement d'écran de verrouillage n'est pas testé (le jeton illisible est traité comme « déconnecté »).
- Pas de mise en cache de l'historique : hors ligne, la liste affiche l'erreur réseau avec « Réessayer ».
- L'identité (e-mail) est visible dans le menu du compte ; l'application ne propose ni changement d'e-mail ni de mot de passe.
