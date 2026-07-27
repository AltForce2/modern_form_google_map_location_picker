import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' show LatLng, MapType;

/// Contrato de implementação do mapa do picker para cada plataforma.
///
/// Divergências conhecidas entre as implementações — a interface não consegue
/// sinalizá-las em tempo de compilação, então ficam registradas aqui:
///
/// - [onCameraMoveStarted] dispara em qualquer início de movimento no nativo,
///   mas só em `dragstart` no WebView (zoom e movimento programático não
///   disparam).
/// - O WebView emite um [onCameraIdle] logo após o primeiro render; o nativo
///   não emite nada até o usuário mexer no mapa.
abstract class LocationPickerMapInterface {
  Widget buildWidget({
    required LatLng initialCenter,
    required double initialZoom,
    required MapType mapType,
    required String? mapStyleJson,

    /// Exibe o indicador da posição atual. No nativo é o `myLocationEnabled` do
    /// `GoogleMap`; no WebView o adapter assina o geolocator e desenha o ponto
    /// azul via JS, porque o Maps JS API não tem equivalente.
    required bool myLocationEnabled,
    required ValueChanged<LatLng> onCameraMove,
    required VoidCallback onCameraIdle,
    required VoidCallback onCameraMoveStarted,
    required VoidCallback onMapReady,
    Set<Factory<OneSequenceGestureRecognizer>>? gestureRecognizers,
  });

  Future<void> animateCamera(LatLng target, double zoom);

  Future<void> setMapType(MapType mapType);

  void dispose();
}
