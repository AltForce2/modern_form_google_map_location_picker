// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'location_picker_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class GoogleMapLocationPickerLocalizationsRu
    extends GoogleMapLocationPickerLocalizations {
  GoogleMapLocationPickerLocalizationsRu([String locale = 'ru'])
    : super(locale);

  @override
  String get pleaseCheckYourConnection =>
      'Пожалуйста, проверьте ваше соединение';

  @override
  String get serverError => 'Ошибка сервера';

  @override
  String get unableToLoadTheMap => 'Unable to load the map';

  @override
  String get accessToLocationDenied => 'Доступ к местоположению запрещен';

  @override
  String get allowAccessToTheLocationServices =>
      'Разрешить доступ к службам определения местоположения.';

  @override
  String get accessToLocationPermanentlyDenied =>
      'Доступ к местоположению запрещен навсегда';

  @override
  String get allowAccessToTheLocationServicesFromSettings =>
      'Разрешите доступ к службам определения местоположения для этого приложения в настройках устройства.';

  @override
  String get ok => 'ОК';

  @override
  String get cantGetCurrentLocation =>
      'Невозможно получить текущее местоположение';

  @override
  String get pleaseMakeSureYouEnableGpsAndTryAgain =>
      'Пожалуйста, убедитесь, что вы включили GPS и попробуйте снова';

  @override
  String get searchPlace => 'Поиск места';

  @override
  String get findingPlace => 'Finding place...';

  @override
  String get noResultFound => 'No result found';

  @override
  String get unnamedPlace => 'Место без названия';
}
