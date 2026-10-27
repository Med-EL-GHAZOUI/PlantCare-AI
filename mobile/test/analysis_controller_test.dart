import 'dart:async';
import 'dart:typed_data';

import 'package:agriscan_mobile/data/models.dart';
import 'package:agriscan_mobile/data/prediction_api.dart';
import 'package:agriscan_mobile/logic/analysis_controller.dart';
import 'package:agriscan_mobile/logic/image_source_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  AnalysisController build(FakePredictionApi api, FakeImageSource source, {int maxBytes = 5 * 1024 * 1024}) =>
      AnalysisController(api: api, imageSource: source, maxUploadBytes: maxBytes);

  test('succès : idle → loading → success', () async {
    final completer = Completer<Prediction>();
    final api = FakePredictionApi(completer: completer);
    final controller = build(api, FakeImageSource(image: sampleImage()));
    final states = <AnalysisStatus>[];
    controller.addListener(() => states.add(controller.status));

    final future = controller.pickAndAnalyze(ImageOrigin.gallery);
    await Future<void>.delayed(Duration.zero);
    expect(controller.status, AnalysisStatus.loading);
    expect(controller.isLoading, isTrue);

    completer.complete(samplePrediction());
    await future;

    expect(states, [AnalysisStatus.loading, AnalysisStatus.success]);
    expect(controller.prediction!.predictedClass, 'Tomato___Late_blight');
    expect(controller.failure, isNull);
  });

  test('annulation de la sélection : aucun changement, aucun appel API', () async {
    final api = FakePredictionApi(result: samplePrediction());
    final controller = build(api, FakeImageSource(image: null));
    await controller.pickAndAnalyze(ImageOrigin.camera);
    expect(controller.status, AnalysisStatus.idle);
    expect(api.calls, 0);
  });

  test('échec du sélecteur (permission refusée) → pickFailed', () async {
    final api = FakePredictionApi(result: samplePrediction());
    final controller = build(api, FakeImageSource(failure: const ApiFailure(FailureKind.pickFailed)));
    await controller.pickAndAnalyze(ImageOrigin.camera);
    expect(controller.status, AnalysisStatus.failure);
    expect(controller.failure!.kind, FailureKind.pickFailed);
    expect(api.calls, 0);
  });

  test('image trop volumineuse refusée avant tout envoi', () async {
    final api = FakePredictionApi(result: samplePrediction());
    final controller = build(api, FakeImageSource(image: sampleImage()), maxBytes: 10);
    await controller.pickAndAnalyze(ImageOrigin.gallery);
    expect(controller.failure!.kind, FailureKind.fileTooLarge);
    expect(api.calls, 0);
  });

  test('fichier vide et format non pris en charge refusés localement', () async {
    final api = FakePredictionApi(result: samplePrediction());
    final empty = build(api, FakeImageSource(image: PickedImage(bytes: Uint8List(0), name: 'a.jpg')));
    await empty.pickAndAnalyze(ImageOrigin.gallery);
    expect(empty.failure!.kind, FailureKind.emptyFile);

    final gif = build(api, FakeImageSource(image: sampleImage(name: 'a.gif')));
    await gif.pickAndAnalyze(ImageOrigin.gallery);
    expect(gif.failure!.kind, FailureKind.unsupportedFormat);
    expect(api.calls, 0);
  });

  test('échec réseau puis réessai réussi avec la même image', () async {
    final api = FakePredictionApi(failure: const ApiFailure(FailureKind.network));
    final source = FakeImageSource(image: sampleImage());
    final controller = build(api, source);

    await controller.pickAndAnalyze(ImageOrigin.gallery);
    expect(controller.status, AnalysisStatus.failure);
    expect(controller.failure!.kind, FailureKind.network);
    expect(controller.image, isNotNull);

    api
      ..failure = null
      ..result = samplePrediction();
    await controller.retry();

    expect(controller.status, AnalysisStatus.success);
    expect(api.calls, 2);
    expect(source.requests, hasLength(1)); // la photo n'est pas redemandée
  });

  test("exception inattendue de l'API → unknown", () async {
    final controller = AnalysisController(api: _ThrowingApi(), imageSource: FakeImageSource(image: sampleImage()));
    await controller.pickAndAnalyze(ImageOrigin.gallery);
    expect(controller.status, AnalysisStatus.failure);
    expect(controller.failure!.kind, FailureKind.unknown);
  });

  test('une seconde demande pendant le chargement est ignorée', () async {
    final completer = Completer<Prediction>();
    final api = FakePredictionApi(completer: completer);
    final controller = build(api, FakeImageSource(image: sampleImage()));

    final first = controller.pickAndAnalyze(ImageOrigin.gallery);
    await Future<void>.delayed(Duration.zero);
    await controller.pickAndAnalyze(ImageOrigin.camera);
    await controller.retry();
    expect(api.calls, 1);

    completer.complete(samplePrediction());
    await first;
  });

  test('reset revient à l’état initial', () async {
    final controller = build(FakePredictionApi(result: samplePrediction()), FakeImageSource(image: sampleImage()));
    await controller.pickAndAnalyze(ImageOrigin.gallery);
    controller.reset();
    expect(controller.status, AnalysisStatus.idle);
    expect(controller.image, isNull);
    expect(controller.prediction, isNull);
  });

  test('résultat incertain conservé tel quel (pas de classe)', () async {
    final controller = build(
        FakePredictionApi(result: samplePrediction(uncertain: true)), FakeImageSource(image: sampleImage()));
    await controller.pickAndAnalyze(ImageOrigin.gallery);
    expect(controller.status, AnalysisStatus.success);
    expect(controller.prediction!.isUncertain, isTrue);
    expect(controller.prediction!.predictedClass, isNull);
  });
}

class _ThrowingApi implements PredictionApi {
  @override
  Future<Prediction> predict(PickedImage image) async => throw StateError('boom');
}
