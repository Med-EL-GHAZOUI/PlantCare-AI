import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:agriscan_mobile/data/prediction_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'helpers.dart';

http.Response pngResponse({
  Uint8List? body,
  String contentType = 'image/png',
  Map<String, String> extra = const {'x-prediction-id': 'p-123', 'x-watermark': 'applied'},
}) =>
    http.Response.bytes(body ?? tinyPng, 200, headers: {'content-type': contentType, ...extra});

http.Response errorResponse(int status, String code) => http.Response.bytes(
      utf8.encode(jsonEncode({'error': {'code': code, 'message': 'x'}})),
      status,
      headers: {'content-type': 'application/json'},
    );

HttpPredictionApi apiWith(MockClientHandler handler, {Duration timeout = const Duration(seconds: 2)}) =>
    HttpPredictionApi(baseUrl: 'http://api.test', client: MockClient(handler), timeout: timeout);

Future<ApiFailure> failureOf(Future<Object?> Function() call) async {
  try {
    await call();
  } on ApiFailure catch (failure) {
    return failure;
  }
  fail('Une ApiFailure était attendue');
}

void main() {
  group('exportAnnotated', () {
    test('POST multipart sur /annotated-image avec le paramètre watermark', () async {
      late http.Request seen;
      final api = apiWith((request) async {
        seen = request;
        return pngResponse();
      });

      final exported = await api.exportAnnotated(sampleImage(name: 'feuille.jpg'));

      expect(seen.method, 'POST');
      expect(seen.url.path, '/api/v1/predictions/annotated-image');
      expect(seen.url.queryParameters, {'watermark': 'true'});
      expect(seen.headers['content-type'], startsWith('multipart/form-data'));
      final body = latin1.decode(seen.bodyBytes);
      expect(body, contains('name="image"'));
      expect(body.toLowerCase(), contains('content-type: image/jpeg'));
      expect(seen.headers.containsKey('Authorization'), isFalse); // l'export est anonyme
      expect(exported.bytes, tinyPng);
      expect(exported.predictionId, 'p-123');
      expect(exported.watermarkApplied, isTrue);
    });

    test('watermark=false transmis et reflété par l’en-tête de réponse', () async {
      late http.Request seen;
      final api = apiWith((request) async {
        seen = request;
        return pngResponse(extra: {'x-watermark': 'none'});
      });
      final exported = await api.exportAnnotated(sampleImage(), watermark: false);
      expect(seen.url.queryParameters, {'watermark': 'false'});
      expect(exported.watermarkApplied, isFalse);
      expect(exported.predictionId, isNull);
    });

    test('format local non pris en charge : refus sans appel réseau', () async {
      var called = false;
      final api = apiWith((_) async {
        called = true;
        return pngResponse();
      });
      final failure = await failureOf(() => api.exportAnnotated(sampleImage(name: 'photo.gif')));
      expect(failure.kind, FailureKind.unsupportedFormat);
      expect(called, isFalse);
    });

    final cases = <String, (int, String, FailureKind)>{
      'fichier trop volumineux': (413, 'file_too_large', FailureKind.fileTooLarge),
      'image corrompue': (400, 'invalid_image', FailureKind.invalidImage),
      'image trop petite': (422, 'image_too_small', FailureKind.imageTooSmall),
      'modèle indisponible': (503, 'model_unavailable', FailureKind.modelUnavailable),
    };
    cases.forEach((name, spec) {
      test('erreur API « $name » → ${spec.$3.name}', () async {
        final api = apiWith((_) async => errorResponse(spec.$1, spec.$2));
        expect((await failureOf(() => api.exportAnnotated(sampleImage()))).kind, spec.$3);
      });
    });

    test('réponse 200 qui n’est pas un PNG valide → invalidResponse', () async {
      expect(
        (await failureOf(() => apiWith((_) async => pngResponse(contentType: 'text/html')).exportAnnotated(sampleImage()))).kind,
        FailureKind.invalidResponse,
      );
      expect(
        (await failureOf(() => apiWith((_) async => pngResponse(body: Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8, 9]))).exportAnnotated(sampleImage()))).kind,
        FailureKind.invalidResponse,
      );
      expect(
        (await failureOf(() => apiWith((_) async => pngResponse(body: Uint8List(0))).exportAnnotated(sampleImage()))).kind,
        FailureKind.invalidResponse,
      );
    });

    test('réseau coupé et délai dépassé', () async {
      expect(
        (await failureOf(() => apiWith((_) async => throw const SocketException('down')).exportAnnotated(sampleImage()))).kind,
        FailureKind.network,
      );
      final slow = apiWith((_) => Completer<http.Response>().future, timeout: const Duration(milliseconds: 50));
      expect((await failureOf(() => slow.exportAnnotated(sampleImage()))).kind, FailureKind.timeout);
    });
  });
}
