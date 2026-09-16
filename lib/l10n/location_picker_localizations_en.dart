// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'location_picker_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class GoogleMapLocationPickerLocalizationsEn
    extends GoogleMapLocationPickerLocalizations {
  GoogleMapLocationPickerLocalizationsEn([String locale = 'en'])
    : super(locale);

  @override
  String get pleaseCheckYourConnection => 'Please check your connection';

  @override
  String get serverError => 'Server error';

  @override
  String get unableToLoadTheMap => 'Unable to load the map';

  @override
  String get accessToLocationDenied => 'Access to location denied';

  @override
  String get allowAccessToTheLocationServices =>
      'Allow access to the location services.';

  @override
  String get accessToLocationPermanentlyDenied =>
      'Access to location permanently denied';

  @override
  String get allowAccessToTheLocationServicesFromSettings =>
      'Allow access to the location services for this App using the device settings.';

  @override
  String get ok => 'Ok';

  @override
  String get cantGetCurrentLocation => 'Can\'t get current location';

  @override
  String get pleaseMakeSureYouEnableGpsAndTryAgain =>
      'Please make sure you enable GPS and try again';

  @override
  String get searchPlace => 'Search place';

  @override
  String get findingPlace => 'Finding place...';

  @override
  String get noResultFound => 'No result found';

  @override
  String get unnamedPlace => 'Unnamed place';
}
