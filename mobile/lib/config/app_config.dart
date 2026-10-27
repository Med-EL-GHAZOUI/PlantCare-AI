/// Configuration de build. L'URL de l'API se définit à la compilation :
/// `flutter run --dart-define=API_BASE_URL=https://api.exemple.com`.
/// Par défaut : `http://10.0.2.2:8000`, l'adresse de la machine hôte vue depuis l'émulateur Android.
/// En production, utiliser uniquement HTTPS.
class AppConfig {
  const AppConfig._();

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000',
  );

  /// Limite d'envoi identique à celle de l'API (AGRISCAN_MAX_UPLOAD_BYTES, 5 Mo par défaut).
  static const int maxUploadBytes = 5 * 1024 * 1024;

  static const Duration requestTimeout = Duration(seconds: 30);
}
