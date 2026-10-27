import 'package:image_picker/image_picker.dart';

import '../data/models.dart';
import '../data/prediction_api.dart';

enum ImageOrigin { camera, gallery }

abstract class ImageSourceService {
  /// Retourne null si l'utilisateur annule ; lève [ApiFailure] (pickFailed) si l'accès échoue.
  Future<PickedImage?> pick(ImageOrigin origin);
}

class DeviceImageSourceService implements ImageSourceService {
  DeviceImageSourceService({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<PickedImage?> pick(ImageOrigin origin) async {
    try {
      // Réduction à 1024 px : le serveur redimensionne de toute façon à 224 px, et l'envoi reste léger.
      final file = await _picker.pickImage(
        source: origin == ImageOrigin.camera ? ImageSource.camera : ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 90,
      );
      if (file == null) return null;
      return PickedImage(bytes: await file.readAsBytes(), name: file.name);
    } on Exception {
      throw const ApiFailure(FailureKind.pickFailed);
    }
  }
}
