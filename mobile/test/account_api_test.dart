import 'dart:convert';
import 'dart:io';

import 'package:agriscan_mobile/data/account_api.dart';
import 'package:agriscan_mobile/data/prediction_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'helpers.dart';

http.Response jsonResponse(Object? body, [int status = 200]) => http.Response.bytes(
      utf8.encode(jsonEncode(body)),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

http.Response errorResponse(int status, String code) => jsonResponse({'error': {'code': code, 'message': 'x'}}, status);

Map<String, dynamic> recordJson(String id) => {
      'id': id,
      'status': 'prediction_available',
      'predicted_class': 'Tomato___Late_blight',
      'confidence_score': 0.91,
      'scores': {for (final c in kClasses) c: 0.01},
      'model_version': 'mobilenetv2_classifier-10a733ad75f0',
      'created_at': '2026-10-27T14:30:00.123456Z',
    };

HttpAccountApi apiWith(MockClientHandler handler) =>
    HttpAccountApi(baseUrl: 'http://api.test', client: MockClient(handler), timeout: const Duration(seconds: 2));

Future<ApiFailure> failureOf(Future<Object?> Function() call) async {
  try {
    await call();
  } on ApiFailure catch (failure) {
    return failure;
  }
  fail('Une ApiFailure était attendue');
}

void main() {
  group('requêtes', () {
    test('login : POST JSON, sans en-tête Authorization', () async {
      late http.Request seen;
      final api = apiWith((request) async {
        seen = request;
        return jsonResponse({'access_token': 'jwt.abc', 'token_type': 'bearer', 'expires_in': 1800});
      });
      final token = await api.login('a@b.co', 'secret-pass-123');
      expect(seen.method, 'POST');
      expect(seen.url.toString(), 'http://api.test/api/v1/auth/login');
      expect(seen.headers['content-type'], contains('application/json'));
      expect(jsonDecode(seen.body), {'email': 'a@b.co', 'password': 'secret-pass-123'});
      expect(seen.headers.containsKey('Authorization'), isFalse);
      expect(token.value, 'jwt.abc');
      expect(token.expiresInSeconds, 1800);
    });

    test('register : 201 → profil', () async {
      final api = apiWith((_) async => jsonResponse({'id': 'u1', 'email': 'a@b.co', 'role': 'user'}, 201));
      final user = await api.register('a@b.co', 'secret-pass-123');
      expect(user.email, 'a@b.co');
      expect(user.role, 'user');
    });

    test('jeton envoyé dans l’en-tête Bearer, jamais dans l’URL', () async {
      final seen = <http.Request>[];
      final api = apiWith((request) async {
        seen.add(request);
        if (request.method == 'DELETE') return http.Response('', 204);
        if (request.url.path.endsWith('/auth/me')) return jsonResponse({'id': 'u1', 'email': 'a@b.co', 'role': 'user'});
        if (request.url.path.endsWith('/analyses')) return jsonResponse({'items': [recordJson('a1')], 'total': 1, 'limit': 20, 'offset': 0});
        return jsonResponse(recordJson('a1'));
      });
      await api.me('SECRET-TOKEN');
      await api.listAnalyses('SECRET-TOKEN', limit: 10, offset: 20);
      await api.getAnalysis('SECRET-TOKEN', 'a1');
      await api.deleteAnalysis('SECRET-TOKEN', 'a1');
      await api.deleteAccount('SECRET-TOKEN');

      expect(seen, hasLength(5));
      for (final request in seen) {
        expect(request.headers['Authorization'], 'Bearer SECRET-TOKEN');
        expect(request.url.toString(), isNot(contains('SECRET-TOKEN')));
      }
      expect(seen[1].url.queryParameters, {'limit': '10', 'offset': '20'});
      expect(seen[2].url.path, '/api/v1/analyses/a1');
      expect(seen[3].method, 'DELETE');
      expect(seen[4].url.path, '/api/v1/auth/me');
    });

    test('identifiant d’analyse encodé dans le chemin', () async {
      late http.Request seen;
      final api = apiWith((request) async {
        seen = request;
        return http.Response('', 204);
      });
      await api.deleteAnalysis('t', '../../auth/me');
      // Les « / » de l'identifiant sont encodés : il reste un seul segment (pas de remontée d'arborescence).
      expect(seen.url.pathSegments, hasLength(4));
      expect(seen.url.path, contains('%2F'));
    });
  });

  group('analyse des réponses', () {
    test('page d’analyses : champs, date en heure locale, classe nulle pour un incertain', () async {
      final uncertain = recordJson('a2')
        ..['status'] = 'uncertain'
        ..['predicted_class'] = null;
      final api = apiWith((_) async => jsonResponse({'items': [recordJson('a1'), uncertain], 'total': 7, 'limit': 20, 'offset': 0}));
      final page = await api.listAnalyses('t');
      expect(page.total, 7);
      expect(page.items, hasLength(2));
      expect(page.items.first.predictedClass, 'Tomato___Late_blight');
      expect(page.items.first.createdAt.toUtc(), DateTime.utc(2026, 10, 27, 14, 30, 0, 123, 456));
      expect(page.items.last.isUncertain, isTrue);
      expect(page.items.last.predictedClass, isNull);
      expect(page.items.first.toPrediction().confidence, closeTo(0.91, 1e-9));
    });

    test('réponses hors contrat → invalidResponse', () async {
      expect((await failureOf(() => apiWith((_) async => http.Response('pas du json', 200)).listAnalyses('t'))).kind,
          FailureKind.invalidResponse);
      expect((await failureOf(() => apiWith((_) async => jsonResponse({'items': 'x'})).listAnalyses('t'))).kind,
          FailureKind.invalidResponse);
      expect((await failureOf(() => apiWith((_) async => jsonResponse({'token_type': 'bearer'})).login('a', 'b'))).kind,
          FailureKind.invalidResponse);
    });
  });

  group('erreurs', () {
    final cases = <String, (int, String, FailureKind)>{
      'identifiants incorrects': (401, 'invalid_credentials', FailureKind.invalidCredentials),
      'jeton invalide': (401, 'not_authenticated', FailureKind.unauthorized),
      'e-mail déjà utilisé': (409, 'email_already_registered', FailureKind.emailTaken),
      'trop de tentatives': (429, 'too_many_attempts', FailureKind.tooManyAttempts),
      'analyse introuvable': (404, 'not_found', FailureKind.notFound),
      'requête invalide': (422, 'invalid_request', FailureKind.invalidInput),
      'base indisponible': (503, 'database_unavailable', FailureKind.accountsUnavailable),
      'authentification non configurée': (503, 'auth_unavailable', FailureKind.accountsUnavailable),
    };
    cases.forEach((name, spec) {
      test('« $name » → ${spec.$3.name}', () async {
        final failure = await failureOf(() => apiWith((_) async => errorResponse(spec.$1, spec.$2)).login('a', 'b'));
        expect(failure.kind, spec.$3);
        expect(failure.statusCode, spec.$1);
      });
    });

    test('statuts sans corps JSON', () async {
      expect((await failureOf(() => apiWith((_) async => http.Response('', 401)).me('t'))).kind, FailureKind.unauthorized);
      expect((await failureOf(() => apiWith((_) async => http.Response('', 429)).login('a', 'b'))).kind, FailureKind.tooManyAttempts);
      expect((await failureOf(() => apiWith((_) async => http.Response('<html>', 502)).me('t'))).kind, FailureKind.server);
    });

    test('réseau coupé', () async {
      expect((await failureOf(() => apiWith((_) async => throw const SocketException('down')).me('t'))).kind,
          FailureKind.network);
    });

    test('un statut inattendu (200 au lieu de 204) est traité comme une erreur', () async {
      final failure = await failureOf(() => apiWith((_) async => http.Response('', 200)).deleteAnalysis('t', 'a1'));
      expect(failure.kind, FailureKind.unknown);
    });
  });
}
