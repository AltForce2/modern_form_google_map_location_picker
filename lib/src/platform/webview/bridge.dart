import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' show LatLng;

import 'protocol.dart';

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
      // Escapa também quebras de linha reais (podem vir dentro de
      // `mapStyleJson`), que gerariam JS sintaticamente inválido.
      final escaped = payload
          .replaceAll(r'\', r'\\')
          .replaceAll("'", r"\'")
          .replaceAll('\n', r'\n')
          .replaceAll('\r', r'\r');
      await webViewController.evaluateJavascript(
        source: "${MapBridgeProtocol.commandEntryPoint}('$escaped')",
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
        case MapBridgeProtocol.eventCameraMove:
          final lat = (data['lat'] as num?)?.toDouble();
          final lng = (data['lng'] as num?)?.toDouble();
          if (lat != null && lng != null) onCameraMove?.call(LatLng(lat, lng));
          break;
        case MapBridgeProtocol.eventCameraIdle:
          onCameraIdle?.call();
          break;
        case MapBridgeProtocol.eventCameraMoveStarted:
          onCameraMoveStarted?.call();
          break;
        case MapBridgeProtocol.eventMapReady:
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
    return _sendCommand(MapBridgeProtocol.actionInitialize, {
      'lat': lat,
      'lng': lng,
      'zoom': zoom,
      'mapType': mapType,
      'mapStyleJson': ?mapStyleJson,
    });
  }

  Future<void> setCameraPosition({
    required double lat,
    required double lng,
    required double zoom,
  }) {
    return _sendCommand(
      MapBridgeProtocol.actionSetCamera,
      {'lat': lat, 'lng': lng, 'zoom': zoom},
    );
  }

  Future<void> setMapType(String mapType) {
    return _sendCommand(
      MapBridgeProtocol.actionSetMapType,
      {'type': mapType},
    );
  }

  /// Desenha (ou move) o indicador "minha localização". Sem [lat]/[lng] o
  /// indicador é removido — o JS não tem equivalente ao `myLocationEnabled`
  /// nativo, então a posição é empurrada daqui.
  ///
  /// [accuracy] em metros desenha o círculo de precisão em volta do ponto.
  Future<void> setMyLocation({double? lat, double? lng, double? accuracy}) {
    return _sendCommand(MapBridgeProtocol.actionSetMyLocation, {
      'visible': lat != null && lng != null,
      'lat': lat,
      'lng': lng,
      'accuracy': accuracy,
    });
  }
}
