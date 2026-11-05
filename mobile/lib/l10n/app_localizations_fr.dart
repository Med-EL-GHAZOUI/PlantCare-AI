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

  @override
  String get account => 'Compte';

  @override
  String get signIn => 'Se connecter';

  @override
  String get register => 'Créer un compte';

  @override
  String get signOut => 'Se déconnecter';

  @override
  String get history => 'Historique';

  @override
  String get email => 'Adresse e-mail';

  @override
  String get password => 'Mot de passe';

  @override
  String get passwordHint => '10 caractères minimum';

  @override
  String get signInTitle => 'Connexion';

  @override
  String get registerTitle => 'Créer un compte';

  @override
  String get switchToRegister => 'Pas encore de compte ? Créer un compte';

  @override
  String get switchToSignIn => 'Déjà un compte ? Se connecter';

  @override
  String signedInAs(String email) {
    return 'Connecté : $email';
  }

  @override
  String get signedInUnknown => 'Connecté';

  @override
  String get signInToSaveHint =>
      'Connectez-vous pour conserver vos analyses dans l\'historique.';

  @override
  String get savedToHistory =>
      'Résultat enregistré dans votre historique (la photo n\'est pas conservée).';

  @override
  String get sessionExpired =>
      'Votre session a expiré. Reconnectez-vous pour retrouver votre historique.';

  @override
  String get validationEmail => 'Saisissez une adresse e-mail valide.';

  @override
  String get validationPassword =>
      'Le mot de passe doit contenir au moins 10 caractères.';

  @override
  String get cancel => 'Annuler';

  @override
  String get delete => 'Supprimer';

  @override
  String get deleteAccount => 'Supprimer mon compte';

  @override
  String get deleteAccountTitle => 'Supprimer votre compte ?';

  @override
  String get deleteAccountBody =>
      'Votre compte et toutes vos analyses enregistrées seront supprimés définitivement.';

  @override
  String get historyTitle => 'Mes analyses';

  @override
  String get historyEmpty =>
      'Aucune analyse enregistrée. Les analyses faites en étant connecté apparaissent ici.';

  @override
  String get historyPrivacy =>
      'Seuls les résultats sont conservés, jamais les photos.';

  @override
  String get historyUncertainItem => 'Résultat incertain';

  @override
  String get loadMore => 'Charger plus';

  @override
  String get detailTitle => 'Détail de l\'analyse';

  @override
  String analyzedOn(String date) {
    return 'Analysé le $date';
  }

  @override
  String modelVersionLabel(String version) {
    return 'Version du modèle : $version';
  }

  @override
  String get deleteAnalysis => 'Supprimer cette analyse';

  @override
  String get deleteAnalysisTitle => 'Supprimer cette analyse ?';

  @override
  String get deleteAnalysisBody => 'Cette action est définitive.';

  @override
  String get analysisDeleted => 'Analyse supprimée.';

  @override
  String get errorUnauthorized =>
      'Votre session n\'est plus valide. Reconnectez-vous.';

  @override
  String get errorInvalidCredentials =>
      'Adresse e-mail ou mot de passe incorrect.';

  @override
  String get errorEmailTaken => 'Cette adresse e-mail est déjà utilisée.';

  @override
  String get errorTooManyAttempts =>
      'Trop de tentatives. Réessayez dans quelques minutes.';

  @override
  String get errorNotFound =>
      'Cette analyse est introuvable (elle a peut-être déjà été supprimée).';

  @override
  String get errorInvalidInput =>
      'Les informations saisies ne sont pas valides.';

  @override
  String get errorAccountsUnavailable =>
      'Les comptes et l\'historique sont momentanément indisponibles.';

  @override
  String get exportTitle => 'Exporter le résultat';

  @override
  String get exportButton => 'Exporter l\'image annotée';

  @override
  String get exportingLabel => 'Préparation de l\'image…';

  @override
  String get exportWatermarkOption => 'Ajouter le filigrane « AgriScan AI »';

  @override
  String get exportNote =>
      'L\'image exportée contient la photo, le résultat, le score du modèle et la mention « pas un diagnostic confirmé ». Le filigrane indique la provenance, il ne prouve pas l\'authenticité. Le texte de l\'image est en français sans accents et le nom de la classe est en anglais. Le serveur ne conserve pas l\'image ; vous choisissez où la partager.';

  @override
  String get exportShareText =>
      'Résultat de dépistage AgriScan AI (aide au dépistage, pas un diagnostic confirmé)';

  @override
  String get errorShareFailed =>
      'Impossible d\'ouvrir le partage sur cet appareil. Réessayez.';
}
