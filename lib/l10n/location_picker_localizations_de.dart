// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'location_picker_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class GoogleMapLocationPickerLocalizationsDe
    extends GoogleMapLocationPickerLocalizations {
  GoogleMapLocationPickerLocalizationsDe([String locale = 'de'])
    : super(locale);

  @override
  String get pleaseCheckYourConnection => 'Prüfe deine Internetverbindung';

  @override
  String get serverError => 'Server Fehler';

  @override
  String get unableToLoadTheMap => 'Unable to load the map';

  @override
  String get accessToLocationDenied => 'Zugriff auf Standort verweigert';

  @override
  String get allowAccessToTheLocationServices => 'Erlaube Zugriff auf Standort';

  @override
  String get accessToLocationPermanentlyDenied =>
      'Zugriff auf Standort permanent verweigert';

  @override
  String get allowAccessToTheLocationServicesFromSettings =>
      'Erlaube den Zugriff auf den Standort über die Geräteeinstellungen.';

  @override
  String get ok => 'Ok';

  @override
  String get cantGetCurrentLocation => 'Standort kann nicht abgefragt werden.';

  @override
  String get pleaseMakeSureYouEnableGpsAndTryAgain =>
      'Stelle sicher das GPS aktiviert ist und probier es nochmal';

  @override
  String get searchPlace => 'Suche Ort';

  @override
  String get findingPlace => 'Finde Orte...';

  @override
  String get noResultFound => 'Keine Ergebnisse';

  @override
  String get unnamedPlace => 'unbekannter Ort';
}
