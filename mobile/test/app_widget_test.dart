import 'dart:async';

import 'package:agriscan_mobile/app.dart';
import 'package:agriscan_mobile/data/models.dart';
import 'package:agriscan_mobile/data/prediction_api.dart';
import 'package:agriscan_mobile/l10n/app_localizations_ar.dart';
import 'package:agriscan_mobile/l10n/app_localizations_fr.dart';
import 'package:agriscan_mobile/logic/analysis_controller.dart';
import 'package:agriscan_mobile/logic/image_source_service.dart';
import 'package:agriscan_mobile/logic/locale_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

final fr = AppLocalizationsFr();
final ar = AppLocalizationsAr();

Future<AnalysisController> pumpApp(
  WidgetTester tester, {
  required FakePredictionApi api,
  FakeImageSource? source,
  Locale? locale = const Locale('fr'),
}) async {
  tester.view.physicalSize = const Size(900, 2200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final controller = AnalysisController(api: api, imageSource: source ?? FakeImageSource(image: sampleImage()));
  await tester.pumpWidget(AgriScanApp(controller: controller, localeController: LocaleController(locale)));
  await tester.pumpAndSettle();
  return controller;
}

TextDirection directionOf(WidgetTester tester, Finder finder) => Directionality.of(tester.element(finder));

void main() {
  testWidgets('état initial : aide, boutons caméra et galerie, aucune erreur', (tester) async {
    await pumpApp(tester, api: FakePredictionApi(result: samplePrediction()));
    expect(find.text(fr.emptyHint), findsOneWidget);
    expect(find.text(fr.takePhoto), findsOneWidget);
    expect(find.text(fr.chooseFromGallery), findsOneWidget);
    expect(find.byKey(const Key('error_card')), findsNothing);
    expect(find.byKey(const Key('result_card')), findsNothing);
  });

  testWidgets('parcours principal : galerie → chargement → résultat avec avertissements', (tester) async {
    final completer = Completer<Prediction>();
    final api = FakePredictionApi(completer: completer);
    final source = FakeImageSource(image: sampleImage());
    await pumpApp(tester, api: api, source: source);

    await tester.tap(find.byKey(const Key('gallery_button')));
    await tester.pump();
    await tester.pump();
    expect(source.requests, [ImageOrigin.gallery]);
    expect(find.byKey(const Key('loading_indicator')), findsOneWidget);
    expect(find.text(fr.analyzing), findsOneWidget);
    // Boutons désactivés pendant l'analyse
    expect(tester.widget<FilledButton>(find.byKey(const Key('camera_button'))).onPressed, isNull);

    completer.complete(samplePrediction());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('result_card')), findsOneWidget);
    expect(find.text(fr.classLateBlight), findsOneWidget);
    expect(find.byKey(const Key('model_score')), findsOneWidget);
    expect(find.textContaining('91'), findsWidgets);
    expect(find.text(fr.modelScoreNote), findsOneWidget);
    expect(find.text(fr.disclaimer), findsOneWidget); // limites toujours visibles
    expect(find.text(fr.limitsBody), findsOneWidget);
    expect(find.text(fr.classEarlyBlight), findsOneWidget); // classe voisine indicative
  });

  testWidgets('bouton caméra demande la source caméra', (tester) async {
    final source = FakeImageSource(image: sampleImage());
    await pumpApp(tester, api: FakePredictionApi(result: samplePrediction()), source: source);
    await tester.tap(find.byKey(const Key('camera_button')));
    await tester.pumpAndSettle();
    expect(source.requests, [ImageOrigin.camera]);
  });

  testWidgets('résultat incertain : message prudent, aucune classe affichée', (tester) async {
    await pumpApp(tester, api: FakePredictionApi(result: samplePrediction(uncertain: true)));
    await tester.tap(find.byKey(const Key('gallery_button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('uncertain_card')), findsOneWidget);
    expect(find.text(fr.uncertainTitle), findsOneWidget);
    expect(find.text(fr.uncertainBody), findsOneWidget);
    expect(find.byKey(const Key('result_card')), findsNothing);
    expect(find.byKey(const Key('predicted_class')), findsNothing);
    expect(find.text(fr.disclaimer), findsOneWidget);
  });

  testWidgets('perte réseau : message clair, puis réessai réussi', (tester) async {
    final api = FakePredictionApi(failure: const ApiFailure(FailureKind.network));
    await pumpApp(tester, api: api);
    await tester.tap(find.byKey(const Key('gallery_button')));
    await tester.pumpAndSettle();

    expect(find.text(fr.errorNetwork), findsOneWidget);
    expect(find.byKey(const Key('retry_button')), findsOneWidget);

    api
      ..failure = null
      ..result = samplePrediction();
    await tester.tap(find.byKey(const Key('retry_button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('error_card')), findsNothing);
    expect(find.byKey(const Key('result_card')), findsOneWidget);
  });

  testWidgets('image invalide : message dédié, pas de bouton Réessayer', (tester) async {
    await pumpApp(tester, api: FakePredictionApi(failure: const ApiFailure(FailureKind.invalidImage)));
    await tester.tap(find.byKey(const Key('gallery_button')));
    await tester.pumpAndSettle();
    expect(find.text(fr.errorInvalidImage), findsOneWidget);
    expect(find.byKey(const Key('retry_button')), findsNothing);
  });

  testWidgets('permission refusée sur le sélecteur : message dédié', (tester) async {
    await pumpApp(
      tester,
      api: FakePredictionApi(result: samplePrediction()),
      source: FakeImageSource(failure: const ApiFailure(FailureKind.pickFailed)),
    );
    await tester.tap(find.byKey(const Key('camera_button')));
    await tester.pumpAndSettle();
    expect(find.text(fr.errorPickFailed), findsOneWidget);
  });

  testWidgets('Nouvelle analyse remet l’écran à zéro', (tester) async {
    await pumpApp(tester, api: FakePredictionApi(result: samplePrediction()));
    await tester.tap(find.byKey(const Key('gallery_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('new_analysis_button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('result_card')), findsNothing);
    expect(find.text(fr.emptyHint), findsOneWidget);
  });

  testWidgets('classe inconnue du modèle : étiquette brute affichée, jamais masquée', (tester) async {
    final json = predictionJson(predictedClass: 'Tomato___New_disease');
    (json['scores'] as Map<String, dynamic>)['Tomato___New_disease'] = 0.9;
    await pumpApp(tester, api: FakePredictionApi(result: Prediction.fromJson(json)));
    await tester.tap(find.byKey(const Key('gallery_button')));
    await tester.pumpAndSettle();
    expect(find.text(fr.classUnknown('Tomato___New_disease')), findsOneWidget);
  });

  group('langues et RTL', () {
    testWidgets('français : texte de gauche à droite', (tester) async {
      await pumpApp(tester, api: FakePredictionApi(result: samplePrediction()));
      expect(directionOf(tester, find.byKey(const Key('camera_button'))), TextDirection.ltr);
    });

    testWidgets('arabe : textes traduits et mise en page de droite à gauche', (tester) async {
      await pumpApp(tester, api: FakePredictionApi(result: samplePrediction()), locale: const Locale('ar'));
      expect(find.text(ar.takePhoto), findsOneWidget);
      expect(find.text(ar.emptyHint), findsOneWidget);
      expect(directionOf(tester, find.byKey(const Key('camera_button'))), TextDirection.rtl);

      await tester.tap(find.byKey(const Key('gallery_button')));
      await tester.pumpAndSettle();
      expect(find.text(ar.classLateBlight), findsOneWidget);
      expect(find.text(ar.disclaimer), findsOneWidget);
      expect(directionOf(tester, find.byKey(const Key('result_card'))), TextDirection.rtl);
    });

    testWidgets("changement de langue à chaud via le menu, sans perdre l'état", (tester) async {
      await pumpApp(tester, api: FakePredictionApi(result: samplePrediction()));
      await tester.tap(find.byKey(const Key('gallery_button')));
      await tester.pumpAndSettle();
      expect(find.text(fr.classLateBlight), findsOneWidget);

      await tester.tap(find.byKey(const Key('language_menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(ar.languageArabic).last);
      await tester.pumpAndSettle();

      expect(find.text(ar.classLateBlight), findsOneWidget);
      expect(directionOf(tester, find.byKey(const Key('result_card'))), TextDirection.rtl);
    });

    testWidgets('erreur affichée en arabe', (tester) async {
      await pumpApp(
        tester,
        api: FakePredictionApi(failure: const ApiFailure(FailureKind.timeout)),
        locale: const Locale('ar'),
      );
      await tester.tap(find.byKey(const Key('gallery_button')));
      await tester.pumpAndSettle();
      expect(find.text(ar.errorTimeout), findsOneWidget);
    });
  });
}
