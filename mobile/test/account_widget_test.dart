import 'package:agriscan_mobile/app_services.dart';
import 'package:agriscan_mobile/data/prediction_api.dart';
import 'package:agriscan_mobile/l10n/app_localizations_ar.dart';
import 'package:agriscan_mobile/l10n/app_localizations_fr.dart';
import 'package:agriscan_mobile/logic/locale_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agriscan_mobile/app.dart';

import 'helpers.dart';

final fr = AppLocalizationsFr();
final ar = AppLocalizationsAr();

const goodPassword = 'motdepasse-long';

Future<AppServices> pumpApp(
  WidgetTester tester, {
  FakeAccountApi? accountApi,
  FakePredictionApi? predictionApi,
  MemoryTokenStore? tokenStore,
  FakeExportApi? exportApi,
  FakeImageShare? share,
  Locale locale = const Locale('fr'),
  int pageSize = 20,
}) async {
  tester.view.physicalSize = const Size(900, 2200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final services = AppServices.assemble(
    accountApi: accountApi ?? FakeAccountApi(),
    predictionApi: predictionApi ?? FakePredictionApi(result: samplePrediction()),
    exportApi: exportApi ?? FakeExportApi(),
    imageShare: share ?? FakeImageShare(),
    tokenStore: tokenStore ?? MemoryTokenStore(),
    imageSource: FakeImageSource(image: sampleImage()),
    locale: LocaleController(locale),
    historyPageSize: pageSize,
  );
  await tester.pumpWidget(AgriScanApp(services: services));
  await tester.pumpAndSettle();
  return services;
}

Future<void> signInThroughUi(WidgetTester tester, {String email = 'a@b.co'}) async {
  await tester.tap(find.byKey(const Key('sign_in_button')));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const Key('email_field')), email);
  await tester.enterText(find.byKey(const Key('password_field')), goodPassword);
  await tester.tap(find.byKey(const Key('auth_submit')));
  await tester.pumpAndSettle();
}

Future<void> openMenuItem(WidgetTester tester, Key itemKey) async {
  await tester.tap(find.byKey(const Key('account_menu')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(itemKey));
  await tester.pumpAndSettle();
}

void main() {
  group('connexion et inscription', () {
    testWidgets("déconnecté : invitation à se connecter, pas d'historique", (tester) async {
      await pumpApp(tester);
      expect(find.byKey(const Key('sign_in_button')), findsOneWidget);
      expect(find.byKey(const Key('account_menu')), findsNothing);
      expect(find.text(fr.signInToSaveHint), findsOneWidget);
    });

    testWidgets('validation locale : e-mail et mot de passe, aucun appel réseau', (tester) async {
      final api = FakeAccountApi();
      await pumpApp(tester, accountApi: api);
      await tester.tap(find.byKey(const Key('sign_in_button')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('email_field')), 'pas-un-email');
      await tester.enterText(find.byKey(const Key('password_field')), 'court');
      await tester.tap(find.byKey(const Key('auth_submit')));
      await tester.pumpAndSettle();

      expect(find.text(fr.validationEmail), findsOneWidget);
      expect(find.text(fr.validationPassword), findsOneWidget);
      expect(api.calls, isEmpty);
    });

    testWidgets("connexion réussie : retour à l'accueil, e-mail affiché, jeton stocké", (tester) async {
      final store = MemoryTokenStore();
      await pumpApp(tester, tokenStore: store);
      await signInThroughUi(tester);

      expect(find.byKey(const Key('account_menu')), findsOneWidget);
      expect(find.byKey(const Key('email_field')), findsNothing);
      expect(store.value, 'tok-a@b.co');
      await tester.tap(find.byKey(const Key('account_menu')));
      await tester.pumpAndSettle();
      expect(find.text(fr.signedInAs('a@b.co')), findsOneWidget);
    });

    testWidgets('identifiants refusés : message clair, on reste sur le formulaire, rien de stocké', (tester) async {
      final api = FakeAccountApi()..loginFailure = const ApiFailure(FailureKind.invalidCredentials, statusCode: 401);
      final store = MemoryTokenStore();
      await pumpApp(tester, accountApi: api, tokenStore: store);
      await signInThroughUi(tester);

      expect(find.text(fr.errorInvalidCredentials), findsOneWidget);
      expect(find.byKey(const Key('email_field')), findsOneWidget);
      expect(store.value, isNull);
    });

    testWidgets('trop de tentatives : message dédié', (tester) async {
      final api = FakeAccountApi()..loginFailure = const ApiFailure(FailureKind.tooManyAttempts, statusCode: 429);
      await pumpApp(tester, accountApi: api);
      await signInThroughUi(tester);
      expect(find.text(fr.errorTooManyAttempts), findsOneWidget);
    });

    testWidgets('inscription : bascule de mode, compte créé puis session ouverte', (tester) async {
      final api = FakeAccountApi();
      await pumpApp(tester, accountApi: api);
      await tester.tap(find.byKey(const Key('sign_in_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('auth_switch')));
      await tester.pumpAndSettle();
      expect(find.text(fr.registerTitle), findsWidgets);
      expect(find.text(fr.passwordHint), findsOneWidget);

      await tester.enterText(find.byKey(const Key('email_field')), 'new@b.co');
      await tester.enterText(find.byKey(const Key('password_field')), goodPassword);
      await tester.tap(find.byKey(const Key('auth_submit')));
      await tester.pumpAndSettle();

      expect(api.calls, containsAllInOrder(['register:new@b.co', 'login:new@b.co']));
      expect(find.byKey(const Key('account_menu')), findsOneWidget);
    });

    testWidgets('inscription avec un e-mail déjà utilisé', (tester) async {
      final api = FakeAccountApi()..registerFailure = const ApiFailure(FailureKind.emailTaken, statusCode: 409);
      await pumpApp(tester, accountApi: api);
      await tester.tap(find.byKey(const Key('sign_in_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('auth_switch')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('email_field')), 'a@b.co');
      await tester.enterText(find.byKey(const Key('password_field')), goodPassword);
      await tester.tap(find.byKey(const Key('auth_submit')));
      await tester.pumpAndSettle();
      expect(find.text(fr.errorEmailTaken), findsOneWidget);
    });

    testWidgets('le mot de passe est masqué par défaut', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.byKey(const Key('sign_in_button')));
      await tester.pumpAndSettle();
      final field = tester.widget<EditableText>(
        find.descendant(of: find.byKey(const Key('password_field')), matching: find.byType(EditableText)),
      );
      expect(field.obscureText, isTrue);
    });

    testWidgets('session reprise au démarrage depuis le jeton stocké', (tester) async {
      await pumpApp(tester, tokenStore: MemoryTokenStore('tok-saved@b.co'));
      expect(find.byKey(const Key('account_menu')), findsOneWidget);
      expect(find.byKey(const Key('sign_in_button')), findsNothing);
    });

    testWidgets('jeton stocké expiré : retour déconnecté avec message', (tester) async {
      final api = FakeAccountApi()..revokedTokens.add('tok-old@b.co');
      final store = MemoryTokenStore('tok-old@b.co');
      await pumpApp(tester, accountApi: api, tokenStore: store);
      expect(find.byKey(const Key('sign_in_button')), findsOneWidget);
      expect(find.text(fr.sessionExpired), findsOneWidget);
      expect(store.value, isNull);
    });

    testWidgets('déconnexion : jeton effacé, retour au bouton de connexion', (tester) async {
      final store = MemoryTokenStore();
      await pumpApp(tester, tokenStore: store);
      await signInThroughUi(tester);
      await openMenuItem(tester, const Key('menu_sign_out'));
      expect(find.byKey(const Key('sign_in_button')), findsOneWidget);
      expect(store.value, isNull);
    });

    testWidgets('suppression du compte : confirmation obligatoire puis déconnexion', (tester) async {
      final api = FakeAccountApi();
      await pumpApp(tester, accountApi: api);
      await signInThroughUi(tester);

      await openMenuItem(tester, const Key('menu_delete_account'));
      expect(find.text(fr.deleteAccountTitle), findsOneWidget);
      await tester.tap(find.byKey(const Key('dialog_cancel')));
      await tester.pumpAndSettle();
      expect(api.calls, isNot(contains('deleteAccount')));
      expect(find.byKey(const Key('account_menu')), findsOneWidget);

      await openMenuItem(tester, const Key('menu_delete_account'));
      await tester.tap(find.byKey(const Key('dialog_confirm')));
      await tester.pumpAndSettle();
      expect(api.calls, contains('deleteAccount'));
      expect(find.byKey(const Key('sign_in_button')), findsOneWidget);
    });
  });

  group('analyse avec compte', () {
    testWidgets('connecté : le jeton est envoyé et la note « enregistré » apparaît', (tester) async {
      final predictions = FakePredictionApi(result: samplePrediction());
      await pumpApp(tester, predictionApi: predictions);
      await signInThroughUi(tester);
      await tester.tap(find.byKey(const Key('gallery_button')));
      await tester.pumpAndSettle();

      expect(predictions.tokensSeen, ['tok-a@b.co']);
      expect(find.text(fr.savedToHistory), findsOneWidget);
    });

    testWidgets('anonyme : aucun jeton, aucune note « enregistré »', (tester) async {
      final predictions = FakePredictionApi(result: samplePrediction());
      await pumpApp(tester, predictionApi: predictions);
      await tester.tap(find.byKey(const Key('gallery_button')));
      await tester.pumpAndSettle();

      expect(predictions.tokensSeen, [null]);
      expect(find.text(fr.savedToHistory), findsNothing);
    });

    testWidgets("jeton rejeté pendant l'analyse : session fermée, message, réessai anonyme possible", (tester) async {
      final predictions = FakePredictionApi(failure: const ApiFailure(FailureKind.unauthorized, statusCode: 401));
      await pumpApp(tester, predictionApi: predictions);
      await signInThroughUi(tester);
      await tester.tap(find.byKey(const Key('gallery_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('sign_in_button')), findsOneWidget);
      expect(find.text(fr.sessionExpired), findsOneWidget);
      expect(find.text(fr.errorUnauthorized), findsOneWidget);

      predictions
        ..failure = null
        ..result = samplePrediction();
      await tester.tap(find.byKey(const Key('retry_button')));
      await tester.pumpAndSettle();
      expect(predictions.tokensSeen.last, isNull); // le réessai est anonyme
      expect(find.byKey(const Key('result_card')), findsOneWidget);
    });
  });

  group('historique', () {
    Future<FakeAccountApi> openHistory(WidgetTester tester, List<dynamic> records, {int pageSize = 20}) async {
      final api = FakeAccountApi(records: records.cast());
      await pumpApp(tester, accountApi: api, pageSize: pageSize);
      await signInThroughUi(tester);
      await openMenuItem(tester, const Key('menu_history'));
      return api;
    }

    testWidgets("liste vide : message et rappel que les photos ne sont pas conservées", (tester) async {
      await openHistory(tester, []);
      expect(find.byKey(const Key('history_empty')), findsOneWidget);
      expect(find.text(fr.historyPrivacy), findsOneWidget);
    });

    testWidgets('éléments : classe traduite, incertain sans classe, date localisée', (tester) async {
      await openHistory(tester, [
        sampleRecord('a1'),
        sampleRecord('a2', uncertain: true),
      ]);
      expect(find.text(fr.classLateBlight), findsOneWidget);
      expect(find.text(fr.historyUncertainItem), findsOneWidget);
      expect(find.byKey(const Key('history_item_a1')), findsOneWidget);
      expect(find.textContaining('2026'), findsWidgets);
    });

    testWidgets('pagination : « Charger plus » ajoute la page suivante', (tester) async {
      await openHistory(tester, [for (var i = 1; i <= 3; i++) sampleRecord('a$i')], pageSize: 2);
      expect(find.byKey(const Key('history_item_a3')), findsNothing);
      await tester.tap(find.byKey(const Key('load_more_button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('history_item_a3')), findsOneWidget);
      expect(find.byKey(const Key('load_more_button')), findsNothing);
    });

    testWidgets('détail : résultat, avertissements, date et version du modèle', (tester) async {
      await openHistory(tester, [sampleRecord('a1')]);
      await tester.tap(find.byKey(const Key('history_item_a1')));
      await tester.pumpAndSettle();

      expect(find.text(fr.detailTitle), findsOneWidget);
      expect(find.byKey(const Key('result_card')), findsOneWidget);
      expect(find.text(fr.classLateBlight), findsOneWidget);
      expect(find.byKey(const Key('disclaimer')), findsOneWidget);
      expect(find.byKey(const Key('detail_date')), findsOneWidget);
      expect(find.textContaining('mobilenetv2_classifier-10a733ad75f0'), findsOneWidget);
    });

    testWidgets('suppression depuis la liste : confirmation, puis retrait', (tester) async {
      final api = await openHistory(tester, [sampleRecord('a1'), sampleRecord('a2')]);

      await tester.tap(find.byKey(const Key('delete_item_a1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('dialog_cancel')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('history_item_a1')), findsOneWidget); // annulé : rien supprimé

      await tester.tap(find.byKey(const Key('delete_item_a1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('dialog_confirm')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('history_item_a1')), findsNothing);
      expect(find.byKey(const Key('history_item_a2')), findsOneWidget);
      expect(find.text(fr.analysisDeleted), findsOneWidget);
      expect(api.records.map((r) => r.id), ['a2']);
    });

    testWidgets('suppression depuis le détail : retour à la liste actualisée', (tester) async {
      final api = await openHistory(tester, [sampleRecord('a1'), sampleRecord('a2')]);
      await tester.tap(find.byKey(const Key('history_item_a1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('detail_delete_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('dialog_confirm')));
      await tester.pumpAndSettle();

      expect(find.text(fr.historyTitle), findsOneWidget);
      expect(find.byKey(const Key('history_item_a1')), findsNothing);
      expect(api.records.map((r) => r.id), ['a2']);
    });

    testWidgets('erreur réseau : message et bouton Réessayer qui recharge', (tester) async {
      final api = FakeAccountApi(records: [sampleRecord('a1')]);
      await pumpApp(tester, accountApi: api);
      await signInThroughUi(tester);
      api.listFailure = const ApiFailure(FailureKind.network);
      await openMenuItem(tester, const Key('menu_history'));

      expect(find.text(fr.errorNetwork), findsOneWidget);
      api.listFailure = null;
      await tester.tap(find.byKey(const Key('retry_button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('history_item_a1')), findsOneWidget);
    });

    testWidgets("session expirée pendant la consultation : retour à l'accueil déconnecté", (tester) async {
      final api = FakeAccountApi(records: [sampleRecord('a1')]);
      await pumpApp(tester, accountApi: api);
      await signInThroughUi(tester);
      api.revokedTokens.add('tok-a@b.co');
      await openMenuItem(tester, const Key('menu_history'));

      expect(find.byKey(const Key('sign_in_button')), findsOneWidget);
      expect(find.text(fr.sessionExpired), findsOneWidget);
      expect(find.text(fr.historyTitle), findsNothing);
    });

    testWidgets("arabe : historique en RTL avec textes traduits", (tester) async {
      final api = FakeAccountApi(records: [sampleRecord('a1')]);
      await pumpApp(tester, accountApi: api, locale: const Locale('ar'));
      await signInThroughUi(tester);
      await openMenuItem(tester, const Key('menu_history'));

      expect(find.text(ar.historyTitle), findsOneWidget);
      expect(find.text(ar.classLateBlight), findsOneWidget);
      final direction = Directionality.of(tester.element(find.byKey(const Key('history_item_a1'))));
      expect(direction, TextDirection.rtl);
    });
  });
}
