import 'package:flutter/material.dart';

/// Langue choisie par l'utilisateur ; null = langue du système (français si non prise en charge).
/// Le choix n'est pas conservé entre deux lancements (pas de stockage local à ce stade).
class LocaleController extends ChangeNotifier {
  LocaleController([this._locale]);

  static const supportedLocales = [Locale('fr'), Locale('ar')];

  Locale? _locale;
  Locale? get locale => _locale;

  void setLocale(Locale? locale) {
    if (locale == _locale) return;
    _locale = locale;
    notifyListeners();
  }
}
