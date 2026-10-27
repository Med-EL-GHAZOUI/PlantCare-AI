import 'config/app_config.dart';
import 'data/account_api.dart';
import 'data/prediction_api.dart';
import 'data/token_store.dart';
import 'logic/analysis_controller.dart';
import 'logic/history_controller.dart';
import 'logic/image_source_service.dart';
import 'logic/locale_controller.dart';
import 'logic/session_controller.dart';

/// Regroupe les contrôleurs et services partagés par les écrans (injection simple, sans bibliothèque).
class AppServices {
  AppServices({
    required this.accountApi,
    required this.session,
    required this.analysis,
    required this.history,
    required this.locale,
  });

  final AccountApi accountApi;
  final SessionController session;
  final AnalysisController analysis;
  final HistoryController history;
  final LocaleController locale;

  /// Assemblage de production : HTTP réel, stockage sécurisé du jeton, caméra et galerie.
  factory AppServices.production() {
    final accountApi = HttpAccountApi(baseUrl: AppConfig.apiBaseUrl, timeout: AppConfig.requestTimeout);
    return AppServices.assemble(
      accountApi: accountApi,
      predictionApi: HttpPredictionApi(baseUrl: AppConfig.apiBaseUrl, timeout: AppConfig.requestTimeout),
      tokenStore: SecureTokenStore(),
      imageSource: DeviceImageSourceService(),
      locale: LocaleController(),
    );
  }

  /// Assemblage commun (production et tests) : relie le jeton de session à l'analyse et à l'historique.
  factory AppServices.assemble({
    required AccountApi accountApi,
    required PredictionApi predictionApi,
    required TokenStore tokenStore,
    required ImageSourceService imageSource,
    required LocaleController locale,
    int maxUploadBytes = AppConfig.maxUploadBytes,
    int historyPageSize = 20,
  }) {
    final session = SessionController(api: accountApi, tokenStore: tokenStore);
    final analysis = AnalysisController(
      api: predictionApi,
      imageSource: imageSource,
      maxUploadBytes: maxUploadBytes,
      accessToken: () => session.accessToken,
      onUnauthorized: session.expire,
    );
    final history = HistoryController(api: accountApi, session: session, pageSize: historyPageSize);
    return AppServices(accountApi: accountApi, session: session, analysis: analysis, history: history, locale: locale);
  }
}
