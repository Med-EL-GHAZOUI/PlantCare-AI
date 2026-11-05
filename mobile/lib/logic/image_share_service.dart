import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';

import '../data/api_errors.dart';

/// Partage ou enregistre une image via la feuille de partage du système. C'est l'utilisateur qui choisit
/// la destination (galerie, messagerie…) : l'application n'envoie jamais l'image d'elle-même.
abstract class ImageShareService {
  /// Lève [ApiFailure] (shareFailed) si la feuille de partage ne peut pas s'ouvrir.
  Future<void> shareImage(Uint8List bytes, {required String filename, required String text});
}

class SharePlusImageShareService implements ImageShareService {
  @override
  Future<void> shareImage(Uint8List bytes, {required String filename, required String text}) async {
    try {
      await SharePlus.instance.share(ShareParams(
        files: [XFile.fromData(bytes, mimeType: 'image/png')],
        fileNameOverrides: [filename],
        text: text,
      ));
    } on Exception {
      throw const ApiFailure(FailureKind.shareFailed);
    }
  }
}
