import 'package:flutter/foundation.dart';

import '../data/account_api.dart';
import '../data/api_errors.dart';
import '../data/models.dart';
import '../data/token_store.dart';

enum SessionStatus { restoring, signedOut, busy, signedIn }

/// Connexion, inscription, déconnexion et jeton. Le jeton n'est conservé qu'en mémoire
/// et dans le [TokenStore] sécurisé.
class SessionController extends ChangeNotifier {
  SessionController({required AccountApi api, required TokenStore tokenStore})
      : _api = api,
        _tokenStore = tokenStore;

  final AccountApi _api;
  final TokenStore _tokenStore;

  SessionStatus _status = SessionStatus.restoring;
  String? _token;
  UserProfile? _user;
  ApiFailure? _failure;
  bool _expired = false;

  SessionStatus get status => _status;
  UserProfile? get user => _user;
  ApiFailure? get failure => _failure;

  /// Vrai quand la session précédente a expiré ou a été rejetée par le serveur.
  bool get sessionExpired => _expired;
  bool get isSignedIn => _status == SessionStatus.signedIn;
  bool get isBusy => _status == SessionStatus.busy;
  String? get accessToken => _token;

  /// Au démarrage : reprend la session si un jeton valide est stocké.
  /// Hors ligne, le jeton est conservé (la session reste ouverte, profil inconnu).
  Future<void> restore() async {
    final stored = await _tokenStore.read();
    if (stored == null) return _set(SessionStatus.signedOut);
    try {
      _user = await _api.me(stored);
      _token = stored;
      _set(SessionStatus.signedIn);
    } on ApiFailure catch (failure) {
      if (failure.kind == FailureKind.unauthorized) {
        await _tokenStore.clear();
        _expired = true;
        _set(SessionStatus.signedOut);
      } else {
        _token = stored;
        _set(SessionStatus.signedIn);
      }
    }
  }

  Future<bool> signIn(String email, String password) => _authenticate(email, password, register: false);

  /// Crée le compte puis ouvre la session.
  Future<bool> register(String email, String password) => _authenticate(email, password, register: true);

  Future<bool> _authenticate(String email, String password, {required bool register}) async {
    if (isBusy) return false;
    _failure = null;
    _expired = false;
    _set(SessionStatus.busy);
    try {
      if (register) await _api.register(email, password);
      final token = await _api.login(email, password);
      await _tokenStore.write(token.value);
      _token = token.value;
      _user = await _api.me(token.value);
      _set(SessionStatus.signedIn);
      return true;
    } on ApiFailure catch (failure) {
      _failure = failure;
      _token = null;
      _user = null;
      _set(SessionStatus.signedOut);
      return false;
    }
  }

  Future<void> signOut() async {
    await _tokenStore.clear();
    _clear();
    _set(SessionStatus.signedOut);
  }

  /// Supprime le compte et ses analyses côté serveur, puis ferme la session.
  Future<bool> deleteAccount() async {
    final token = _token;
    if (token == null || isBusy) return false;
    _failure = null;
    _set(SessionStatus.busy);
    try {
      await _api.deleteAccount(token);
    } on ApiFailure catch (failure) {
      if (failure.kind != FailureKind.unauthorized) {
        _failure = failure;
        _set(SessionStatus.signedIn);
        return false;
      }
    }
    await signOut();
    return true;
  }

  /// Appelé quand le serveur rejette le jeton (401) : on oublie la session.
  Future<void> expire() async {
    if (_token == null) return;
    await _tokenStore.clear();
    _clear();
    _expired = true;
    _set(SessionStatus.signedOut);
  }

  void clearFailure() {
    if (_failure == null && !_expired) return;
    _failure = null;
    _expired = false;
    notifyListeners();
  }

  void _clear() {
    _token = null;
    _user = null;
    _failure = null;
    _expired = false;
  }

  void _set(SessionStatus status) {
    _status = status;
    notifyListeners();
  }
}
