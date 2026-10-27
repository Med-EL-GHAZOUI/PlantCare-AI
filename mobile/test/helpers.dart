import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:agriscan_mobile/data/models.dart';
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

  @override
  Future<Prediction> predict(PickedImage image) async {
    calls++;
    if (completer != null) return completer!.future;
    if (failure != null) throw failure!;
    return result!;
  }
}
