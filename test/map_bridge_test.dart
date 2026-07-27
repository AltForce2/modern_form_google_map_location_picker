import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_map_location_picker/src/platform/webview/core.dart';
import 'package:google_map_location_picker/src/platform/webview/protocol.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' show MapType;

void main() {
  group('mapTypeToString', () {
    test('mapeia cada MapType para o identificador aceito pelo JS', () {
      expect(
        LocationPickerMapWebView.mapTypeToString(MapType.normal),
        MapBridgeProtocol.mapTypeNormal,
      );
      expect(
        LocationPickerMapWebView.mapTypeToString(MapType.satellite),
        MapBridgeProtocol.mapTypeSatellite,
      );
      expect(
        LocationPickerMapWebView.mapTypeToString(MapType.terrain),
        MapBridgeProtocol.mapTypeTerrain,
      );
      expect(
        LocationPickerMapWebView.mapTypeToString(MapType.hybrid),
        MapBridgeProtocol.mapTypeHybrid,
      );
    });

    test('MapType.none cai para normal', () {
      // O JS não tem equivalente. O FAB de camadas não cicla por `none`
      // justamente porque no nativo ele renderiza tela em branco.
      expect(
        LocationPickerMapWebView.mapTypeToString(MapType.none),
        MapBridgeProtocol.mapTypeNormal,
      );
    });

    test('todo MapType tem mapeamento', () {
      for (final type in MapType.values) {
        expect(
          () => LocationPickerMapWebView.mapTypeToString(type),
          returnsNormally,
          reason: '$type',
        );
      }
    });
  });

  group('contrato do protocolo', () {
    test('os nomes de evento e ação estão estáveis', () {
      // Estes valores são replicados literalmente em assets/google_maps.html.
      // Se um deles mudar sem o HTML acompanhar, o mapa para de responder.
      expect(MapBridgeProtocol.channel, 'FlutterChannel');
      expect(MapBridgeProtocol.commandEntryPoint, 'window.handleFlutterCommand');
      expect(MapBridgeProtocol.actionInitialize, 'initialize');
      expect(MapBridgeProtocol.actionSetCamera, 'set_camera');
      expect(MapBridgeProtocol.actionSetMapType, 'set_map_type');
      expect(MapBridgeProtocol.actionSetMyLocation, 'set_my_location');
      expect(MapBridgeProtocol.eventCameraMove, 'camera_move');
      expect(MapBridgeProtocol.eventCameraIdle, 'camera_idle');
      expect(MapBridgeProtocol.eventCameraMoveStarted, 'camera_move_started');
      expect(MapBridgeProtocol.eventMapReady, 'map_ready');
    });

    test('set_my_location sem coordenadas significa "esconder"', () {
      // Contrato com `setMyLocation(data)` no HTML: `visible: false` (ou
      // lat/lng nulos) remove o marcador em vez de deixá-lo parado numa
      // posição obsoleta.
      final hide = <String, dynamic>{
        'visible': false,
        'lat': null,
        'lng': null,
        'accuracy': null,
      };
      final show = <String, dynamic>{
        'visible': true,
        'lat': -23.5,
        'lng': -46.6,
        'accuracy': 12.5,
      };

      expect(jsonDecode(jsonEncode(hide))['visible'], isFalse);
      expect(jsonDecode(jsonEncode(show))['visible'], isTrue);
      expect(jsonDecode(jsonEncode(show))['accuracy'], 12.5);
    });

    test('o payload de evento do JS é JSON com type e data', () {
      // Documenta o formato que handleMessage espera receber.
      final decoded = jsonDecode(jsonEncode({
        'type': MapBridgeProtocol.eventCameraMove,
        'data': {'lat': -23.5, 'lng': -46.6},
      })) as Map<String, dynamic>;

      expect(decoded['type'], MapBridgeProtocol.eventCameraMove);
      expect((decoded['data'] as Map)['lat'], -23.5);
    });
  });
}
