import 'dart:async';

import 'package:agriscan_mobile/app_services.dart';
import 'package:agriscan_mobile/data/models.dart';
import 'package:agriscan_mobile/data/prediction_api.dart';
import 'package:agriscan_mobile/logic/export_controller.dart';
import 'package:agriscan_mobile/logic/image_source_service.dart';
import 'package:agriscan_mobile/logic/locale_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  late FakeExportApi api;
  late FakeImageShare share;
  late ExportController controller;

  setUp(() {
    api = FakeExportApi();
    share = FakeImageShare();
    controller = ExportController(api: api, share: share);
  });

  test('export réussi : image demandée avec filigrane puis partagée sous un nom fixe', () async {
    final image = sampleImage();
    final ok = await controller.export(image, shareText: 'texte partagé');

    expect(ok, isTrue);
    expect(api.images.single, same(image));
    expect(api.watermarkRequests, [true]); // filigrane activé par défaut
    expect(share.shared, hasLength(1));
    expect(share.shared.single.filename, ExportController.filename);
    expect(share.shared.single.text, 'texte partagé');
    expect(share.shared.single.bytes, tinyPng);
    expect(controller.status, ExportStatus.idle);
    expect(controller.failure, isNull);
  });

  test('le filigrane peut être désactivé avant l’export', () async {
    controller.watermark = false;
    await controller.export(sampleImage(), shareText: 't');
    expect(api.watermarkRequests, [false]);
  });

  test('changer l’option notifie les écouteurs une seule fois par changement', () {
    var notified = 0;
    controller.addListener(() => notified++);
    controller.watermark = true; // inchangé
    controller.watermark = false;
    controller.watermark = false; // inchangé
    expect(notified, 1);
  });

  test('pendant l’export : état exporting, et une seconde demande est ignorée', () async {
    api.completer = Completer<ExportedImage>();
    final first = controller.export(sampleImage(), shareText: 't');
    await Future<void>.delayed(Duration.zero);
    expect(controller.isExporting, isTrue);

    expect(await controller.export(sampleImage(), shareText: 't'), isFalse);
    expect(api.images, hasLength(1));

    api.completer!.complete(ExportedImage(bytes: tinyPng, predictionId: 'p', watermarkApplied: true));
    expect(await first, isTrue);
    expect(share.shared, hasLength(1));
  });

  test('échec réseau : rien n’est partagé, puis réessai réussi avec la même image', () async {
    api.failure = const ApiFailure(FailureKind.network);
    final image = sampleImage();
    expect(await controller.export(image, shareText: 'texte'), isFalse);
    expect(controller.status, ExportStatus.failure);
    expect(controller.failure!.kind, FailureKind.network);
    expect(share.shared, isEmpty);

    api.failure = null;
    expect(await controller.retry(), isTrue);
    expect(api.images, [image, image]);
    expect(share.shared.single.text, 'texte');
    expect(controller.failure, isNull);
  });

  test('échec du partage système : shareFailed', () async {
    share.failure = const ApiFailure(FailureKind.shareFailed);
    expect(await controller.export(sampleImage(), shareText: 't'), isFalse);
    expect(controller.failure!.kind, FailureKind.shareFailed);
  });

  test('erreur inattendue : unknown, l’écran ne reste pas en chargement', () async {
    final broken = ExportController(api: _ThrowingExportApi(), share: share);
    expect(await broken.export(sampleImage(), shareText: 't'), isFalse);
    expect(broken.status, ExportStatus.failure);
    expect(broken.failure!.kind, FailureKind.unknown);
  });

  test('retry sans export précédent : sans effet', () async {
    expect(await controller.retry(), isFalse);
    expect(api.images, isEmpty);
  });

  test('reset efface l’échec affiché', () async {
    api.failure = const ApiFailure(FailureKind.server);
    await controller.export(sampleImage(), shareText: 't');
    controller.reset();
    expect(controller.status, ExportStatus.idle);
    expect(controller.failure, isNull);
  });

  test('une nouvelle analyse efface l’échec d’export (câblage réel AppServices)', () async {
    final exportApi = FakeExportApi()..failure = const ApiFailure(FailureKind.server);
    final predictionApi = FakePredictionApi(result: samplePrediction());
    final services = AppServices.assemble(
      accountApi: FakeAccountApi(),
      predictionApi: predictionApi,
      exportApi: exportApi,
      imageShare: FakeImageShare(),
      tokenStore: MemoryTokenStore(),
      imageSource: FakeImageSource(image: sampleImage()),
      locale: LocaleController(),
    );
    await services.analysis.pickAndAnalyze(ImageOrigin.gallery);
    await services.export.export(services.analysis.image!, shareText: 't');
    expect(services.export.failure, isNotNull);

    predictionApi.completer = Completer<Prediction>(); // la 2e analyse reste en « chargement »
    final next = services.analysis.pickAndAnalyze(ImageOrigin.gallery);
    await Future<void>.delayed(Duration.zero);
    expect(services.analysis.isLoading, isTrue);
    expect(services.export.failure, isNull); // l'ancien échec d'export a été effacé
    predictionApi.completer!.complete(samplePrediction());
    await next;
  });
}

class _ThrowingExportApi implements ExportApi {
  @override
  Future<ExportedImage> exportAnnotated(PickedImage image, {bool watermark = true}) async =>
      throw StateError('boom');
}
