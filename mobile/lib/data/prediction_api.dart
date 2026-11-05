import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import 'api_errors.dart';
import 'models.dart';

export 'api_errors.dart' show ApiFailure, FailureKind;

abstract class PredictionApi {
  /// Avec [accessToken], l'analyse est ajoutée à l'historique de l'utilisateur côté serveur.
  Future<Prediction> predict(PickedImage image, {String? accessToken});
}

abstract class ExportApi {
  /// Image annotée (résultat + filigrane optionnel). Le serveur refait l'inférence sur l'image envoyée,
  /// ne stocke rien et renvoie un PNG.
  Future<ExportedImage> exportAnnotated(PickedImage image, {bool watermark = true});
}

class HttpPredictionApi implements PredictionApi, ExportApi {
  HttpPredictionApi({
    required this.baseUrl,
    http.Client? client,
    this.timeout = const Duration(seconds: 30),
  }) : _client = client ?? http.Client();

  final String baseUrl;
  final Duration timeout;
  final http.Client _client;

  /// Type MIME déduit de l'extension ; null si le format n'est pas JPEG/PNG.
  static String? contentTypeFor(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.png')) return 'image/png';
    return null;
  }

  http.MultipartRequest _multipartRequest(String path, PickedImage image, {Map<String, String>? query}) {
    final contentType = contentTypeFor(image.name);
    if (contentType == null) throw const ApiFailure(FailureKind.unsupportedFormat);
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);
    return http.MultipartRequest('POST', uri)
      ..files.add(http.MultipartFile.fromBytes(
        'image',
        image.bytes,
        filename: image.name,
        contentType: MediaType.parse(contentType),
      ));
  }

  @override
  Future<Prediction> predict(PickedImage image, {String? accessToken}) async {
    final request = _multipartRequest('/api/v1/predictions', image);
    if (accessToken != null) request.headers['Authorization'] = 'Bearer $accessToken';

    final response = await sendGuarded(
      () async => http.Response.fromStream(await _client.send(request)),
      timeout,
    );
    if (response.statusCode == 200) return decodeBody(response, Prediction.fromJson);
    throw failureFromResponse(response);
  }

  static const _pngSignature = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];

  @override
  Future<ExportedImage> exportAnnotated(PickedImage image, {bool watermark = true}) async {
    final request = _multipartRequest(
      '/api/v1/predictions/annotated-image',
      image,
      query: {'watermark': watermark ? 'true' : 'false'},
    );
    final response = await sendGuarded(
      () async => http.Response.fromStream(await _client.send(request)),
      timeout,
    );
    if (response.statusCode != 200) throw failureFromResponse(response);

    final bytes = response.bodyBytes;
    final isPng = bytes.length > _pngSignature.length &&
        response.headers['content-type']?.startsWith('image/png') == true &&
        List.generate(_pngSignature.length, (i) => bytes[i] == _pngSignature[i]).every((ok) => ok);
    if (!isPng) throw ApiFailure(FailureKind.invalidResponse, statusCode: response.statusCode);
    return ExportedImage(
      bytes: bytes,
      predictionId: response.headers['x-prediction-id'],
      watermarkApplied: response.headers['x-watermark'] == 'applied',
    );
  }

  void close() => _client.close();
}
