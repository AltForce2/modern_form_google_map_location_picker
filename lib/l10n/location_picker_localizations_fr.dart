// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'location_picker_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class GoogleMapLocationPickerLocalizationsFr
    extends GoogleMapLocationPickerLocalizations {
  GoogleMapLocationPickerLocalizationsFr([String locale = 'fr'])
    : super(locale);

  @override
  String get pleaseCheckYourConnection => 'Veuillez vérifier votre connexion';

  @override
  String get serverError => 'Erreur du serveur';

  @override
  String get unableToLoadTheMap => 'Unable to load the map';

  @override
  String get accessToLocationDenied => 'Accès à l\'emplacement refusé';

  @override
  String get allowAccessToTheLocationServices =>
      'Autoriser l\'accès aux services de localisation.';

  @override
  String get accessToLocationPermanentlyDenied =>
      'Accès à l\'emplacement refusé définitivement';

  @override
  String get allowAccessToTheLocationServicesFromSettings =>
      'Autorisez l\'accès aux services de localisation pour cette application à l\'aide des paramètres de l\'appareil.';

  @override
  String get ok => 'D\'accord';

  @override
  String get cantGetCurrentLocation =>
      'Impossible d\'obtenir l\'emplacement actuel';

  @override
  String get pleaseMakeSureYouEnableGpsAndTryAgain =>
      'Veuillez vous assurer d\'activer le GPS et de réessayer';

  @override
  String get searchPlace => 'Rechercher un lieu';

  @override
  String get findingPlace => 'En train de trouver un lieu...';

  @override
  String get noResultFound => 'Aucun résultat trouvé';

  @override
  String get unnamedPlace => 'Lieu sans nom';
}
