import 'dart:async';
import 'dart:convert';
import 'dart:io' show SocketException;

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import 'models.dart';

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
  unknown,
}

class ApiFailure implements Exception {
  const ApiFailure(this.kind, {this.statusCode, this.code});

  final FailureKind kind;
  final int? statusCode;

  /// Code d'erreur de l'API (`{"error": {"code": ...}}`), s'il est présent.
  final String? code;

  /// Un nouvel essai a une chance de réussir sans changer de photo.
  bool get isRetryable => switch (kind) {
        FailureKind.network ||
        FailureKind.timeout ||
        FailureKind.modelUnavailable ||
        FailureKind.server ||
        FailureKind.invalidResponse ||
        FailureKind.unknown =>
          true,
        _ => false,
      };

  @override
  String toString() => 'ApiFailure($kind, status: $statusCode, code: $code)';
}

abstract class PredictionApi {
  Future<Prediction> predict(PickedImage image);
}

class HttpPredictionApi implements PredictionApi {
  HttpPredictionApi({
    required this.baseUrl,
    http.Client? client,
    this.timeout = const Duration(seconds: 30),
  }) : _client = client ?? http.Client();

  final String baseUrl;
  final Duration timeout;
  final http.Client _client;

  static const _codeToKind = <String, FailureKind>{
    'file_too_large': FailureKind.fileTooLarge,
    'unsupported_media_type': FailureKind.unsupportedFormat,
    'invalid_image': FailureKind.invalidImage,
    'empty_file': FailureKind.emptyFile,
    'image_too_small': FailureKind.imageTooSmall,
    'image_dimensions_too_large': FailureKind.imageTooLarge,
    'model_unavailable': FailureKind.modelUnavailable,
    'internal_error': FailureKind.server,
  };

  /// Type MIME déduit de l'extension ; null si le format n'est pas JPEG/PNG.
  static String? contentTypeFor(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.png')) return 'image/png';
    return null;
  }

  @override
  Future<Prediction> predict(PickedImage image) async {
    final contentType = contentTypeFor(image.name);
    if (contentType == null) throw const ApiFailure(FailureKind.unsupportedFormat);

    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/api/v1/predictions'))
      ..files.add(http.MultipartFile.fromBytes(
        'image',
        image.bytes,
        filename: image.name,
        contentType: MediaType.parse(contentType),
      ));

    final http.Response response;
    try {
      final streamed = await _client.send(request).timeout(timeout);
      response = await http.Response.fromStream(streamed).timeout(timeout);
    } on TimeoutException {
      throw const ApiFailure(FailureKind.timeout);
    } on SocketException {
      throw const ApiFailure(FailureKind.network);
    } on http.ClientException {
      throw const ApiFailure(FailureKind.network);
    }

    if (response.statusCode == 200) {
      try {
        return Prediction.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
      } on FormatException {
        throw ApiFailure(FailureKind.invalidResponse, statusCode: response.statusCode);
      } on TypeError {
        throw ApiFailure(FailureKind.invalidResponse, statusCode: response.statusCode);
      }
    }
    throw _failureFromError(response);
  }

  ApiFailure _failureFromError(http.Response response) {
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
          413 => FailureKind.fileTooLarge,
          415 => FailureKind.unsupportedFormat,
          503 => FailureKind.modelUnavailable,
          >= 500 => FailureKind.server,
          _ => FailureKind.unknown,
        };
    return ApiFailure(kind, statusCode: status, code: code);
  }

  void close() => _client.close();
}
