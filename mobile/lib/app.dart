import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'l10n/app_localizations.dart';
import 'logic/analysis_controller.dart';
import 'logic/locale_controller.dart';
import 'ui/home_screen.dart';

class AgriScanApp extends StatelessWidget {
  const AgriScanApp({super.key, required this.controller, required this.localeController});

  final AnalysisController controller;
  final LocaleController localeController;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: localeController,
      builder: (context, _) => MaterialApp(
        onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
        debugShowCheckedModeBanner: false,
        theme: ThemeData(colorSchemeSeed: const Color(0xFF2E7D32), useMaterial3: true),
        locale: localeController.locale,
        supportedLocales: LocaleController.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        // Langue du système si prise en charge, sinon français. Le RTL découle de la locale arabe.
        localeResolutionCallback: (device, supported) {
          for (final locale in supported) {
            if (locale.languageCode == device?.languageCode) return locale;
          }
          return supported.first;
        },
        home: HomeScreen(controller: controller, localeController: localeController),
      ),
    );
  }
}
