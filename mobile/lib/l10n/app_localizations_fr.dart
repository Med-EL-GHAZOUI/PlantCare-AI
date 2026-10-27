// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'AgriScan AI';

  @override
  String get tagline =>
      'Aide au dépistage des maladies de la feuille de tomate';

  @override
  String get emptyHint =>
      'Photographiez une feuille de tomate seule, bien éclairée et nette, ou choisissez une photo dans la galerie.';

  @override
  String get takePhoto => 'Prendre une photo';

  @override
  String get chooseFromGallery => 'Choisir dans la galerie';

  @override
  String get analyzing => 'Analyse en cours…';

  @override
  String get language => 'Langue';

  @override
  String get languageFrench => 'Français';

  @override
  String get languageArabic => 'العربية';

  @override
  String get selectedImage => 'Photo sélectionnée';

  @override
  String get resultTitle => 'Résultat du dépistage';

  @override
  String modelScore(String percent) {
    return 'Score du modèle : $percent';
  }

  @override
  String get modelScoreNote =>
      'Ce score n\'est pas une probabilité calibrée : il indique seulement la confiance relative du modèle.';

  @override
  String get otherClassesTitle => 'Classes les plus proches';

  @override
  String get uncertainTitle => 'Résultat incertain';

  @override
  String get uncertainBody =>
      'Le modèle n\'est pas assez sûr pour proposer une classe. Reprenez une photo plus nette, mieux éclairée, avec une seule feuille de tomate, ou demandez l\'avis d\'un spécialiste.';

  @override
  String get disclaimer =>
      'Résultat de dépistage par IA, pas un diagnostic confirmé. Faites vérifier par un spécialiste (technicien, ingénieur agronome) avant toute décision de traitement.';

  @override
  String get limitsTitle => 'Limites';

  @override
  String get limitsBody =>
      'Le modèle ne connaît que 10 classes de feuilles de tomate (9 maladies ou ravageurs et « saine »). Il ne détecte pas les images hors sujet ni les autres maladies, et a été évalué sur des photos en conditions contrôlées, pas sur des champs.';

  @override
  String get newAnalysis => 'Nouvelle analyse';

  @override
  String get retry => 'Réessayer';

  @override
  String get errorNetwork =>
      'Impossible de joindre le serveur. Vérifiez votre connexion internet puis réessayez.';

  @override
  String get errorTimeout =>
      'Le serveur met trop de temps à répondre. Réessayez dans un instant.';

  @override
  String get errorFileTooLarge =>
      'La photo est trop volumineuse (5 Mo maximum). Choisissez une photo plus légère.';

  @override
  String get errorUnsupportedFormat =>
      'Format non pris en charge. Utilisez une photo JPEG ou PNG.';

  @override
  String get errorInvalidImage =>
      'Cette image est illisible ou corrompue. Choisissez-en une autre.';

  @override
  String get errorEmptyFile =>
      'Le fichier est vide. Choisissez une autre photo.';

  @override
  String get errorImageTooSmall =>
      'La photo est trop petite. Rapprochez-vous de la feuille.';

  @override
  String get errorImageTooLarge =>
      'Les dimensions de la photo sont trop grandes. Choisissez une photo plus petite.';

  @override
  String get errorModelUnavailable =>
      'Le service d\'analyse est momentanément indisponible. Réessayez plus tard.';

  @override
  String get errorServer =>
      'Le serveur a rencontré un problème. Réessayez plus tard.';

  @override
  String get errorInvalidResponse =>
      'Réponse inattendue du serveur. Réessayez plus tard.';

  @override
  String get errorPickFailed =>
      'Impossible d\'accéder à la caméra ou à la galerie. Vérifiez les autorisations de l\'application.';

  @override
  String get errorUnknown =>
      'Une erreur inattendue s\'est produite. Réessayez.';

  @override
  String get classBacterialSpot => 'Tache bactérienne';

  @override
  String get classEarlyBlight => 'Alternariose (brûlure précoce)';

  @override
  String get classLateBlight => 'Mildiou (brûlure tardive)';

  @override
  String get classLeafMold => 'Cladosporiose (moisissure des feuilles)';

  @override
  String get classSeptoriaLeafSpot => 'Septoriose (taches foliaires)';

  @override
  String get classSpiderMites => 'Acariens tétranyques (araignées rouges)';

  @override
  String get classTargetSpot => 'Tache cible';

  @override
  String get classYellowLeafCurlVirus =>
      'Virus de l\'enroulement jaune en cuillère (TYLCV)';

  @override
  String get classMosaicVirus => 'Virus de la mosaïque de la tomate';

  @override
  String get classHealthy => 'Feuille saine';

  @override
  String classUnknown(String name) {
    return 'Classe inconnue ($name)';
  }
}
