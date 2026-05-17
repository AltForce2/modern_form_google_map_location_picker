import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' show LatLng;

/// Ponte entre Flutter e o JavaScript embarcado no `google_maps.html`.
/// Mantém só o necessário para o picker: câmera + tipo de mapa.
class LocationPickerMapBridge {
  final InAppWebViewController webViewController;

  ValueChanged<LatLng>? onCameraMove;
  VoidCallback? onCameraIdle;
  VoidCallback? onCameraMoveStarted;
  VoidCallback? onMapReady;

  LocationPickerMapBridge(this.webViewController);

  Future<void> _sendCommand(String action, Map<String, dynamic> data) async {
    try {
      final payload = jsonEncode({'action': action, 'data': data});
      final escaped = payload.replaceAll(r'\', r'\\').replaceAll("'", r"\'");
      await webViewController.evaluateJavascript(
        source: "window.handleFlutterCommand('$escaped')",
      );
    } catch (e) {
      debugPrint('LocationPickerMapBridge sendCommand error: $e');
    }
  }

  void handleMessage(String message) {
    try {
      final map = jsonDecode(message) as Map<String, dynamic>;
      final type = map['type'] as String?;
      final data = (map['data'] as Map?)?.cast<String, dynamic>() ?? const {};
      switch (type) {
        case 'camera_move':
          final lat = (data['lat'] as num?)?.toDouble();
          final lng = (data['lng'] as num?)?.toDouble();
          if (lat != null && lng != null) onCameraMove?.call(LatLng(lat, lng));
          break;
        case 'camera_idle':
          onCameraIdle?.call();
          break;
        case 'camera_move_started':
          onCameraMoveStarted?.call();
          break;
        case 'map_ready':
          onMapReady?.call();
          break;
        default:
          debugPrint('LocationPickerMapBridge: evento desconhecido ($type)');
      }
    } catch (e) {
      debugPrint('LocationPickerMapBridge handleMessage error: $e');
    }
  }

  Future<void> initializeMap({
    required double lat,
    required double lng,
    required double zoom,
    required String mapType,
    String? mapStyleJson,
  }) {
    return _sendCommand('initialize', {
      'lat': lat,
      'lng': lng,
      'zoom': zoom,
      'mapType': mapType,
      if (mapStyleJson != null) 'mapStyleJson': mapStyleJson,
    });
  }

  Future<void> setCameraPosition({
    required double lat,
    required double lng,
    required double zoom,
  }) {
    return _sendCommand('set_camera', {'lat': lat, 'lng': lng, 'zoom': zoom});
  }

  Future<void> setMapType(String mapType) {
    return _sendCommand('set_map_type', {'type': mapType});
  }
}
