// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'location_picker_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class GoogleMapLocationPickerLocalizationsAr
    extends GoogleMapLocationPickerLocalizations {
  GoogleMapLocationPickerLocalizationsAr([String locale = 'ar'])
    : super(locale);

  @override
  String get pleaseCheckYourConnection => 'تأكد من وجود انترنت';

  @override
  String get serverError => 'خطأ من الخادم حاول مرة اخري';

  @override
  String get unableToLoadTheMap => 'Unable to load the map';

  @override
  String get accessToLocationDenied => 'تم رفض إذن الوصل الي الموقع الجغرافي';

  @override
  String get allowAccessToTheLocationServices =>
      'من فضلك قم بقبول إذن الوصول الي الموقع الجغرافي';

  @override
  String get accessToLocationPermanentlyDenied =>
      'تم رفض إذن الوصل الي الموقع الجغرافي بشكل نهائي';

  @override
  String get allowAccessToTheLocationServicesFromSettings =>
      'من فضلك قم بقبول إذن الوصول الي الموقع الجغرافي من إدادات التطبيق.';

  @override
  String get ok => 'حسنا';

  @override
  String get cantGetCurrentLocation =>
      'لا يمكن الحصول علي الموقع الجغرافي الحالي';

  @override
  String get pleaseMakeSureYouEnableGpsAndTryAgain =>
      'الرجاء التاكد من تفعيل الـGPS و المحاولة مرة أخري';

  @override
  String get searchPlace => 'إبحث بإسم المكان';

  @override
  String get findingPlace => 'جاري البحث...';

  @override
  String get noResultFound => 'لم يتم العثور على نتائج';

  @override
  String get unnamedPlace => 'مكان بدون اسم';
}
