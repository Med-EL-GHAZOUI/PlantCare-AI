import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Stockage du jeton d'accès. Le jeton ne doit jamais être écrit dans les journaux,
/// les préférences non chiffrées ni une URL.
abstract class TokenStore {
  Future<String?> read();
  Future<void> write(String token);
  Future<void> clear();
}

/// Keystore Android (chiffré) / Keychain iOS via flutter_secure_storage.
class SecureTokenStore implements TokenStore {
  SecureTokenStore([FlutterSecureStorage? storage]) : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'agriscan_access_token';
  final FlutterSecureStorage _storage;

  @override
  Future<String?> read() async {
    try {
      return await _storage.read(key: _key);
    } on Exception {
      return null; // stockage illisible (clé invalidée, restauration) : l'utilisateur se reconnectera
    }
  }

  @override
  Future<void> write(String token) => _storage.write(key: _key, value: token);

  @override
  Future<void> clear() async {
    try {
      await _storage.delete(key: _key);
    } on Exception {
      // Rien à effacer si le stockage est inaccessible.
    }
  }
}
