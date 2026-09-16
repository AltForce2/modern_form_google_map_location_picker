// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'location_picker_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class GoogleMapLocationPickerLocalizationsPt
    extends GoogleMapLocationPickerLocalizations {
  GoogleMapLocationPickerLocalizationsPt([String locale = 'pt'])
    : super(locale);

  @override
  String get pleaseCheckYourConnection => 'Por favor, verifique sua conexão';

  @override
  String get serverError => 'Erro de servidor';

  @override
  String get unableToLoadTheMap => 'Não foi possível carregar o mapa';

  @override
  String get accessToLocationDenied => 'Acesso a localização negado';

  @override
  String get allowAccessToTheLocationServices =>
      'Permitir acesso aos serviços de localização.';

  @override
  String get accessToLocationPermanentlyDenied =>
      'Acesso ao local negado permanentemente';

  @override
  String get allowAccessToTheLocationServicesFromSettings =>
      'Permita o acesso aos serviços de localização para este aplicativo usando as configurações do dispositivo.';

  @override
  String get ok => 'Ok';

  @override
  String get cantGetCurrentLocation =>
      'Não é possível obter a localização atual';

  @override
  String get pleaseMakeSureYouEnableGpsAndTryAgain =>
      'Certifique-se de ativar o GPS e tente novamente';

  @override
  String get searchPlace => 'Pesquisar endereço';

  @override
  String get findingPlace => 'Encontrando lugar...';

  @override
  String get noResultFound => 'Nenhum resultado encontrado';

  @override
  String get unnamedPlace => 'Lugar sem nome';
}
