library;

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

/// Linha de sugestão do autocomplete, para quem desenha a própria lista de
/// `PlaceSuggestion` com o mesmo visual do picker.
export 'src/rich_suggestion.dart';

export 'package:geolocator/geolocator.dart';
