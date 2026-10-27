import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import 'api_errors.dart';
import 'models.dart';

export 'api_errors.dart' show ApiFailure, FailureKind;

abstract class PredictionApi {
  /// Avec [accessToken], l'analyse est ajoutée à l'historique de l'utilisateur côté serveur.
  Future<Prediction> predict(PickedImage image, {String? accessToken});
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

  /// Type MIME déduit de l'extension ; null si le format n'est pas JPEG/PNG.
  static String? contentTypeFor(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.png')) return 'image/png';
    return null;
  }

  @override
  Future<Prediction> predict(PickedImage image, {String? accessToken}) async {
    final contentType = contentTypeFor(image.name);
    if (contentType == null) throw const ApiFailure(FailureKind.unsupportedFormat);

    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/api/v1/predictions'))
      ..files.add(http.MultipartFile.fromBytes(
        'image',
        image.bytes,
        filename: image.name,
        contentType: MediaType.parse(contentType),
      ));
    if (accessToken != null) request.headers['Authorization'] = 'Bearer $accessToken';

    final response = await sendGuarded(
      () async => http.Response.fromStream(await _client.send(request)),
      timeout,
    );
    if (response.statusCode == 200) return decodeBody(response, Prediction.fromJson);
    throw failureFromResponse(response);
  }

  void close() => _client.close();
}
