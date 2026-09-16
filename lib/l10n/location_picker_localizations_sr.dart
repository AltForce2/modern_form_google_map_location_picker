// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'location_picker_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Serbian (`sr`).
class GoogleMapLocationPickerLocalizationsSr
    extends GoogleMapLocationPickerLocalizations {
  GoogleMapLocationPickerLocalizationsSr([String locale = 'sr'])
    : super(locale);

  @override
  String get pleaseCheckYourConnection => 'Proverite svoju internet konekciju';

  @override
  String get serverError => 'Greška na serveru.';

  @override
  String get unableToLoadTheMap => 'Unable to load the map';

  @override
  String get accessToLocationDenied => 'Onemogućen pristup lokaciji';

  @override
  String get allowAccessToTheLocationServices =>
      'Omogućite pristup Vašoj lokaciji';

  @override
  String get accessToLocationPermanentlyDenied =>
      'Access to location permanently denied';

  @override
  String get allowAccessToTheLocationServicesFromSettings =>
      'Allow access to the location services for this App using the device settings.';

  @override
  String get ok => 'U redu';

  @override
  String get cantGetCurrentLocation =>
      'Ne možemo da pristupimo Vašoj lokaciji, pokušajte ponovo';

  @override
  String get pleaseMakeSureYouEnableGpsAndTryAgain =>
      'Proverite da li ste omogućili GPS i pokušajte ponovo';

  @override
  String get searchPlace => 'Pretraži';

  @override
  String get findingPlace => 'Pronalaženje mesta ...';

  @override
  String get noResultFound => 'Nema rezultata';

  @override
  String get unnamedPlace => 'Unnamed place';
}
