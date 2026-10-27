import 'package:flutter/foundation.dart';

import '../data/account_api.dart';
import '../data/api_errors.dart';
import '../data/models.dart';
import 'session_controller.dart';

enum DetailStatus { loading, loaded, failure, deleted }

/// Détail d'une analyse de l'historique (rechargée depuis le serveur) et sa suppression.
class DetailController extends ChangeNotifier {
  DetailController({
    required AccountApi api,
    required SessionController session,
    required this.analysisId,
    AnalysisRecord? initial,
  })  : _api = api,
        _session = session,
        _record = initial,
        _status = initial == null ? DetailStatus.loading : DetailStatus.loaded;

  final AccountApi _api;
  final SessionController _session;
  final String analysisId;

  DetailStatus _status;
  AnalysisRecord? _record;
  ApiFailure? _failure;
  bool _loading = false;
  bool _deleting = false;

  DetailStatus get status => _status;
  AnalysisRecord? get record => _record;
  ApiFailure? get failure => _failure;
  bool get isLoading => _loading;

  /// Vrai pendant la suppression ; un rechargement en arrière-plan ne bloque pas la suppression.
  bool get isDeleting => _deleting;

  Future<void> load() async {
    if (_loading) return;
    _loading = true;
    _failure = null;
    if (_record == null) _status = DetailStatus.loading;
    notifyListeners();
    try {
      final record = await _api.getAnalysis(_token(), analysisId);
      if (_status != DetailStatus.deleted) {
        _record = record;
        _status = DetailStatus.loaded;
      }
    } on ApiFailure catch (failure) {
      if (_status != DetailStatus.deleted) await _handle(failure);
    }
    _loading = false;
    notifyListeners();
  }

  Future<bool> delete() async {
    if (_deleting) return false;
    _deleting = true;
    _failure = null;
    notifyListeners();
    var ok = false;
    try {
      await _api.deleteAnalysis(_token(), analysisId);
      _status = DetailStatus.deleted;
      ok = true;
    } on ApiFailure catch (failure) {
      if (failure.kind == FailureKind.notFound) {
        _status = DetailStatus.deleted;
        ok = true;
      } else {
        await _handle(failure, keepRecord: true);
      }
    }
    _deleting = false;
    notifyListeners();
    return ok;
  }

  Future<void> _handle(ApiFailure failure, {bool keepRecord = false}) async {
    _failure = failure;
    if (!keepRecord || _record == null) _status = DetailStatus.failure;
    if (failure.kind == FailureKind.unauthorized) await _session.expire();
  }

  String _token() {
    final token = _session.accessToken;
    if (token == null) throw const ApiFailure(FailureKind.unauthorized);
    return token;
  }
}
