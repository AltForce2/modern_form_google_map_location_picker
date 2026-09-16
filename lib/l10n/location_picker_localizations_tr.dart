// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'location_picker_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Turkish (`tr`).
class GoogleMapLocationPickerLocalizationsTr
    extends GoogleMapLocationPickerLocalizations {
  GoogleMapLocationPickerLocalizationsTr([String locale = 'tr'])
    : super(locale);

  @override
  String get pleaseCheckYourConnection => 'Lütfen bağlantınızı kontrol edin';

  @override
  String get serverError => 'Sunucu hatası';

  @override
  String get unableToLoadTheMap => 'Unable to load the map';

  @override
  String get accessToLocationDenied => 'Konum erişimi reddedildi';

  @override
  String get allowAccessToTheLocationServices =>
      'Konum servislerine izin verin.';

  @override
  String get accessToLocationPermanentlyDenied =>
      'Konuma erişim kalıcı olarak reddedildi';

  @override
  String get allowAccessToTheLocationServicesFromSettings =>
      'Cihaz ayarlarını kullanarak bu Uygulama için konum hizmetlerine erişime izin verin.';

  @override
  String get ok => 'Tamam';

  @override
  String get cantGetCurrentLocation => 'Geçerli konum alınamıyor';

  @override
  String get pleaseMakeSureYouEnableGpsAndTryAgain =>
      'Lütfen GPS’i etkinleştirin ve tekrar deneyin.';

  @override
  String get searchPlace => 'Konum ara';

  @override
  String get findingPlace => 'Yer aranıyor...';

  @override
  String get noResultFound => 'Sonuç Bulunamadı';

  @override
  String get unnamedPlace => 'Adsız yer';
}
