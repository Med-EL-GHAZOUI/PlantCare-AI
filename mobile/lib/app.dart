import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app_services.dart';
import 'l10n/app_localizations.dart';
import 'logic/locale_controller.dart';
import 'ui/home_screen.dart';

class AgriScanApp extends StatefulWidget {
  const AgriScanApp({super.key, required this.services});

  final AppServices services;

  @override
  State<AgriScanApp> createState() => _AgriScanAppState();
}

class _AgriScanAppState extends State<AgriScanApp> {
  @override
  void initState() {
    super.initState();
    widget.services.session.restore(); // reprend la session si un jeton valide est stocké
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.services.locale,
      builder: (context, _) => MaterialApp(
        onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
        debugShowCheckedModeBanner: false,
        theme: ThemeData(colorSchemeSeed: const Color(0xFF2E7D32), useMaterial3: true),
        locale: widget.services.locale.locale,
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
        home: HomeScreen(services: widget.services),
      ),
    );
  }
}
