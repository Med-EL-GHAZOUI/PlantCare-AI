// Test d'intégration sur appareil/émulateur : vrai réseau, vraie API, vrai modèle, vraie base PostgreSQL
// et vrai stockage sécurisé du jeton (Android Keystore).
//
// Prérequis : API lancée avec AGRISCAN_DATABASE_URL et AGRISCAN_JWT_SECRET (voir docs/MOBILE.md), puis,
// depuis mobile/ :
//   flutter test integration_test -d <id appareil> --dart-define=API_BASE_URL=http://10.0.2.2:8000
//
// L'image est synthétique (aucune donnée PlantVillage) : on vérifie le contrat, la persistance et
// l'affichage, pas la justesse du diagnostic. Le compte de test est créé puis supprimé par le test.
import 'dart:convert';
import 'dart:typed_data';

import 'package:agriscan_mobile/app.dart';
import 'package:agriscan_mobile/app_services.dart';
import 'package:agriscan_mobile/config/app_config.dart';
import 'package:agriscan_mobile/data/account_api.dart';
import 'package:agriscan_mobile/data/models.dart';
import 'package:agriscan_mobile/data/prediction_api.dart';
import 'package:agriscan_mobile/data/token_store.dart';
import 'package:agriscan_mobile/l10n/app_localizations_fr.dart';
import 'package:agriscan_mobile/logic/image_share_service.dart';
import 'package:agriscan_mobile/logic/image_source_service.dart';
import 'package:agriscan_mobile/logic/locale_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

const _leafJpegBase64 =
    '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';

class _FixedImageSource implements ImageSourceService {
  @override
  Future<PickedImage?> pick(ImageOrigin origin) async =>
      PickedImage(bytes: base64Decode(_leafJpegBase64), name: 'feuille_synthetique.jpg');
}

class _CapturingShare implements ImageShareService {
  final List<Uint8List> shared = [];

  @override
  Future<void> shareImage(Uint8List bytes, {required String filename, required String text}) async {
    shared.add(bytes);
  }
}

AppServices _services(String baseUrl, TokenStore store, {ImageShareService? share}) {
  final predictionApi = HttpPredictionApi(baseUrl: baseUrl, timeout: const Duration(seconds: 20));
  return AppServices.assemble(
    accountApi: HttpAccountApi(baseUrl: baseUrl, timeout: const Duration(seconds: 20)),
    predictionApi: predictionApi,
    exportApi: predictionApi,
    imageShare: share ?? _CapturingShare(),
    tokenStore: store,
    imageSource: _FixedImageSource(),
    locale: LocaleController(const Locale('fr')),
  );
}

Future<void> _pump(WidgetTester tester, AppServices services) async {
  await tester.pumpWidget(AgriScanApp(services: services));
  await tester.pumpAndSettle();
}

Future<void> _waitGone(WidgetTester tester, Finder finder, {Duration timeout = const Duration(seconds: 30)}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 250));
    if (finder.evaluate().isEmpty) return;
  }
  fail('Toujours affiché après le délai : $finder');
}

Future<void> _openMenuItem(WidgetTester tester, Key itemKey) async {
  await tester.tap(find.byKey(const Key('account_menu')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(itemKey));
  await tester.pump();
}

Future<void> _waitFor(WidgetTester tester, Finder finder, {Duration timeout = const Duration(seconds: 60)}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 250));
    if (finder.evaluate().isNotEmpty) return;
  }
  fail('Délai dépassé en attendant $finder');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final fr = AppLocalizationsFr();

  testWidgets('API réelle, anonyme : résultat ou incertain avec avertissements, rien enregistré', (tester) async {
    final store = SecureTokenStore();
    await store.clear();
    await _pump(tester, _services(AppConfig.apiBaseUrl, store));
    await tester.tap(find.byKey(const Key('gallery_button')));
    await _waitFor(tester, find.byKey(const Key('disclaimer')));

    final hasResult = find.byKey(const Key('result_card')).evaluate().isNotEmpty;
    final isUncertain = find.byKey(const Key('uncertain_card')).evaluate().isNotEmpty;
    expect(hasResult || isUncertain, isTrue);
    expect(find.byKey(const Key('error_card')), findsNothing);
    expect(find.byKey(const Key('saved_note')), findsNothing);
  });

  testWidgets("API réelle : export de l'image annotée (PNG) partagé via le service de partage", (tester) async {
    final share = _CapturingShare();
    await _pump(tester, _services(AppConfig.apiBaseUrl, SecureTokenStore()..clear(), share: share));
    await tester.tap(find.byKey(const Key('gallery_button')));
    await _waitFor(tester, find.byKey(const Key('export_button')));
    await tester.ensureVisible(find.byKey(const Key('export_button'))); // sous la ligne de flottaison sur un vrai écran
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('export_button')));
    final end = DateTime.now().add(const Duration(seconds: 60));
    while (share.shared.isEmpty && DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    expect(share.shared, hasLength(1));
    expect(share.shared.single.sublist(0, 8), [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]); // signature PNG
    expect(share.shared.single.length, greaterThan(base64Decode(_leafJpegBase64).length ~/ 2));
    expect(find.byKey(const Key('error_card')), findsNothing);
  });

  testWidgets('API injoignable : message réseau et bouton Réessayer', (tester) async {
    await _pump(tester, _services('http://10.0.2.2:9', SecureTokenStore()));
    await tester.tap(find.byKey(const Key('gallery_button')));
    await _waitFor(tester, find.byKey(const Key('error_card')));
    expect(find.byKey(const Key('retry_button')), findsOneWidget);
  });

  testWidgets('parcours complet : inscription, analyse enregistrée, session restaurée, détail, suppression',
      (tester) async {
    final store = SecureTokenStore();
    await store.clear();
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final email = 'it-$stamp@example.com';
    final password = 'Test-$stamp-Zq';

    // 1. Inscription depuis l'interface
    var services = _services(AppConfig.apiBaseUrl, store);
    await _pump(tester, services);
    await tester.tap(find.byKey(const Key('sign_in_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('auth_switch')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('email_field')), email);
    await tester.enterText(find.byKey(const Key('password_field')), password);
    await tester.tap(find.byKey(const Key('auth_submit')));
    await _waitFor(tester, find.byKey(const Key('account_menu')));

    // Le jeton est dans le stockage sécurisé de l'appareil
    expect(await store.read(), isNotNull);

    // 2. Analyse enregistrée dans l'historique
    await tester.tap(find.byKey(const Key('gallery_button')));
    await _waitFor(tester, find.byKey(const Key('saved_note')));
    expect(find.text(fr.savedToHistory), findsOneWidget);

    // 3. « Redémarrage » : nouveaux contrôleurs, même stockage sécurisé, session restaurée
    services = _services(AppConfig.apiBaseUrl, SecureTokenStore());
    await tester.pumpWidget(const SizedBox());
    await _pump(tester, services);
    await _waitFor(tester, find.byKey(const Key('account_menu')));
    expect(services.session.user?.email, email);

    // 4. Historique : une analyse, puis son détail
    await _openMenuItem(tester, const Key('menu_history'));
    await _waitFor(tester, find.byType(ListTile));
    expect(find.byType(ListTile), findsOneWidget);
    await tester.tap(find.byType(ListTile));
    await _waitFor(tester, find.byKey(const Key('detail_date')));
    expect(find.byKey(const Key('disclaimer')), findsOneWidget);

    // 5. Suppression de l'analyse depuis le détail : liste vide
    await tester.tap(find.byKey(const Key('detail_delete_button')));
    await _waitFor(tester, find.byKey(const Key('dialog_confirm')));
    await tester.tap(find.byKey(const Key('dialog_confirm')));
    await _waitFor(tester, find.byKey(const Key('history_empty')));
    await _waitGone(tester, find.byKey(const Key('detail_date'))); // l'écran de détail est refermé
    await tester.pumpAndSettle();

    // 6. Suppression du compte : déconnexion et jeton effacé de l'appareil
    await tester.tap(find.byType(BackButton)); // retour de l'historique à l'accueil
    await tester.pumpAndSettle();
    await _openMenuItem(tester, const Key('menu_delete_account'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('dialog_confirm')));
    await _waitFor(tester, find.byKey(const Key('sign_in_button')));
    expect(await SecureTokenStore().read(), isNull);

    // Le compte n'existe plus côté serveur : connexion impossible
    final api = HttpAccountApi(baseUrl: AppConfig.apiBaseUrl);
    await expectLater(
      api.login(email, password),
      throwsA(isA<ApiFailure>().having((f) => f.kind, 'kind', FailureKind.invalidCredentials)),
    );
  });
}
