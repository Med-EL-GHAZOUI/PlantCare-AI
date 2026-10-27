import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_errors.dart';
import 'models.dart';

/// Comptes et historique (`/api/v1/auth/*`, `/api/v1/analyses*`).
abstract class AccountApi {
  Future<UserProfile> register(String email, String password);
  Future<AccessToken> login(String email, String password);
  Future<UserProfile> me(String token);
  Future<void> deleteAccount(String token);
  Future<AnalysisPage> listAnalyses(String token, {int limit = 20, int offset = 0});
  Future<AnalysisRecord> getAnalysis(String token, String id);
  Future<void> deleteAnalysis(String token, String id);
}

class HttpAccountApi implements AccountApi {
  HttpAccountApi({
    required this.baseUrl,
    http.Client? client,
    this.timeout = const Duration(seconds: 30),
  }) : _client = client ?? http.Client();

  final String baseUrl;
  final Duration timeout;
  final http.Client _client;

  Future<http.Response> _send(
    String method,
    String path, {
    String? token,
    Map<String, dynamic>? json,
    Map<String, String>? query,
  }) {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);
    final request = http.Request(method, uri);
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    if (json != null) {
      request.headers['Content-Type'] = 'application/json; charset=utf-8';
      request.body = jsonEncode(json);
    }
    return sendGuarded(() async => http.Response.fromStream(await _client.send(request)), timeout);
  }

  /// Retourne la réponse si son statut est [expected], sinon lève l'échec correspondant.
  http.Response _expect(http.Response response, int expected) {
    if (response.statusCode != expected) throw failureFromResponse(response);
    return response;
  }

  @override
  Future<UserProfile> register(String email, String password) async {
    final response = await _send('POST', '/api/v1/auth/register', json: {'email': email, 'password': password});
    return decodeBody(_expect(response, 201), UserProfile.fromJson);
  }

  @override
  Future<AccessToken> login(String email, String password) async {
    final response = await _send('POST', '/api/v1/auth/login', json: {'email': email, 'password': password});
    return decodeBody(_expect(response, 200), AccessToken.fromJson);
  }

  @override
  Future<UserProfile> me(String token) async {
    final response = await _send('GET', '/api/v1/auth/me', token: token);
    return decodeBody(_expect(response, 200), UserProfile.fromJson);
  }

  @override
  Future<void> deleteAccount(String token) async {
    _expect(await _send('DELETE', '/api/v1/auth/me', token: token), 204);
  }

  @override
  Future<AnalysisPage> listAnalyses(String token, {int limit = 20, int offset = 0}) async {
    final response = await _send('GET', '/api/v1/analyses',
        token: token, query: {'limit': '$limit', 'offset': '$offset'});
    return decodeBody(_expect(response, 200), AnalysisPage.fromJson);
  }

  @override
  Future<AnalysisRecord> getAnalysis(String token, String id) async {
    final response = await _send('GET', '/api/v1/analyses/${Uri.encodeComponent(id)}', token: token);
    return decodeBody(_expect(response, 200), AnalysisRecord.fromJson);
  }

  @override
  Future<void> deleteAnalysis(String token, String id) async {
    _expect(await _send('DELETE', '/api/v1/analyses/${Uri.encodeComponent(id)}', token: token), 204);
  }

  void close() => _client.close();
}
