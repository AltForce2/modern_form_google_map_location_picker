/// Nomes do protocolo de mensagens entre o Dart e o `assets/google_maps.html`.
///
/// Estas strings são um contrato entre duas linguagens: o JS as repete
/// literalmente. Mantê-las nomeadas de um lado não impede a divergência, mas
/// deixa o ponto de sincronização explícito — ao mudar qualquer valor aqui,
/// atualize também `assets/google_maps.html`.
abstract final class MapBridgeProtocol {
  /// Nome do handler JS registrado via `addJavaScriptHandler`.
  static const String channel = 'FlutterChannel';

  /// Função global exposta pelo HTML para receber comandos do Dart.
  static const String commandEntryPoint = 'window.handleFlutterCommand';

  // Comandos Dart → JS.
  static const String actionInitialize = 'initialize';
  static const String actionSetCamera = 'set_camera';
  static const String actionSetMapType = 'set_map_type';
  static const String actionSetMyLocation = 'set_my_location';

  // Eventos JS → Dart.
  static const String eventCameraMove = 'camera_move';
  static const String eventCameraIdle = 'camera_idle';
  static const String eventCameraMoveStarted = 'camera_move_started';
  static const String eventMapReady = 'map_ready';

  // Identificadores de tipo de mapa aceitos pelo JS (`mapTypeIdFor`).
  static const String mapTypeNormal = 'normal';
  static const String mapTypeSatellite = 'satellite';
  static const String mapTypeTerrain = 'terrain';
  static const String mapTypeHybrid = 'hybrid';
}
