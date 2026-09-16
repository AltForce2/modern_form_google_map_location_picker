library;

/// Textos do pacote, gerados por `flutter gen-l10n` a partir de `lib/l10n/*.arb`.
/// O host precisa registrar `GoogleMapLocationPickerLocalizations.delegate` em
/// `localizationsDelegates` para o picker achar os textos.
export 'l10n/location_picker_localizations.dart';

export 'src/google_map_location_picker.dart';
export 'src/model/location_result.dart';
export 'src/model/location_address.dart';
export 'src/utils/location_utils.dart';

/// Camada de rede. Implemente `LocationPickerApi` e atribua a
/// `LocationPickerApi.instance` para redirecionar todas as chamadas do picker
/// para um backend próprio em vez das APIs do Google.
export 'src/api/location_picker_api.dart';
export 'src/api/google_location_picker_api.dart';
export 'src/api/backend_location_picker_api.dart';

export 'package:geolocator/geolocator.dart';
