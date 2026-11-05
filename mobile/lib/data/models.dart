import 'dart:typed_data';

/// Image choisie par l'utilisateur (octets en mémoire + nom d'origine).
class PickedImage {
  const PickedImage({required this.bytes, required this.name});

  final Uint8List bytes;
  final String name;
}

enum PredictionStatus { predictionAvailable, uncertain }

/// Réponse de `POST /api/v1/predictions`.
class Prediction {
  const Prediction({
    required this.id,
    required this.status,
    required this.predictedClass,
    required this.confidence,
    required this.scores,
    required this.modelVersion,
  });

  final String id;
  final PredictionStatus status;

  /// Étiquette brute du modèle (ex. `Tomato___Late_blight`) ; null si le résultat est incertain.
  final String? predictedClass;

  /// Score softmax maximal du modèle. Ce n'est PAS une probabilité calibrée.
  final double confidence;
  final Map<String, double> scores;
  final String modelVersion;

  bool get isUncertain => status == PredictionStatus.uncertain;

  /// Les [count] classes les mieux notées, par score décroissant.
  List<MapEntry<String, double>> topScores([int count = 3]) {
    final entries = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.take(count).toList();
  }

  /// Lève une [FormatException] si la réponse ne respecte pas le contrat de l'API.
  factory Prediction.fromJson(Object? json) {
    if (json is! Map<String, dynamic>) {
      throw const FormatException('Réponse JSON inattendue');
    }
    final status = switch (json['status']) {
      'prediction_available' => PredictionStatus.predictionAvailable,
      'uncertain' => PredictionStatus.uncertain,
      _ => throw FormatException('Statut inconnu : ${json['status']}'),
    };
    final rawScores = json['scores'];
    if (rawScores is! Map<String, dynamic> || rawScores.isEmpty) {
      throw const FormatException('Scores absents');
    }
    final predicted = json['predicted_class'];
    if (status == PredictionStatus.predictionAvailable && predicted is! String) {
      throw const FormatException('Classe prédite absente');
    }
    final confidence = json['confidence'];
    if (confidence is! num) throw const FormatException('Confiance absente');
    return Prediction(
      id: json['prediction_id'] as String,
      status: status,
      predictedClass: predicted as String?,
      confidence: confidence.toDouble(),
      scores: rawScores.map((key, value) => MapEntry(key, (value as num).toDouble())),
      modelVersion: json['model_version'] as String,
    );
  }
}

/// Profil renvoyé par `/api/v1/auth/register` et `/api/v1/auth/me`.
class UserProfile {
  const UserProfile({required this.id, required this.email, required this.role});

  final String id;
  final String email;
  final String role;

  factory UserProfile.fromJson(Object? json) {
    if (json is! Map<String, dynamic>) throw const FormatException('Profil inattendu');
    return UserProfile(
      id: json['id'] as String,
      email: json['email'] as String,
      role: json['role'] as String,
    );
  }
}

/// Jeton d'accès renvoyé par `/api/v1/auth/login`.
class AccessToken {
  const AccessToken({required this.value, required this.expiresInSeconds});

  final String value;
  final int expiresInSeconds;

  factory AccessToken.fromJson(Object? json) {
    if (json is! Map<String, dynamic>) throw const FormatException('Jeton inattendu');
    final token = json['access_token'];
    if (token is! String || token.isEmpty) throw const FormatException('Jeton absent');
    return AccessToken(value: token, expiresInSeconds: (json['expires_in'] as num).toInt());
  }
}

/// Analyse conservée dans l'historique de l'utilisateur (jamais l'image).
class AnalysisRecord {
  const AnalysisRecord({
    required this.id,
    required this.status,
    required this.predictedClass,
    required this.confidenceScore,
    required this.scores,
    required this.modelVersion,
    required this.createdAt,
  });

  final String id;
  final PredictionStatus status;
  final String? predictedClass;
  final double? confidenceScore;
  final Map<String, double> scores;
  final String modelVersion;
  final DateTime createdAt;

  bool get isUncertain => status == PredictionStatus.uncertain;

  /// Vue « résultat » identique à celle d'une analyse fraîche.
  Prediction toPrediction() => Prediction(
        id: id,
        status: status,
        predictedClass: predictedClass,
        confidence: confidenceScore ?? 0,
        scores: scores,
        modelVersion: modelVersion,
      );

  factory AnalysisRecord.fromJson(Object? json) {
    if (json is! Map<String, dynamic>) throw const FormatException('Analyse inattendue');
    final status = switch (json['status']) {
      'prediction_available' => PredictionStatus.predictionAvailable,
      'uncertain' => PredictionStatus.uncertain,
      _ => throw FormatException('Statut inconnu : ${json['status']}'),
    };
    final rawScores = json['scores'];
    if (rawScores is! Map<String, dynamic>) throw const FormatException('Scores absents');
    return AnalysisRecord(
      id: json['id'] as String,
      status: status,
      predictedClass: json['predicted_class'] as String?,
      confidenceScore: (json['confidence_score'] as num?)?.toDouble(),
      scores: rawScores.map((key, value) => MapEntry(key, (value as num).toDouble())),
      modelVersion: json['model_version'] as String,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
    );
  }
}

class AnalysisPage {
  const AnalysisPage({required this.items, required this.total, required this.offset});

  final List<AnalysisRecord> items;
  final int total;
  final int offset;

  factory AnalysisPage.fromJson(Object? json) {
    if (json is! Map<String, dynamic>) throw const FormatException('Page inattendue');
    return AnalysisPage(
      items: (json['items'] as List<dynamic>).map(AnalysisRecord.fromJson).toList(),
      total: (json['total'] as num).toInt(),
      offset: (json['offset'] as num).toInt(),
    );
  }
}

/// Image PNG annotée renvoyée par `POST /api/v1/predictions/annotated-image`.
class ExportedImage {
  const ExportedImage({required this.bytes, required this.predictionId, required this.watermarkApplied});

  final Uint8List bytes;
  final String? predictionId;
  final bool watermarkApplied;
}
