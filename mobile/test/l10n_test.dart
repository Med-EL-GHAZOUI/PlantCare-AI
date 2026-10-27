import 'dart:convert';
import 'dart:io';

import 'package:agriscan_mobile/data/prediction_api.dart';
import 'package:agriscan_mobile/l10n/app_localizations_ar.dart';
import 'package:agriscan_mobile/l10n/app_localizations_fr.dart';
import 'package:agriscan_mobile/ui/localized_text.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

Map<String, dynamic> readArb(String locale) =>
    jsonDecode(File('lib/l10n/app_$locale.arb').readAsStringSync()) as Map<String, dynamic>;

Set<String> messageKeys(Map<String, dynamic> arb) =>
    arb.keys.where((key) => !key.startsWith('@')).toSet();

void main() {
  test('les fichiers ARB français et arabe ont exactement les mêmes clés', () {
    final frKeys = messageKeys(readArb('fr'));
    final arKeys = messageKeys(readArb('ar'));
    expect(arKeys.difference(frKeys), isEmpty, reason: 'clés arabes en trop');
    expect(frKeys.difference(arKeys), isEmpty, reason: 'clés arabes manquantes');
  });

  test('aucune traduction vide', () {
    for (final locale in ['fr', 'ar']) {
      readArb(locale).forEach((key, value) {
        if (!key.startsWith('@') && value is String) {
          expect(value.trim(), isNotEmpty, reason: '$locale:$key');
        }
      });
    }
  });

  test('les 10 classes du modèle ont un nom français et arabe distincts', () {
    final frNames = kClasses.map((c) => localizedClassName(fr, c)).toSet();
    final arNames = kClasses.map((c) => localizedClassName(ar, c)).toSet();
    expect(frNames, hasLength(10));
    expect(arNames, hasLength(10));
    for (final name in [...frNames, ...arNames]) {
      expect(name, isNot(contains('inconnue')));
      expect(name, isNot(contains('غير معروفة')));
    }
  });

  test('chaque type d’échec a un message dans les deux langues', () {
    for (final kind in FailureKind.values) {
      expect(failureMessage(fr, kind), isNotEmpty);
      expect(failureMessage(ar, kind), isNotEmpty);
    }
  });

  test("les textes de prudence rappellent que ce n'est pas un diagnostic", () {
    expect(fr.disclaimer, contains('pas un diagnostic'));
    expect(ar.disclaimer, contains('ليست تشخيصًا'));
  });

  test('aucune recommandation de traitement ou de dosage dans les textes', () {
    final text = '${fr.disclaimer}${fr.limitsBody}${fr.uncertainBody}'.toLowerCase();
    for (final banned in ['dose', 'dosage', 'pesticide', 'fongicide', 'litre']) {
      expect(text, isNot(contains(banned)));
    }
  });
}

final fr = AppLocalizationsFr();
final ar = AppLocalizationsAr();
