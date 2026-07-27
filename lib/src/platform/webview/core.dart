import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_map_location_picker/generated/l10n.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' show LatLng, MapType;

import '../interface.dart';
import 'bridge.dart';
import 'protocol.dart';

class LocationPickerMapWebView implements LocationPickerMapInterface {
  final String apiKey;
  LocationPickerMapWebView({required this.apiKey});

  LocationPickerMapBridge? _bridge;
  bool _mapReady = false;
  bool _mapInitDispatched = false;
  Future<String>? _htmlFuture;

  LatLng? _pendingInitialCenter;
  double? _pendingInitialZoom;
  MapType _currentMapType = MapType.normal;
  String? _mapStyleJson;

  // animateCamera chamado antes do mapa ficar pronto fica enfileirado aqui
  // e é aplicado em onMapReady.
  LatLng? _pendingAnimateTarget;
  double? _pendingAnimateZoom;

  ValueChanged<LatLng>? _onCameraMove;
  VoidCallback? _onCameraIdle;
  VoidCallback? _onCameraMoveStarted;
  VoidCallback? _onMapReady;

  // O Maps JS API não tem equivalente ao `myLocationEnabled` do SDK nativo:
  // lá o próprio mapa rastreia e desenha o ponto azul. Aqui assinamos o
  // geolocator e empurramos a posição para o JS, para o comportamento ficar
  // igual nas duas plataformas.
  bool _myLocationEnabled = false;
  StreamSubscription<Position>? _positionSubscription;
  Position? _lastKnownPosition;

  @override
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
  }) {
    // Só atualiza os "pending" initial enquanto o mapa ainda não foi inicializado.
    // Depois disso, qualquer mudança de câmera deve passar por animateCamera,
    // não por re-inicialização (que descartaria a posição atual do usuário).
    if (!_mapInitDispatched) {
      _pendingInitialCenter = initialCenter;
      _pendingInitialZoom = initialZoom;
    }
    _currentMapType = mapType;
    _mapStyleJson = mapStyleJson;
    _onCameraMove = onCameraMove;
    _onCameraIdle = onCameraIdle;
    _onCameraMoveStarted = onCameraMoveStarted;
    _onMapReady = onMapReady;

    if (myLocationEnabled != _myLocationEnabled) {
      _myLocationEnabled = myLocationEnabled;
      _syncMyLocationTracking();
    }

    _htmlFuture ??= _loadHtml();

    return FutureBuilder<String>(
      future: _htmlFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                S.of(context)?.server_error ?? 'Unable to load the map',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        return InAppWebView(
          key: const ValueKey('location_picker_webview'),
          initialData: InAppWebViewInitialData(
            data: snapshot.data!,
            baseUrl: WebUri('https://localhost/'),
          ),
          initialSettings: InAppWebViewSettings(
            javaScriptEnabled: true,
            transparentBackground: false,
            disableContextMenu: true,
            allowFileAccess: true,
            allowContentAccess: true,
          ),
          gestureRecognizers: gestureRecognizers,
          onWebViewCreated: (c) {
            _bridge = LocationPickerMapBridge(c);
            _wireBridgeCallbacks();
            c.addJavaScriptHandler(
              handlerName: MapBridgeProtocol.channel,
              callback: (args) {
                if (args.isNotEmpty) {
                  _bridge!.handleMessage(args[0].toString());
                }
              },
            );
          },
          onLoadStop: (c, url) async {
            if (_mapInitDispatched) return;
            final center = _pendingInitialCenter;
            final zoom = _pendingInitialZoom;
            if (center == null || zoom == null) return;
            _mapInitDispatched = true;
            await _bridge?.initializeMap(
              lat: center.latitude,
              lng: center.longitude,
              zoom: zoom,
              mapType: mapTypeToString(_currentMapType),
              mapStyleJson: _mapStyleJson,
            );
          },
          onConsoleMessage: (controller, consoleMessage) {
            debugPrint('LocationPicker JS: ${consoleMessage.message}');
          },
        );
      },
    );
  }

  void _wireBridgeCallbacks() {
    final b = _bridge;
    if (b == null) return;
    b.onCameraMove = (latLng) => _onCameraMove?.call(latLng);
    b.onCameraIdle = () => _onCameraIdle?.call();
    b.onCameraMoveStarted = () => _onCameraMoveStarted?.call();
    b.onMapReady = () {
      _mapReady = true;
      _flushPendingAnimate();
      // A posição pode ter chegado antes do mapa ficar pronto; nesse caso o
      // push foi descartado e precisa ser refeito agora.
      _pushMyLocation();
      _onMapReady?.call();
    };
  }

  /// Liga ou desliga o rastreamento conforme [_myLocationEnabled].
  void _syncMyLocationTracking() {
    if (_myLocationEnabled) {
      _startMyLocationTracking();
    } else {
      _stopMyLocationTracking();
    }
  }

  void _startMyLocationTracking() {
    if (_positionSubscription != null) return;

    // A permissão já é solicitada pelo `MapPicker` antes de chegar aqui; se
    // ainda não houver, o stream emite erro e simplesmente não desenhamos nada.
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen(
      (Position position) {
        _lastKnownPosition = position;
        _pushMyLocation();
      },
      onError: (Object error) {
        debugPrint('LocationPicker myLocation stream error: $error');
      },
    );
  }

  void _stopMyLocationTracking() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _lastKnownPosition = null;
    _pushMyLocation();
  }

  /// Envia a posição corrente ao JS. Sem posição (ou com o indicador
  /// desligado) manda o comando sem coordenadas, o que remove o marcador.
  void _pushMyLocation() {
    if (!_mapReady) return;

    final Position? position = _lastKnownPosition;
    if (!_myLocationEnabled || position == null) {
      _bridge?.setMyLocation();
      return;
    }

    _bridge?.setMyLocation(
      lat: position.latitude,
      lng: position.longitude,
      accuracy: position.accuracy,
    );
  }

  void _flushPendingAnimate() {
    final target = _pendingAnimateTarget;
    final zoom = _pendingAnimateZoom;
    if (target == null || zoom == null) return;
    _pendingAnimateTarget = null;
    _pendingAnimateZoom = null;
    _bridge?.setCameraPosition(
      lat: target.latitude,
      lng: target.longitude,
      zoom: zoom,
    );
  }

  Future<String> _loadHtml() async {
    final raw = await rootBundle.loadString(
      'packages/google_map_location_picker/assets/google_maps.html',
    );
    return raw.replaceAll('{{API_KEY}}', apiKey);
  }

  @override
  Future<void> animateCamera(LatLng target, double zoom) async {
    if (!_mapReady) {
      // Caso (a): mapa ainda nem inicializou — sobrescreve o initial para que
      // o initializeMap parta dessa posição (evita "piscar" em initialCenter).
      if (!_mapInitDispatched) {
        _pendingInitialCenter = target;
        _pendingInitialZoom = zoom;
      }
      // Caso (b): initializeMap já foi enviado mas o map_ready ainda não voltou.
      // Enfileira para aplicar assim que map_ready chegar.
      _pendingAnimateTarget = target;
      _pendingAnimateZoom = zoom;
      return;
    }
    await _bridge?.setCameraPosition(
      lat: target.latitude,
      lng: target.longitude,
      zoom: zoom,
    );
  }

  @override
  Future<void> setMapType(MapType mapType) async {
    _currentMapType = mapType;
    if (!_mapReady) return;
    await _bridge?.setMapType(mapTypeToString(mapType));
  }

  @override
  void dispose() {
    // O handler JS registrado em onWebViewCreated segura uma closure com este
    // adapter; sem removê-lo o controller e o bridge sobrevivem ao unmount.
    _bridge?.webViewController
        .removeJavaScriptHandler(handlerName: MapBridgeProtocol.channel);

    _positionSubscription?.cancel();
    _positionSubscription = null;
    _lastKnownPosition = null;
    _myLocationEnabled = false;

    _mapReady = false;
    _mapInitDispatched = false;
    _bridge = null;
    _htmlFuture = null;
    _pendingAnimateTarget = null;
    _pendingAnimateZoom = null;
  }

  @visibleForTesting
  static String mapTypeToString(MapType type) {
    switch (type) {
      case MapType.satellite:
        return MapBridgeProtocol.mapTypeSatellite;
      case MapType.terrain:
        return MapBridgeProtocol.mapTypeTerrain;
      case MapType.hybrid:
        return MapBridgeProtocol.mapTypeHybrid;
      case MapType.normal:
      case MapType.none:
        return MapBridgeProtocol.mapTypeNormal;
    }
  }
}
