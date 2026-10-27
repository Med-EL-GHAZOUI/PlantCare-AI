import 'dart:async';
import 'dart:convert';
import 'dart:io' show SocketException;

import 'package:http/http.dart' as http;

/// Nature d'un échec, indépendante de la langue ; l'interface choisit le message traduit.
enum FailureKind {
  network,
  timeout,
  fileTooLarge,
  unsupportedFormat,
  invalidImage,
  emptyFile,
  imageTooSmall,
  imageTooLarge,
  modelUnavailable,
  server,
  invalidResponse,
  pickFailed,
  unauthorized,
  invalidCredentials,
  emailTaken,
  tooManyAttempts,
  notFound,
  invalidInput,
  accountsUnavailable,
  unknown,
}

class ApiFailure implements Exception {
  const ApiFailure(this.kind, {this.statusCode, this.code});

  final FailureKind kind;
  final int? statusCode;

  /// Code d'erreur de l'API (`{"error": {"code": ...}}`), s'il est présent.
  final String? code;

  /// Un nouvel essai a une chance de réussir sans rien changer.
  bool get isRetryable => switch (kind) {
        FailureKind.network ||
        FailureKind.timeout ||
        FailureKind.modelUnavailable ||
        FailureKind.server ||
        FailureKind.invalidResponse ||
        FailureKind.accountsUnavailable ||
        FailureKind.unauthorized ||
        FailureKind.unknown =>
          true,
        _ => false,
      };

  @override
  String toString() => 'ApiFailure($kind, status: $statusCode, code: $code)';
}

const _codeToKind = <String, FailureKind>{
  'file_too_large': FailureKind.fileTooLarge,
  'unsupported_media_type': FailureKind.unsupportedFormat,
  'invalid_image': FailureKind.invalidImage,
  'empty_file': FailureKind.emptyFile,
  'image_too_small': FailureKind.imageTooSmall,
  'image_dimensions_too_large': FailureKind.imageTooLarge,
  'model_unavailable': FailureKind.modelUnavailable,
  'internal_error': FailureKind.server,
  'not_authenticated': FailureKind.unauthorized,
  'invalid_credentials': FailureKind.invalidCredentials,
  'email_already_registered': FailureKind.emailTaken,
  'too_many_attempts': FailureKind.tooManyAttempts,
  'not_found': FailureKind.notFound,
  'invalid_request': FailureKind.invalidInput,
  'database_unavailable': FailureKind.accountsUnavailable,
  'auth_unavailable': FailureKind.accountsUnavailable,
};

/// Traduit une réponse d'erreur de l'API (`{"error": {"code", "message"}}`) en [ApiFailure].
ApiFailure failureFromResponse(http.Response response) {
  String? code;
  try {
    final body = jsonDecode(utf8.decode(response.bodyBytes));
    if (body is Map<String, dynamic> && body['error'] is Map<String, dynamic>) {
      code = (body['error'] as Map<String, dynamic>)['code'] as String?;
    }
  } on FormatException {
    code = null;
  }
  final status = response.statusCode;
  final kind = _codeToKind[code] ??
      switch (status) {
        401 => FailureKind.unauthorized,
        404 => FailureKind.notFound,
        413 => FailureKind.fileTooLarge,
        415 => FailureKind.unsupportedFormat,
        429 => FailureKind.tooManyAttempts,
        503 => FailureKind.modelUnavailable,
        >= 500 => FailureKind.server,
        _ => FailureKind.unknown,
      };
  return ApiFailure(kind, statusCode: status, code: code);
}

/// Exécute une requête et traduit les échecs de transport (réseau coupé, délai dépassé).
Future<http.Response> sendGuarded(Future<http.Response> Function() action, Duration timeout) async {
  try {
    return await action().timeout(timeout);
  } on TimeoutException {
    throw const ApiFailure(FailureKind.timeout);
  } on SocketException {
    throw const ApiFailure(FailureKind.network);
  } on http.ClientException {
    throw const ApiFailure(FailureKind.network);
  }
}

/// Décode un corps JSON UTF-8 ; toute anomalie devient `invalidResponse`.
T decodeBody<T>(http.Response response, T Function(Object? json) parse) {
  try {
    return parse(jsonDecode(utf8.decode(response.bodyBytes)));
  } on FormatException {
    throw ApiFailure(FailureKind.invalidResponse, statusCode: response.statusCode);
  } on TypeError {
    throw ApiFailure(FailureKind.invalidResponse, statusCode: response.statusCode);
  }
}
