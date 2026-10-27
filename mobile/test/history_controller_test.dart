import 'dart:async';

import 'package:agriscan_mobile/data/prediction_api.dart';
import 'package:agriscan_mobile/logic/detail_controller.dart';
import 'package:agriscan_mobile/logic/history_controller.dart';
import 'package:agriscan_mobile/logic/session_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

Future<(FakeAccountApi, SessionController, HistoryController)> setUpSignedIn({int count = 5, int pageSize = 2}) async {
  final api = FakeAccountApi(records: [for (var i = 1; i <= count; i++) sampleRecord('a$i')]);
  final session = SessionController(api: api, tokenStore: MemoryTokenStore());
  await session.signIn('a@b.co', 'motdepasse-long');
  return (api, session, HistoryController(api: api, session: session, pageSize: pageSize));
}

void main() {
  group('HistoryController', () {
    test('refresh charge la première page', () async {
      final (api, _, history) = await setUpSignedIn();
      await history.refresh();
      expect(history.status, HistoryStatus.loaded);
      expect(history.items.map((r) => r.id), ['a1', 'a2']);
      expect(history.total, 5);
      expect(history.hasMore, isTrue);
      expect(api.calls.last, 'list:2:0');
    });

    test('loadMore ajoute les pages suivantes jusqu’à la fin', () async {
      final (_, _, history) = await setUpSignedIn();
      await history.refresh();
      await history.loadMore();
      await history.loadMore();
      expect(history.items.map((r) => r.id), ['a1', 'a2', 'a3', 'a4', 'a5']);
      expect(history.hasMore, isFalse);
      await history.loadMore(); // sans effet
      expect(history.items, hasLength(5));
    });

    test('liste vide : état chargé sans élément', () async {
      final (_, _, history) = await setUpSignedIn(count: 0);
      await history.refresh();
      expect(history.status, HistoryStatus.loaded);
      expect(history.items, isEmpty);
    });

    test('échec réseau puis réessai', () async {
      final (api, _, history) = await setUpSignedIn();
      api.listFailure = const ApiFailure(FailureKind.network);
      await history.refresh();
      expect(history.status, HistoryStatus.failure);
      expect(history.failure!.kind, FailureKind.network);

      api.listFailure = null;
      await history.refresh();
      expect(history.status, HistoryStatus.loaded);
      expect(history.failure, isNull);
    });

    test('401 : la session est fermée', () async {
      final (api, session, history) = await setUpSignedIn();
      api.revokedTokens.add(session.accessToken!);
      await history.refresh();
      expect(history.failure!.kind, FailureKind.unauthorized);
      expect(session.isSignedIn, isFalse);
      expect(session.sessionExpired, isTrue);
    });

    test('suppression : retirée du serveur et de la liste, total décrémenté', () async {
      final (api, _, history) = await setUpSignedIn(pageSize: 10);
      await history.refresh();
      expect(await history.delete('a2'), isTrue);
      expect(history.items.map((r) => r.id), ['a1', 'a3', 'a4', 'a5']);
      expect(history.total, 4);
      expect(api.records.map((r) => r.id), isNot(contains('a2')));
    });

    test('suppression d’une analyse déjà supprimée ailleurs : retirée sans erreur', () async {
      final (api, _, history) = await setUpSignedIn(pageSize: 10);
      await history.refresh();
      api.records.removeWhere((r) => r.id == 'a1');
      expect(await history.delete('a1'), isTrue);
      expect(history.items.map((r) => r.id), isNot(contains('a1')));
    });

    test('échec de suppression : la liste reste intacte', () async {
      final (api, _, history) = await setUpSignedIn(pageSize: 10);
      await history.refresh();
      api.deleteFailure = const ApiFailure(FailureKind.server);
      expect(await history.delete('a1'), isFalse);
      expect(history.items, hasLength(5));
      expect(history.failure!.kind, FailureKind.server);
    });

    test('sans jeton : unauthorized sans appel réseau', () async {
      final api = FakeAccountApi();
      final session = SessionController(api: api, tokenStore: MemoryTokenStore());
      final history = HistoryController(api: api, session: session);
      await history.refresh();
      expect(history.failure!.kind, FailureKind.unauthorized);
      expect(api.calls, isEmpty);
    });
  });

  group('DetailController', () {
    test('charge depuis le serveur et remplace la version de la liste', () async {
      final (api, session, _) = await setUpSignedIn();
      final controller = DetailController(
        api: api,
        session: session,
        analysisId: 'a1',
        initial: sampleRecord('a1', uncertain: true),
      );
      expect(controller.status, DetailStatus.loaded);
      await controller.load();
      expect(controller.record!.isUncertain, isFalse); // la version serveur fait foi
    });

    test('analyse introuvable : échec notFound', () async {
      final (api, session, _) = await setUpSignedIn();
      final controller = DetailController(api: api, session: session, analysisId: 'zzz');
      await controller.load();
      expect(controller.status, DetailStatus.failure);
      expect(controller.failure!.kind, FailureKind.notFound);
    });

    test('suppression réussie', () async {
      final (api, session, _) = await setUpSignedIn();
      final controller =
          DetailController(api: api, session: session, analysisId: 'a1', initial: sampleRecord('a1'));
      expect(await controller.delete(), isTrue);
      expect(controller.status, DetailStatus.deleted);
      expect(api.records.map((r) => r.id), isNot(contains('a1')));
    });

    test("échec de suppression : l'analyse reste affichée avec l'erreur", () async {
      final (api, session, _) = await setUpSignedIn();
      api.deleteFailure = const ApiFailure(FailureKind.network);
      final controller =
          DetailController(api: api, session: session, analysisId: 'a1', initial: sampleRecord('a1'));
      expect(await controller.delete(), isFalse);
      expect(controller.status, DetailStatus.loaded);
      expect(controller.record, isNotNull);
      expect(controller.failure!.kind, FailureKind.network);
    });

    test('la suppression reste possible pendant un rechargement lent, sans ressusciter l’analyse', () async {
      final (api, session, _) = await setUpSignedIn();
      api.getGate = Completer<void>();
      final controller =
          DetailController(api: api, session: session, analysisId: 'a1', initial: sampleRecord('a1'));
      final loading = controller.load(); // rechargement en arrière-plan, bloqué
      await Future<void>.delayed(Duration.zero);
      expect(controller.isLoading, isTrue);
      expect(controller.isDeleting, isFalse);

      expect(await controller.delete(), isTrue);
      expect(controller.status, DetailStatus.deleted);

      api.getGate!.complete(); // la réponse tardive arrive après la suppression
      await loading;
      expect(controller.status, DetailStatus.deleted);
    });

    test('401 pendant le chargement : session fermée', () async {
      final (api, session, _) = await setUpSignedIn();
      api.revokedTokens.add(session.accessToken!);
      final controller = DetailController(api: api, session: session, analysisId: 'a1');
      await controller.load();
      expect(session.isSignedIn, isFalse);
    });
  });
}
