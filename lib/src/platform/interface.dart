import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' show LatLng, MapType;

/// Contrato de implementação do mapa do picker para cada plataforma.
abstract class LocationPickerMapInterface {
  Widget buildWidget({
    required LatLng initialCenter,
    required double initialZoom,
    required MapType mapType,
    required String? mapStyleJson,
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
