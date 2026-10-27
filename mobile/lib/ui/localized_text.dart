import '../data/prediction_api.dart';
import '../l10n/app_localizations.dart';

/// Nom lisible d'une étiquette brute du modèle (ex. `Tomato___Late_blight`).
/// Une étiquette inconnue (modèle plus récent) est affichée telle quelle, jamais masquée.
String localizedClassName(AppLocalizations l10n, String rawLabel) {
  return switch (rawLabel) {
    'Tomato___Bacterial_spot' => l10n.classBacterialSpot,
    'Tomato___Early_blight' => l10n.classEarlyBlight,
    'Tomato___Late_blight' => l10n.classLateBlight,
    'Tomato___Leaf_Mold' => l10n.classLeafMold,
    'Tomato___Septoria_leaf_spot' => l10n.classSeptoriaLeafSpot,
    'Tomato___Spider_mites Two-spotted_spider_mite' => l10n.classSpiderMites,
    'Tomato___Target_Spot' => l10n.classTargetSpot,
    'Tomato___Tomato_Yellow_Leaf_Curl_Virus' => l10n.classYellowLeafCurlVirus,
    'Tomato___Tomato_mosaic_virus' => l10n.classMosaicVirus,
    'Tomato___healthy' => l10n.classHealthy,
    _ => l10n.classUnknown(rawLabel),
  };
}

String failureMessage(AppLocalizations l10n, FailureKind kind) {
  return switch (kind) {
    FailureKind.network => l10n.errorNetwork,
    FailureKind.timeout => l10n.errorTimeout,
    FailureKind.fileTooLarge => l10n.errorFileTooLarge,
    FailureKind.unsupportedFormat => l10n.errorUnsupportedFormat,
    FailureKind.invalidImage => l10n.errorInvalidImage,
    FailureKind.emptyFile => l10n.errorEmptyFile,
    FailureKind.imageTooSmall => l10n.errorImageTooSmall,
    FailureKind.imageTooLarge => l10n.errorImageTooLarge,
    FailureKind.modelUnavailable => l10n.errorModelUnavailable,
    FailureKind.server => l10n.errorServer,
    FailureKind.invalidResponse => l10n.errorInvalidResponse,
    FailureKind.pickFailed => l10n.errorPickFailed,
    FailureKind.unknown => l10n.errorUnknown,
  };
}
