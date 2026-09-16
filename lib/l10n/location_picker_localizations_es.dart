// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'location_picker_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class GoogleMapLocationPickerLocalizationsEs
    extends GoogleMapLocationPickerLocalizations {
  GoogleMapLocationPickerLocalizationsEs([String locale = 'es'])
    : super(locale);

  @override
  String get pleaseCheckYourConnection => 'Por favor, verifique su conexión';

  @override
  String get serverError => 'Error del servidor';

  @override
  String get unableToLoadTheMap => 'No se pudo cargar el mapa';

  @override
  String get accessToLocationDenied => 'Acceso a la ubicación denegado';

  @override
  String get allowAccessToTheLocationServices =>
      'Permitir acceso a los servicios de ubicación';

  @override
  String get accessToLocationPermanentlyDenied =>
      'Acceso a la ubicación denegado permanentemente';

  @override
  String get allowAccessToTheLocationServicesFromSettings =>
      'Permita el acceso a los servicios de ubicación para esta aplicación usando la configuración del dispositivo.';

  @override
  String get ok => 'Ok';

  @override
  String get cantGetCurrentLocation =>
      'No se puede obtener la ubicación actual';

  @override
  String get pleaseMakeSureYouEnableGpsAndTryAgain =>
      'Asegúrese de habilitar el GPS y vuelva a intentarlo';

  @override
  String get searchPlace => 'Buscar lugar';

  @override
  String get findingPlace => 'Buscando lugar ...';

  @override
  String get noResultFound => 'No se encontraron resultados';

  @override
  String get unnamedPlace => 'Lugar sin nombre';
}
