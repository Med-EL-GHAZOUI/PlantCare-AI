import 'dart:async';

import 'package:agriscan_mobile/app.dart';
import 'package:agriscan_mobile/app_services.dart';
import 'package:agriscan_mobile/data/models.dart';
import 'package:agriscan_mobile/data/prediction_api.dart';
import 'package:agriscan_mobile/l10n/app_localizations_ar.dart';
import 'package:agriscan_mobile/l10n/app_localizations_fr.dart';
import 'package:agriscan_mobile/logic/locale_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

final fr = AppLocalizationsFr();
final ar = AppLocalizationsAr();

Future<AppServices> pumpApp(
  WidgetTester tester, {
  required FakeExportApi exportApi,
  required FakeImageShare share,
  FakePredictionApi? predictionApi,
  Locale locale = const Locale('fr'),
}) async {
  tester.view.physicalSize = const Size(900, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final services = AppServices.assemble(
    accountApi: FakeAccountApi(),
    predictionApi: predictionApi ?? FakePredictionApi(result: samplePrediction()),
    exportApi: exportApi,
    imageShare: share,
    tokenStore: MemoryTokenStore(),
    imageSource: FakeImageSource(image: sampleImage()),
    locale: LocaleController(locale),
  );
  await tester.pumpWidget(AgriScanApp(services: services));
  await tester.pumpAndSettle();
  return services;
}

Future<void> analyse(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('gallery_button')));
  await tester.pumpAndSettle();
}

void main() {
  late FakeExportApi exportApi;
  late FakeImageShare share;

  setUp(() {
    exportApi = FakeExportApi();
    share = FakeImageShare();
  });

  testWidgets('la carte d’export n’apparaît qu’après un résultat', (tester) async {
    await pumpApp(tester, exportApi: exportApi, share: share);
    expect(find.byKey(const Key('export_card')), findsNothing);
    await analyse(tester);
    expect(find.byKey(const Key('export_card')), findsOneWidget);
    expect(find.text(fr.exportButton), findsOneWidget);
    expect(find.text(fr.exportNote), findsOneWidget); // limites du filigrane et confidentialité expliquées
  });

  testWidgets('le filigrane est activé par défaut', (tester) async {
    await pumpApp(tester, exportApi: exportApi, share: share);
    await analyse(tester);
    expect(tester.widget<SwitchListTile>(find.byKey(const Key('export_watermark_switch'))).value, isTrue);
  });

  testWidgets('export : la même photo est envoyée, puis le PNG est partagé', (tester) async {
    await pumpApp(tester, exportApi: exportApi, share: share);
    await analyse(tester);
    await tester.tap(find.byKey(const Key('export_button')));
    await tester.pumpAndSettle();

    expect(exportApi.images.single.name, 'leaf.jpg');
    expect(exportApi.watermarkRequests, [true]);
    expect(share.shared, hasLength(1));
    expect(share.shared.single.filename, 'agriscan-result.png');
    expect(share.shared.single.text, fr.exportShareText);
    expect(find.byKey(const Key('error_card')), findsNothing);
  });

  testWidgets('désactiver le filigrane est transmis au serveur', (tester) async {
    await pumpApp(tester, exportApi: exportApi, share: share);
    await analyse(tester);
    await tester.tap(find.byKey(const Key('export_watermark_switch')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('export_button')));
    await tester.pumpAndSettle();
    expect(exportApi.watermarkRequests, [false]);
  });

  testWidgets('pendant l’export : indicateur de progression, bouton et option désactivés', (tester) async {
    exportApi.completer = Completer<ExportedImage>();
    await pumpApp(tester, exportApi: exportApi, share: share);
    await analyse(tester);
    await tester.tap(find.byKey(const Key('export_button')));
    await tester.pump();

    expect(find.byKey(const Key('export_progress')), findsOneWidget);
    expect(find.text(fr.exportingLabel), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byKey(const Key('export_button'))).onPressed, isNull);
    expect(tester.widget<SwitchListTile>(find.byKey(const Key('export_watermark_switch'))).onChanged, isNull);

    exportApi.completer!.complete(ExportedImage(bytes: tinyPng, predictionId: 'p', watermarkApplied: true));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('export_progress')), findsNothing);
    expect(share.shared, hasLength(1));
  });

  testWidgets('erreur réseau : message, aucun partage, puis réessai réussi', (tester) async {
    exportApi.failure = const ApiFailure(FailureKind.network);
    await pumpApp(tester, exportApi: exportApi, share: share);
    await analyse(tester);
    await tester.tap(find.byKey(const Key('export_button')));
    await tester.pumpAndSettle();

    expect(find.text(fr.errorNetwork), findsOneWidget);
    expect(share.shared, isEmpty);

    exportApi.failure = null;
    await tester.tap(find.descendant(of: find.byKey(const Key('export_card')), matching: find.byKey(const Key('retry_button'))));
    await tester.pumpAndSettle();
    expect(find.text(fr.errorNetwork), findsNothing);
    expect(share.shared, hasLength(1));
  });

  testWidgets('partage impossible sur l’appareil : message dédié', (tester) async {
    share.failure = const ApiFailure(FailureKind.shareFailed);
    await pumpApp(tester, exportApi: exportApi, share: share);
    await analyse(tester);
    await tester.tap(find.byKey(const Key('export_button')));
    await tester.pumpAndSettle();
    expect(find.text(fr.errorShareFailed), findsOneWidget);
  });

  testWidgets('résultat incertain : l’export reste proposé', (tester) async {
    await pumpApp(
      tester,
      exportApi: exportApi,
      share: share,
      predictionApi: FakePredictionApi(result: samplePrediction(uncertain: true)),
    );
    await analyse(tester);
    expect(find.byKey(const Key('uncertain_card')), findsOneWidget);
    expect(find.byKey(const Key('export_card')), findsOneWidget);
  });

  testWidgets('nouvelle analyse : la carte d’export disparaît', (tester) async {
    await pumpApp(tester, exportApi: exportApi, share: share);
    await analyse(tester);
    await tester.tap(find.byKey(const Key('new_analysis_button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('export_card')), findsNothing);
  });

  testWidgets('arabe : textes traduits et mise en page de droite à gauche', (tester) async {
    await pumpApp(tester, exportApi: exportApi, share: share, locale: const Locale('ar'));
    await analyse(tester);
    expect(find.text(ar.exportButton), findsOneWidget);
    expect(find.text(ar.exportWatermarkOption), findsOneWidget);
    expect(Directionality.of(tester.element(find.byKey(const Key('export_card')))), TextDirection.rtl);

    await tester.tap(find.byKey(const Key('export_button')));
    await tester.pumpAndSettle();
    expect(share.shared.single.text, ar.exportShareText);
  });
}
