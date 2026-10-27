import 'dart:async';

import 'package:agriscan_mobile/data/prediction_api.dart';
import 'package:agriscan_mobile/logic/session_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  late FakeAccountApi api;
  late MemoryTokenStore store;
  late SessionController session;

  setUp(() {
    api = FakeAccountApi();
    store = MemoryTokenStore();
    session = SessionController(api: api, tokenStore: store);
  });

  group('restore', () {
    test('sans jeton stocké : déconnecté, aucun appel réseau', () async {
      await session.restore();
      expect(session.status, SessionStatus.signedOut);
      expect(api.calls, isEmpty);
    });

    test('jeton valide : session reprise avec le profil', () async {
      store.value = 'tok-a@b.co';
      await session.restore();
      expect(session.isSignedIn, isTrue);
      expect(session.user!.email, 'a@b.co');
      expect(session.accessToken, 'tok-a@b.co');
    });

    test('jeton rejeté (401) : effacé du stockage, session expirée signalée', () async {
      store.value = 'tok-a@b.co';
      api.revokedTokens.add('tok-a@b.co');
      await session.restore();
      expect(session.status, SessionStatus.signedOut);
      expect(session.sessionExpired, isTrue);
      expect(store.value, isNull);
    });

    test('hors ligne : le jeton est conservé et la session reste ouverte', () async {
      store.value = 'tok-a@b.co';
      api.meFailure = const ApiFailure(FailureKind.network);
      await session.restore();
      expect(session.isSignedIn, isTrue);
      expect(session.user, isNull);
      expect(store.value, 'tok-a@b.co');
    });
  });

  group('connexion et inscription', () {
    test('connexion réussie : jeton stocké de façon sécurisée, profil chargé', () async {
      final ok = await session.signIn('a@b.co', 'motdepasse-long');
      expect(ok, isTrue);
      expect(session.isSignedIn, isTrue);
      expect(store.value, 'tok-a@b.co');
      expect(store.writes, 1);
      expect(api.calls, ['login:a@b.co', 'me']);
    });

    test('identifiants refusés : aucun jeton écrit, échec exposé', () async {
      api.loginFailure = const ApiFailure(FailureKind.invalidCredentials, statusCode: 401);
      final ok = await session.signIn('a@b.co', 'mauvais-mot-de-passe');
      expect(ok, isFalse);
      expect(session.status, SessionStatus.signedOut);
      expect(session.failure!.kind, FailureKind.invalidCredentials);
      expect(store.writes, 0);
      expect(store.value, isNull);
    });

    test('inscription : crée le compte puis ouvre la session', () async {
      final ok = await session.register('new@b.co', 'motdepasse-long');
      expect(ok, isTrue);
      expect(api.calls.take(2), ['register:new@b.co', 'login:new@b.co']);
      expect(session.user!.email, 'new@b.co');
    });

    test('e-mail déjà utilisé : pas de connexion tentée', () async {
      api.registerFailure = const ApiFailure(FailureKind.emailTaken, statusCode: 409);
      expect(await session.register('a@b.co', 'motdepasse-long'), isFalse);
      expect(session.failure!.kind, FailureKind.emailTaken);
      expect(api.calls, ['register:a@b.co']);
    });

    test("trop de tentatives : l'échec est exposé", () async {
      api.loginFailure = const ApiFailure(FailureKind.tooManyAttempts, statusCode: 429);
      await session.signIn('a@b.co', 'motdepasse-long');
      expect(session.failure!.kind, FailureKind.tooManyAttempts);
    });

    test('une seconde demande pendant une connexion est ignorée', () async {
      api.loginGate = Completer<void>();
      final first = session.signIn('a@b.co', 'motdepasse-long');
      await Future<void>.delayed(Duration.zero);
      expect(session.isBusy, isTrue);
      expect(await session.signIn('a@b.co', 'motdepasse-long'), isFalse);
      api.loginGate!.complete();
      expect(await first, isTrue);
      expect(api.calls.where((c) => c.startsWith('login')), hasLength(1));
    });
  });

  group('fermeture de session', () {
    test('déconnexion : jeton effacé du stockage et de la mémoire', () async {
      await session.signIn('a@b.co', 'motdepasse-long');
      await session.signOut();
      expect(session.status, SessionStatus.signedOut);
      expect(session.accessToken, isNull);
      expect(store.value, isNull);
    });

    test('suppression du compte : appel serveur puis déconnexion', () async {
      await session.signIn('a@b.co', 'motdepasse-long');
      expect(await session.deleteAccount(), isTrue);
      expect(api.calls, contains('deleteAccount'));
      expect(session.isSignedIn, isFalse);
      expect(store.value, isNull);
    });

    test("échec de suppression du compte : la session reste ouverte, l'échec est exposé", () async {
      await session.signIn('a@b.co', 'motdepasse-long');
      api.deleteAccountFailure = const ApiFailure(FailureKind.network);
      expect(await session.deleteAccount(), isFalse);
      expect(session.isSignedIn, isTrue);
      expect(session.failure!.kind, FailureKind.network);
      expect(store.value, 'tok-a@b.co');
    });

    test('expire() efface le jeton et signale la session expirée', () async {
      await session.signIn('a@b.co', 'motdepasse-long');
      await session.expire();
      expect(session.isSignedIn, isFalse);
      expect(session.sessionExpired, isTrue);
      expect(store.value, isNull);
    });
  });
}
