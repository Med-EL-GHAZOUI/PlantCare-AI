import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('fr'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In fr, this message translates to:
  /// **'AgriScan AI'**
  String get appTitle;

  /// No description provided for @tagline.
  ///
  /// In fr, this message translates to:
  /// **'Aide au dépistage des maladies de la feuille de tomate'**
  String get tagline;

  /// No description provided for @emptyHint.
  ///
  /// In fr, this message translates to:
  /// **'Photographiez une feuille de tomate seule, bien éclairée et nette, ou choisissez une photo dans la galerie.'**
  String get emptyHint;

  /// No description provided for @takePhoto.
  ///
  /// In fr, this message translates to:
  /// **'Prendre une photo'**
  String get takePhoto;

  /// No description provided for @chooseFromGallery.
  ///
  /// In fr, this message translates to:
  /// **'Choisir dans la galerie'**
  String get chooseFromGallery;

  /// No description provided for @analyzing.
  ///
  /// In fr, this message translates to:
  /// **'Analyse en cours…'**
  String get analyzing;

  /// No description provided for @language.
  ///
  /// In fr, this message translates to:
  /// **'Langue'**
  String get language;

  /// No description provided for @languageFrench.
  ///
  /// In fr, this message translates to:
  /// **'Français'**
  String get languageFrench;

  /// No description provided for @languageArabic.
  ///
  /// In fr, this message translates to:
  /// **'العربية'**
  String get languageArabic;

  /// No description provided for @selectedImage.
  ///
  /// In fr, this message translates to:
  /// **'Photo sélectionnée'**
  String get selectedImage;

  /// No description provided for @resultTitle.
  ///
  /// In fr, this message translates to:
  /// **'Résultat du dépistage'**
  String get resultTitle;

  /// No description provided for @modelScore.
  ///
  /// In fr, this message translates to:
  /// **'Score du modèle : {percent}'**
  String modelScore(String percent);

  /// No description provided for @modelScoreNote.
  ///
  /// In fr, this message translates to:
  /// **'Ce score n\'est pas une probabilité calibrée : il indique seulement la confiance relative du modèle.'**
  String get modelScoreNote;

  /// No description provided for @otherClassesTitle.
  ///
  /// In fr, this message translates to:
  /// **'Classes les plus proches'**
  String get otherClassesTitle;

  /// No description provided for @uncertainTitle.
  ///
  /// In fr, this message translates to:
  /// **'Résultat incertain'**
  String get uncertainTitle;

  /// No description provided for @uncertainBody.
  ///
  /// In fr, this message translates to:
  /// **'Le modèle n\'est pas assez sûr pour proposer une classe. Reprenez une photo plus nette, mieux éclairée, avec une seule feuille de tomate, ou demandez l\'avis d\'un spécialiste.'**
  String get uncertainBody;

  /// No description provided for @disclaimer.
  ///
  /// In fr, this message translates to:
  /// **'Résultat de dépistage par IA, pas un diagnostic confirmé. Faites vérifier par un spécialiste (technicien, ingénieur agronome) avant toute décision de traitement.'**
  String get disclaimer;

  /// No description provided for @limitsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Limites'**
  String get limitsTitle;

  /// No description provided for @limitsBody.
  ///
  /// In fr, this message translates to:
  /// **'Le modèle ne connaît que 10 classes de feuilles de tomate (9 maladies ou ravageurs et « saine »). Il ne détecte pas les images hors sujet ni les autres maladies, et a été évalué sur des photos en conditions contrôlées, pas sur des champs.'**
  String get limitsBody;

  /// No description provided for @newAnalysis.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle analyse'**
  String get newAnalysis;

  /// No description provided for @retry.
  ///
  /// In fr, this message translates to:
  /// **'Réessayer'**
  String get retry;

  /// No description provided for @errorNetwork.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de joindre le serveur. Vérifiez votre connexion internet puis réessayez.'**
  String get errorNetwork;

  /// No description provided for @errorTimeout.
  ///
  /// In fr, this message translates to:
  /// **'Le serveur met trop de temps à répondre. Réessayez dans un instant.'**
  String get errorTimeout;

  /// No description provided for @errorFileTooLarge.
  ///
  /// In fr, this message translates to:
  /// **'La photo est trop volumineuse (5 Mo maximum). Choisissez une photo plus légère.'**
  String get errorFileTooLarge;

  /// No description provided for @errorUnsupportedFormat.
  ///
  /// In fr, this message translates to:
  /// **'Format non pris en charge. Utilisez une photo JPEG ou PNG.'**
  String get errorUnsupportedFormat;

  /// No description provided for @errorInvalidImage.
  ///
  /// In fr, this message translates to:
  /// **'Cette image est illisible ou corrompue. Choisissez-en une autre.'**
  String get errorInvalidImage;

  /// No description provided for @errorEmptyFile.
  ///
  /// In fr, this message translates to:
  /// **'Le fichier est vide. Choisissez une autre photo.'**
  String get errorEmptyFile;

  /// No description provided for @errorImageTooSmall.
  ///
  /// In fr, this message translates to:
  /// **'La photo est trop petite. Rapprochez-vous de la feuille.'**
  String get errorImageTooSmall;

  /// No description provided for @errorImageTooLarge.
  ///
  /// In fr, this message translates to:
  /// **'Les dimensions de la photo sont trop grandes. Choisissez une photo plus petite.'**
  String get errorImageTooLarge;

  /// No description provided for @errorModelUnavailable.
  ///
  /// In fr, this message translates to:
  /// **'Le service d\'analyse est momentanément indisponible. Réessayez plus tard.'**
  String get errorModelUnavailable;

  /// No description provided for @errorServer.
  ///
  /// In fr, this message translates to:
  /// **'Le serveur a rencontré un problème. Réessayez plus tard.'**
  String get errorServer;

  /// No description provided for @errorInvalidResponse.
  ///
  /// In fr, this message translates to:
  /// **'Réponse inattendue du serveur. Réessayez plus tard.'**
  String get errorInvalidResponse;

  /// No description provided for @errorPickFailed.
  ///
  /// In fr, this message translates to:
  /// **'Impossible d\'accéder à la caméra ou à la galerie. Vérifiez les autorisations de l\'application.'**
  String get errorPickFailed;

  /// No description provided for @errorUnknown.
  ///
  /// In fr, this message translates to:
  /// **'Une erreur inattendue s\'est produite. Réessayez.'**
  String get errorUnknown;

  /// No description provided for @classBacterialSpot.
  ///
  /// In fr, this message translates to:
  /// **'Tache bactérienne'**
  String get classBacterialSpot;

  /// No description provided for @classEarlyBlight.
  ///
  /// In fr, this message translates to:
  /// **'Alternariose (brûlure précoce)'**
  String get classEarlyBlight;

  /// No description provided for @classLateBlight.
  ///
  /// In fr, this message translates to:
  /// **'Mildiou (brûlure tardive)'**
  String get classLateBlight;

  /// No description provided for @classLeafMold.
  ///
  /// In fr, this message translates to:
  /// **'Cladosporiose (moisissure des feuilles)'**
  String get classLeafMold;

  /// No description provided for @classSeptoriaLeafSpot.
  ///
  /// In fr, this message translates to:
  /// **'Septoriose (taches foliaires)'**
  String get classSeptoriaLeafSpot;

  /// No description provided for @classSpiderMites.
  ///
  /// In fr, this message translates to:
  /// **'Acariens tétranyques (araignées rouges)'**
  String get classSpiderMites;

  /// No description provided for @classTargetSpot.
  ///
  /// In fr, this message translates to:
  /// **'Tache cible'**
  String get classTargetSpot;

  /// No description provided for @classYellowLeafCurlVirus.
  ///
  /// In fr, this message translates to:
  /// **'Virus de l\'enroulement jaune en cuillère (TYLCV)'**
  String get classYellowLeafCurlVirus;

  /// No description provided for @classMosaicVirus.
  ///
  /// In fr, this message translates to:
  /// **'Virus de la mosaïque de la tomate'**
  String get classMosaicVirus;

  /// No description provided for @classHealthy.
  ///
  /// In fr, this message translates to:
  /// **'Feuille saine'**
  String get classHealthy;

  /// No description provided for @classUnknown.
  ///
  /// In fr, this message translates to:
  /// **'Classe inconnue ({name})'**
  String classUnknown(String name);

  /// No description provided for @account.
  ///
  /// In fr, this message translates to:
  /// **'Compte'**
  String get account;

  /// No description provided for @signIn.
  ///
  /// In fr, this message translates to:
  /// **'Se connecter'**
  String get signIn;

  /// No description provided for @register.
  ///
  /// In fr, this message translates to:
  /// **'Créer un compte'**
  String get register;

  /// No description provided for @signOut.
  ///
  /// In fr, this message translates to:
  /// **'Se déconnecter'**
  String get signOut;

  /// No description provided for @history.
  ///
  /// In fr, this message translates to:
  /// **'Historique'**
  String get history;

  /// No description provided for @email.
  ///
  /// In fr, this message translates to:
  /// **'Adresse e-mail'**
  String get email;

  /// No description provided for @password.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe'**
  String get password;

  /// No description provided for @passwordHint.
  ///
  /// In fr, this message translates to:
  /// **'10 caractères minimum'**
  String get passwordHint;

  /// No description provided for @signInTitle.
  ///
  /// In fr, this message translates to:
  /// **'Connexion'**
  String get signInTitle;

  /// No description provided for @registerTitle.
  ///
  /// In fr, this message translates to:
  /// **'Créer un compte'**
  String get registerTitle;

  /// No description provided for @switchToRegister.
  ///
  /// In fr, this message translates to:
  /// **'Pas encore de compte ? Créer un compte'**
  String get switchToRegister;

  /// No description provided for @switchToSignIn.
  ///
  /// In fr, this message translates to:
  /// **'Déjà un compte ? Se connecter'**
  String get switchToSignIn;

  /// No description provided for @signedInAs.
  ///
  /// In fr, this message translates to:
  /// **'Connecté : {email}'**
  String signedInAs(String email);

  /// No description provided for @signedInUnknown.
  ///
  /// In fr, this message translates to:
  /// **'Connecté'**
  String get signedInUnknown;

  /// No description provided for @signInToSaveHint.
  ///
  /// In fr, this message translates to:
  /// **'Connectez-vous pour conserver vos analyses dans l\'historique.'**
  String get signInToSaveHint;

  /// No description provided for @savedToHistory.
  ///
  /// In fr, this message translates to:
  /// **'Résultat enregistré dans votre historique (la photo n\'est pas conservée).'**
  String get savedToHistory;

  /// No description provided for @sessionExpired.
  ///
  /// In fr, this message translates to:
  /// **'Votre session a expiré. Reconnectez-vous pour retrouver votre historique.'**
  String get sessionExpired;

  /// No description provided for @validationEmail.
  ///
  /// In fr, this message translates to:
  /// **'Saisissez une adresse e-mail valide.'**
  String get validationEmail;

  /// No description provided for @validationPassword.
  ///
  /// In fr, this message translates to:
  /// **'Le mot de passe doit contenir au moins 10 caractères.'**
  String get validationPassword;

  /// No description provided for @cancel.
  ///
  /// In fr, this message translates to:
  /// **'Annuler'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer'**
  String get delete;

  /// No description provided for @deleteAccount.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer mon compte'**
  String get deleteAccount;

  /// No description provided for @deleteAccountTitle.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer votre compte ?'**
  String get deleteAccountTitle;

  /// No description provided for @deleteAccountBody.
  ///
  /// In fr, this message translates to:
  /// **'Votre compte et toutes vos analyses enregistrées seront supprimés définitivement.'**
  String get deleteAccountBody;

  /// No description provided for @historyTitle.
  ///
  /// In fr, this message translates to:
  /// **'Mes analyses'**
  String get historyTitle;

  /// No description provided for @historyEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Aucune analyse enregistrée. Les analyses faites en étant connecté apparaissent ici.'**
  String get historyEmpty;

  /// No description provided for @historyPrivacy.
  ///
  /// In fr, this message translates to:
  /// **'Seuls les résultats sont conservés, jamais les photos.'**
  String get historyPrivacy;

  /// No description provided for @historyUncertainItem.
  ///
  /// In fr, this message translates to:
  /// **'Résultat incertain'**
  String get historyUncertainItem;

  /// No description provided for @loadMore.
  ///
  /// In fr, this message translates to:
  /// **'Charger plus'**
  String get loadMore;

  /// No description provided for @detailTitle.
  ///
  /// In fr, this message translates to:
  /// **'Détail de l\'analyse'**
  String get detailTitle;

  /// No description provided for @analyzedOn.
  ///
  /// In fr, this message translates to:
  /// **'Analysé le {date}'**
  String analyzedOn(String date);

  /// No description provided for @modelVersionLabel.
  ///
  /// In fr, this message translates to:
  /// **'Version du modèle : {version}'**
  String modelVersionLabel(String version);

  /// No description provided for @deleteAnalysis.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer cette analyse'**
  String get deleteAnalysis;

  /// No description provided for @deleteAnalysisTitle.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer cette analyse ?'**
  String get deleteAnalysisTitle;

  /// No description provided for @deleteAnalysisBody.
  ///
  /// In fr, this message translates to:
  /// **'Cette action est définitive.'**
  String get deleteAnalysisBody;

  /// No description provided for @analysisDeleted.
  ///
  /// In fr, this message translates to:
  /// **'Analyse supprimée.'**
  String get analysisDeleted;

  /// No description provided for @errorUnauthorized.
  ///
  /// In fr, this message translates to:
  /// **'Votre session n\'est plus valide. Reconnectez-vous.'**
  String get errorUnauthorized;

  /// No description provided for @errorInvalidCredentials.
  ///
  /// In fr, this message translates to:
  /// **'Adresse e-mail ou mot de passe incorrect.'**
  String get errorInvalidCredentials;

  /// No description provided for @errorEmailTaken.
  ///
  /// In fr, this message translates to:
  /// **'Cette adresse e-mail est déjà utilisée.'**
  String get errorEmailTaken;

  /// No description provided for @errorTooManyAttempts.
  ///
  /// In fr, this message translates to:
  /// **'Trop de tentatives. Réessayez dans quelques minutes.'**
  String get errorTooManyAttempts;

  /// No description provided for @errorNotFound.
  ///
  /// In fr, this message translates to:
  /// **'Cette analyse est introuvable (elle a peut-être déjà été supprimée).'**
  String get errorNotFound;

  /// No description provided for @errorInvalidInput.
  ///
  /// In fr, this message translates to:
  /// **'Les informations saisies ne sont pas valides.'**
  String get errorInvalidInput;

  /// No description provided for @errorAccountsUnavailable.
  ///
  /// In fr, this message translates to:
  /// **'Les comptes et l\'historique sont momentanément indisponibles.'**
  String get errorAccountsUnavailable;

  /// No description provided for @exportTitle.
  ///
  /// In fr, this message translates to:
  /// **'Exporter le résultat'**
  String get exportTitle;

  /// No description provided for @exportButton.
  ///
  /// In fr, this message translates to:
  /// **'Exporter l\'image annotée'**
  String get exportButton;

  /// No description provided for @exportingLabel.
  ///
  /// In fr, this message translates to:
  /// **'Préparation de l\'image…'**
  String get exportingLabel;

  /// No description provided for @exportWatermarkOption.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter le filigrane « AgriScan AI »'**
  String get exportWatermarkOption;

  /// No description provided for @exportNote.
  ///
  /// In fr, this message translates to:
  /// **'L\'image exportée contient la photo, le résultat, le score du modèle et la mention « pas un diagnostic confirmé ». Le filigrane indique la provenance, il ne prouve pas l\'authenticité. Le texte de l\'image est en français sans accents et le nom de la classe est en anglais. Le serveur ne conserve pas l\'image ; vous choisissez où la partager.'**
  String get exportNote;

  /// No description provided for @exportShareText.
  ///
  /// In fr, this message translates to:
  /// **'Résultat de dépistage AgriScan AI (aide au dépistage, pas un diagnostic confirmé)'**
  String get exportShareText;

  /// No description provided for @errorShareFailed.
  ///
  /// In fr, this message translates to:
  /// **'Impossible d\'ouvrir le partage sur cet appareil. Réessayez.'**
  String get errorShareFailed;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
