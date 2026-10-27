// Test d'intégration sur appareil/émulateur : vrai réseau, vraie API, vrai modèle.
// Lancer l'API (backend/) puis, depuis mobile/ :
//   flutter test integration_test -d <id appareil> --dart-define=API_BASE_URL=http://10.0.2.2:8000
// L'image est synthétique (aucune donnée PlantVillage) : le test vérifie le contrat et l'affichage,
// pas la justesse du diagnostic.
import 'dart:convert';

import 'package:agriscan_mobile/app.dart';
import 'package:agriscan_mobile/config/app_config.dart';
import 'package:agriscan_mobile/data/models.dart';
import 'package:agriscan_mobile/data/prediction_api.dart';
import 'package:agriscan_mobile/l10n/app_localizations_fr.dart';
import 'package:agriscan_mobile/logic/analysis_controller.dart';
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

Future<void> _pumpApp(WidgetTester tester, String baseUrl) async {
  final controller = AnalysisController(
    api: HttpPredictionApi(baseUrl: baseUrl, timeout: const Duration(seconds: 20)),
    imageSource: _FixedImageSource(),
  );
  await tester.pumpWidget(AgriScanApp(controller: controller, localeController: LocaleController(const Locale('fr'))));
  await tester.pumpAndSettle();
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

  testWidgets('API réelle : une image valide donne un résultat ou un statut incertain', (tester) async {
    await _pumpApp(tester, AppConfig.apiBaseUrl);
    await tester.tap(find.byKey(const Key('gallery_button')));
    await _waitFor(tester, find.byType(Card));
    await _waitFor(tester, find.byKey(const Key('disclaimer')));

    final hasResult = find.byKey(const Key('result_card')).evaluate().isNotEmpty;
    final isUncertain = find.byKey(const Key('uncertain_card')).evaluate().isNotEmpty;
    expect(hasResult || isUncertain, isTrue);
    expect(find.byKey(const Key('error_card')), findsNothing);
    expect(find.text(fr.disclaimer), findsOneWidget);
  });

  testWidgets('API injoignable : message réseau et bouton Réessayer', (tester) async {
    await _pumpApp(tester, 'http://10.0.2.2:9');
    await tester.tap(find.byKey(const Key('gallery_button')));
    await _waitFor(tester, find.byKey(const Key('error_card')));
    expect(find.byKey(const Key('retry_button')), findsOneWidget);
  });
}
