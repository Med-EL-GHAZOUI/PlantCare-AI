import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../data/models.dart';
import '../data/prediction_api.dart';
import 'image_source_service.dart';

enum AnalysisStatus { idle, loading, success, failure }

/// Orchestre : choix de l'image, validation locale, appel API, état affiché.
/// Aucune dépendance à l'interface : testable sans widget.
class AnalysisController extends ChangeNotifier {
  AnalysisController({
    required PredictionApi api,
    required ImageSourceService imageSource,
    this.maxUploadBytes = AppConfig.maxUploadBytes,
  })  : _api = api,
        _imageSource = imageSource;

  final PredictionApi _api;
  final ImageSourceService _imageSource;
  final int maxUploadBytes;

  AnalysisStatus _status = AnalysisStatus.idle;
  PickedImage? _image;
  Prediction? _prediction;
  ApiFailure? _failure;

  AnalysisStatus get status => _status;
  PickedImage? get image => _image;
  Prediction? get prediction => _prediction;
  ApiFailure? get failure => _failure;
  bool get isLoading => _status == AnalysisStatus.loading;

  /// Choisit une image puis l'analyse. Sans effet si une analyse est déjà en cours
  /// ou si l'utilisateur annule la sélection.
  Future<void> pickAndAnalyze(ImageOrigin origin) async {
    if (isLoading) return;
    final PickedImage? picked;
    try {
      picked = await _imageSource.pick(origin);
    } on ApiFailure catch (failure) {
      _fail(failure);
      return;
    }
    if (picked == null) return;
    await _analyze(picked);
  }

  /// Relance l'analyse de la dernière image (après un échec réseau, par exemple).
  Future<void> retry() async {
    final image = _image;
    if (image == null || isLoading) return;
    await _analyze(image);
  }

  void reset() {
    if (isLoading) return;
    _status = AnalysisStatus.idle;
    _image = null;
    _prediction = null;
    _failure = null;
    notifyListeners();
  }

  Future<void> _analyze(PickedImage image) async {
    _image = image;
    _prediction = null;
    _failure = null;

    if (image.bytes.isEmpty) return _fail(const ApiFailure(FailureKind.emptyFile));
    if (image.bytes.length > maxUploadBytes) return _fail(const ApiFailure(FailureKind.fileTooLarge));
    if (HttpPredictionApi.contentTypeFor(image.name) == null) {
      return _fail(const ApiFailure(FailureKind.unsupportedFormat));
    }

    _status = AnalysisStatus.loading;
    notifyListeners();
    try {
      _prediction = await _api.predict(image);
      _status = AnalysisStatus.success;
      notifyListeners();
    } on ApiFailure catch (failure) {
      _fail(failure);
    } catch (_) {
      // Toute erreur inattendue (y compris StateError/TypeError) doit sortir du chargement.
      _fail(const ApiFailure(FailureKind.unknown));
    }
  }

  void _fail(ApiFailure failure) {
    _status = AnalysisStatus.failure;
    _failure = failure;
    notifyListeners();
  }
}
