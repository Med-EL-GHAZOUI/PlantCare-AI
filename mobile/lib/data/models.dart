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
