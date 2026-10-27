import 'package:flutter/foundation.dart';

import '../data/account_api.dart';
import '../data/api_errors.dart';
import '../data/models.dart';
import 'session_controller.dart';

enum HistoryStatus { idle, loading, loaded, failure }

/// Liste paginée de l'historique de l'utilisateur connecté.
class HistoryController extends ChangeNotifier {
  HistoryController({required AccountApi api, required SessionController session, this.pageSize = 20})
      : _api = api,
        _session = session;

  final AccountApi _api;
  final SessionController _session;
  final int pageSize;

  HistoryStatus _status = HistoryStatus.idle;
  final List<AnalysisRecord> _items = [];
  int _total = 0;
  bool _loadingMore = false;
  ApiFailure? _failure;

  HistoryStatus get status => _status;
  List<AnalysisRecord> get items => List.unmodifiable(_items);
  int get total => _total;
  bool get isLoadingMore => _loadingMore;
  bool get hasMore => _items.length < _total;
  ApiFailure? get failure => _failure;

  /// Recharge la première page (ouverture de l'écran, tirer pour actualiser, réessai).
  Future<void> refresh() async {
    if (_status == HistoryStatus.loading) return;
    _failure = null;
    _status = HistoryStatus.loading;
    notifyListeners();
    await _run(() async {
      final page = await _api.listAnalyses(_token(), limit: pageSize, offset: 0);
      _items
        ..clear()
        ..addAll(page.items);
      _total = page.total;
      _status = HistoryStatus.loaded;
    }, onFailure: () => _status = HistoryStatus.failure);
  }

  Future<void> loadMore() async {
    if (_status != HistoryStatus.loaded || _loadingMore || !hasMore) return;
    _loadingMore = true;
    notifyListeners();
    await _run(() async {
      final page = await _api.listAnalyses(_token(), limit: pageSize, offset: _items.length);
      _items.addAll(page.items);
      _total = page.total;
    }, onFailure: () {});
    _loadingMore = false;
    notifyListeners();
  }

  /// Supprime côté serveur puis retire l'élément de la liste. Retourne vrai en cas de succès.
  Future<bool> delete(String id) async {
    var deleted = false;
    await _run(() async {
      try {
        await _api.deleteAnalysis(_token(), id);
      } on ApiFailure catch (failure) {
        if (failure.kind != FailureKind.notFound) rethrow; // déjà supprimée ailleurs : même résultat
      }
      final before = _items.length;
      _items.removeWhere((item) => item.id == id);
      if (_items.length < before && _total > 0) _total -= 1;
      deleted = true;
    }, onFailure: () {});
    notifyListeners();
    return deleted;
  }

  void clear() {
    _items.clear();
    _total = 0;
    _status = HistoryStatus.idle;
    _failure = null;
    notifyListeners();
  }

  String _token() {
    final token = _session.accessToken;
    if (token == null) throw const ApiFailure(FailureKind.unauthorized);
    return token;
  }

  Future<void> _run(Future<void> Function() action, {required VoidCallback onFailure}) async {
    try {
      await action();
    } on ApiFailure catch (failure) {
      _failure = failure;
      onFailure();
      if (failure.kind == FailureKind.unauthorized) await _session.expire();
    } catch (_) {
      _failure = const ApiFailure(FailureKind.unknown);
      onFailure();
    }
    notifyListeners();
  }
}
