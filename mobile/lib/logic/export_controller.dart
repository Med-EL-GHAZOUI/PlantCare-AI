import 'package:flutter/foundation.dart';

import '../data/models.dart';
import '../data/prediction_api.dart';
import 'image_share_service.dart';

enum ExportStatus { idle, exporting, failure }

/// Exporte l'image annotée du dernier résultat (avec ou sans filigrane) puis ouvre le partage système.
class ExportController extends ChangeNotifier {
  ExportController({required ExportApi api, required ImageShareService share})
      : _api = api,
        _share = share;

  static const filename = 'agriscan-result.png';

  final ExportApi _api;
  final ImageShareService _share;

  ExportStatus _status = ExportStatus.idle;
  ApiFailure? _failure;
  bool _watermark = true;
  PickedImage? _lastImage;
  String? _lastText;

  ExportStatus get status => _status;
  ApiFailure? get failure => _failure;
  bool get isExporting => _status == ExportStatus.exporting;

  /// Filigrane « AgriScan AI » ajouté à l'image exportée (activé par défaut).
  bool get watermark => _watermark;
  set watermark(bool value) {
    if (value == _watermark) return;
    _watermark = value;
    notifyListeners();
  }

  /// Demande l'image annotée au serveur puis la partage. Retourne vrai si la feuille de partage s'est ouverte.
  Future<bool> export(PickedImage image, {required String shareText}) async {
    if (isExporting) return false;
    _lastImage = image;
    _lastText = shareText;
    _failure = null;
    _status = ExportStatus.exporting;
    notifyListeners();
    try {
      final exported = await _api.exportAnnotated(image, watermark: _watermark);
      await _share.shareImage(exported.bytes, filename: filename, text: shareText);
      _status = ExportStatus.idle;
      notifyListeners();
      return true;
    } on ApiFailure catch (failure) {
      _fail(failure);
    } catch (_) {
      _fail(const ApiFailure(FailureKind.unknown));
    }
    return false;
  }

  Future<bool> retry() {
    final image = _lastImage;
    final text = _lastText;
    if (image == null || text == null) return Future.value(false);
    return export(image, shareText: text);
  }

  /// Efface l'échec affiché (nouvelle analyse, retour à l'accueil).
  void reset() {
    if (isExporting || (_status == ExportStatus.idle && _failure == null)) return;
    _status = ExportStatus.idle;
    _failure = null;
    notifyListeners();
  }

  void _fail(ApiFailure failure) {
    _status = ExportStatus.failure;
    _failure = failure;
    notifyListeners();
  }
}
