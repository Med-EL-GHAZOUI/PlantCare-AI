import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:agriscan_mobile/data/models.dart';
import 'package:agriscan_mobile/data/prediction_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'helpers.dart';

http.Response jsonResponse(Object body, [int status = 200]) => http.Response.bytes(
      utf8.encode(jsonEncode(body)),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

HttpPredictionApi apiWith(MockClientHandler handler, {Duration? timeout}) => HttpPredictionApi(
      baseUrl: 'http://api.test',
      client: MockClient(handler),
      timeout: timeout ?? const Duration(seconds: 2),
    );

http.Response errorResponse(int status, String code) =>
    http.Response(jsonEncode({'error': {'code': code, 'message': 'x'}}), status);

Future<ApiFailure> failureOf(HttpPredictionApi api, [PickedImage? image]) async {
  try {
    await api.predict(image ?? sampleImage());
  } on ApiFailure catch (failure) {
    return failure;
  }
  fail('Une ApiFailure était attendue');
}

void main() {
  group('Prediction.fromJson', () {
    test('réponse disponible', () {
      final prediction = Prediction.fromJson(predictionJson());
      expect(prediction.status, PredictionStatus.predictionAvailable);
      expect(prediction.predictedClass, 'Tomato___Late_blight');
      expect(prediction.confidence, closeTo(0.91, 1e-9));
      expect(prediction.topScores(2).first.key, 'Tomato___Late_blight');
      expect(prediction.isUncertain, isFalse);
    });

    test('réponse incertaine sans classe', () {
      final prediction = samplePrediction(uncertain: true);
      expect(prediction.isUncertain, isTrue);
      expect(prediction.predictedClass, isNull);
    });

    test('rejette les réponses hors contrat', () {
      expect(() => Prediction.fromJson('texte'), throwsFormatException);
      expect(() => Prediction.fromJson({...predictionJson(), 'status': 'autre'}), throwsFormatException);
      expect(() => Prediction.fromJson({...predictionJson(), 'scores': {}}), throwsFormatException);
      expect(() => Prediction.fromJson({...predictionJson(), 'predicted_class': null}), throwsFormatException);
      expect(() => Prediction.fromJson({...predictionJson(), 'confidence': 'haute'}), throwsFormatException);
    });
  });

  group('HttpPredictionApi.predict', () {
    test('envoie un multipart avec le champ image et le bon type MIME', () async {
      late http.Request seen;
      final api = apiWith((request) async {
        seen = request;
        return jsonResponse(predictionJson());
      });

      final prediction = await api.predict(sampleImage(name: 'feuille.PNG'));

      expect(seen.method, 'POST');
      expect(seen.url.toString(), 'http://api.test/api/v1/predictions');
      expect(seen.headers['content-type'], startsWith('multipart/form-data'));
      final body = latin1.decode(seen.bodyBytes);
      expect(body, contains('name="image"'));
      expect(body, contains('filename="feuille.PNG"'));
      expect(body.toLowerCase(), contains('content-type: image/png'));
      expect(prediction.predictedClass, 'Tomato___Late_blight');
    });

    test('refuse localement un format autre que JPEG/PNG sans appeler le réseau', () async {
      var called = false;
      final api = apiWith((_) async {
        called = true;
        return http.Response('', 200);
      });
      final failure = await failureOf(api, sampleImage(name: 'photo.gif'));
      expect(failure.kind, FailureKind.unsupportedFormat);
      expect(called, isFalse);
    });

    final cases = <String, (int, String, FailureKind)>{
      'fichier trop volumineux': (413, 'file_too_large', FailureKind.fileTooLarge),
      'format non pris en charge': (415, 'unsupported_media_type', FailureKind.unsupportedFormat),
      'image corrompue': (400, 'invalid_image', FailureKind.invalidImage),
      'fichier vide': (400, 'empty_file', FailureKind.emptyFile),
      'image trop petite': (422, 'image_too_small', FailureKind.imageTooSmall),
      'dimensions excessives': (422, 'image_dimensions_too_large', FailureKind.imageTooLarge),
      'modèle indisponible': (503, 'model_unavailable', FailureKind.modelUnavailable),
      'erreur interne': (500, 'internal_error', FailureKind.server),
    };
    cases.forEach((name, spec) {
      test('code API « $name » → ${spec.$3.name}', () async {
        final api = apiWith((_) async => errorResponse(spec.$1, spec.$2));
        final failure = await failureOf(api);
        expect(failure.kind, spec.$3);
        expect(failure.code, spec.$2);
        expect(failure.statusCode, spec.$1);
      });
    });

    test('statut HTTP sans corps JSON exploitable', () async {
      expect((await failureOf(apiWith((_) async => http.Response('<html>', 502)))).kind, FailureKind.server);
      expect((await failureOf(apiWith((_) async => http.Response('', 413)))).kind, FailureKind.fileTooLarge);
      expect((await failureOf(apiWith((_) async => http.Response('', 418)))).kind, FailureKind.unknown);
    });

    test('perte de réseau', () async {
      expect((await failureOf(apiWith((_) async => throw const SocketException('down')))).kind, FailureKind.network);
      expect((await failureOf(apiWith((_) async => throw http.ClientException('down')))).kind, FailureKind.network);
    });

    test('délai dépassé', () async {
      final api = apiWith((_) => Completer<http.Response>().future, timeout: const Duration(milliseconds: 50));
      expect((await failureOf(api)).kind, FailureKind.timeout);
    });

    test('réponse 200 invalide → invalidResponse', () async {
      expect((await failureOf(apiWith((_) async => http.Response('pas du json', 200)))).kind,
          FailureKind.invalidResponse);
      expect((await failureOf(apiWith((_) async => http.Response('{"status":"uncertain"}', 200)))).kind,
          FailureKind.invalidResponse);
    });

    test('les échecs temporaires sont rejouables, les autres non', () {
      expect(const ApiFailure(FailureKind.network).isRetryable, isTrue);
      expect(const ApiFailure(FailureKind.modelUnavailable).isRetryable, isTrue);
      expect(const ApiFailure(FailureKind.fileTooLarge).isRetryable, isFalse);
      expect(const ApiFailure(FailureKind.invalidImage).isRetryable, isFalse);
    });
  });
}
