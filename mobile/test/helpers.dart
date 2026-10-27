import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:agriscan_mobile/data/account_api.dart';
import 'package:agriscan_mobile/data/models.dart';
import 'package:agriscan_mobile/data/token_store.dart';
import 'package:agriscan_mobile/data/prediction_api.dart';
import 'package:agriscan_mobile/logic/image_source_service.dart';

/// PNG valide de 1×1 pixel (pour Image.memory dans les tests).
final Uint8List tinyPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
);

const kClasses = [
  'Tomato___Bacterial_spot',
  'Tomato___Early_blight',
  'Tomato___Late_blight',
  'Tomato___Leaf_Mold',
  'Tomato___Septoria_leaf_spot',
  'Tomato___Spider_mites Two-spotted_spider_mite',
  'Tomato___Target_Spot',
  'Tomato___Tomato_Yellow_Leaf_Curl_Virus',
  'Tomato___Tomato_mosaic_virus',
  'Tomato___healthy',
];

Map<String, dynamic> predictionJson({
  String status = 'prediction_available',
  String? predictedClass = 'Tomato___Late_blight',
  double confidence = 0.91,
}) {
  final scores = {for (final c in kClasses) c: 0.01};
  scores['Tomato___Late_blight'] = 0.91;
  scores['Tomato___Early_blight'] = 0.05;
  scores['Tomato___Target_Spot'] = 0.03;
  return {
    'prediction_id': '3f2b8c1e-0000-4000-8000-000000000001',
    'status': status,
    'predicted_class': predictedClass,
    'confidence': confidence,
    'scores': scores,
    'model_version': 'mobilenetv2_classifier-10a733ad75f0',
    'disclaimer': 'Résultat de dépistage par IA, pas un diagnostic confirmé.',
  };
}

Prediction samplePrediction({bool uncertain = false}) => Prediction.fromJson(
      uncertain
          ? predictionJson(status: 'uncertain', predictedClass: null, confidence: 0.55)
          : predictionJson(),
    );

PickedImage sampleImage({String name = 'leaf.jpg'}) => PickedImage(bytes: tinyPng, name: name);

/// Source d'image de test : renvoie [image] (ou null pour simuler une annulation).
class FakeImageSource implements ImageSourceService {
  FakeImageSource({this.image, this.failure});

  PickedImage? image;
  ApiFailure? failure;
  final List<ImageOrigin> requests = [];

  @override
  Future<PickedImage?> pick(ImageOrigin origin) async {
    requests.add(origin);
    if (failure != null) throw failure!;
    return image;
  }
}

/// API de test pilotable : résultat immédiat, échec, ou réponse différée via [completer].
class FakePredictionApi implements PredictionApi {
  FakePredictionApi({this.result, this.failure, this.completer});

  Prediction? result;
  ApiFailure? failure;
  Completer<Prediction>? completer;
  int calls = 0;
  final List<String?> tokensSeen = [];

  @override
  Future<Prediction> predict(PickedImage image, {String? accessToken}) async {
    calls++;
    tokensSeen.add(accessToken);
    if (completer != null) return completer!.future;
    if (failure != null) throw failure!;
    return result!;
  }
}

AnalysisRecord sampleRecord(
  String id, {
  bool uncertain = false,
  String? predictedClass = 'Tomato___Late_blight',
  DateTime? createdAt,
}) =>
    AnalysisRecord(
      id: id,
      status: uncertain ? PredictionStatus.uncertain : PredictionStatus.predictionAvailable,
      predictedClass: uncertain ? null : predictedClass,
      confidenceScore: uncertain ? 0.55 : 0.91,
      scores: {for (final c in kClasses) c: 0.01}..['Tomato___Late_blight'] = 0.91,
      modelVersion: 'mobilenetv2_classifier-10a733ad75f0',
      createdAt: createdAt ?? DateTime(2026, 10, 27, 14, 30),
    );

/// Stockage de jeton en mémoire (le vrai stockage chiffré nécessite un appareil).
class MemoryTokenStore implements TokenStore {
  MemoryTokenStore([this.value]);

  String? value;
  int writes = 0;
  int clears = 0;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String token) async {
    writes++;
    value = token;
  }

  @override
  Future<void> clear() async {
    clears++;
    value = null;
  }
}

/// API de comptes pilotable. Le jeton émis est `tok-<email>` ; tout autre jeton est refusé (401).
class FakeAccountApi implements AccountApi {
  FakeAccountApi({List<AnalysisRecord>? records}) : records = records ?? [];

  final List<AnalysisRecord> records;
  final List<String> calls = [];
  final Set<String> revokedTokens = {};
  ApiFailure? registerFailure;
  ApiFailure? loginFailure;
  ApiFailure? meFailure;
  ApiFailure? listFailure;
  ApiFailure? getFailure;
  ApiFailure? deleteFailure;
  ApiFailure? deleteAccountFailure;
  Completer<void>? loginGate;
  Completer<void>? getGate;

  void _checkToken(String token) {
    if (!token.startsWith('tok-') || revokedTokens.contains(token)) {
      throw const ApiFailure(FailureKind.unauthorized, statusCode: 401);
    }
  }

  @override
  Future<UserProfile> register(String email, String password) async {
    calls.add('register:$email');
    if (registerFailure != null) throw registerFailure!;
    return UserProfile(id: 'u-1', email: email, role: 'user');
  }

  @override
  Future<AccessToken> login(String email, String password) async {
    calls.add('login:$email');
    if (loginGate != null) await loginGate!.future;
    if (loginFailure != null) throw loginFailure!;
    return AccessToken(value: 'tok-$email', expiresInSeconds: 1800);
  }

  @override
  Future<UserProfile> me(String token) async {
    calls.add('me');
    if (meFailure != null) throw meFailure!;
    _checkToken(token);
    return UserProfile(id: 'u-1', email: token.substring(4), role: 'user');
  }

  @override
  Future<void> deleteAccount(String token) async {
    calls.add('deleteAccount');
    if (deleteAccountFailure != null) throw deleteAccountFailure!;
    _checkToken(token);
    records.clear();
  }

  @override
  Future<AnalysisPage> listAnalyses(String token, {int limit = 20, int offset = 0}) async {
    calls.add('list:$limit:$offset');
    if (listFailure != null) throw listFailure!;
    _checkToken(token);
    final page = records.skip(offset).take(limit).toList();
    return AnalysisPage(items: page, total: records.length, offset: offset);
  }

  @override
  Future<AnalysisRecord> getAnalysis(String token, String id) async {
    calls.add('get:$id');
    if (getGate != null) await getGate!.future;
    if (getFailure != null) throw getFailure!;
    _checkToken(token);
    return records.firstWhere((r) => r.id == id, orElse: () => throw const ApiFailure(FailureKind.notFound));
  }

  @override
  Future<void> deleteAnalysis(String token, String id) async {
    calls.add('delete:$id');
    if (deleteFailure != null) throw deleteFailure!;
    _checkToken(token);
    final before = records.length;
    records.removeWhere((r) => r.id == id);
    if (records.length == before) throw const ApiFailure(FailureKind.notFound);
  }
}
