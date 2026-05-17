import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' show LatLng, MapType;

import '../interface.dart';
import 'bridge.dart';

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
                'Erro ao carregar o mapa: ${snapshot.error}',
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
              handlerName: 'FlutterChannel',
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
              mapType: _mapTypeToString(_currentMapType),
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
      _onMapReady?.call();
    };
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
    await _bridge?.setMapType(_mapTypeToString(mapType));
  }

  @override
  void dispose() {
    _mapReady = false;
    _mapInitDispatched = false;
    _bridge = null;
    _htmlFuture = null;
    _pendingAnimateTarget = null;
    _pendingAnimateZoom = null;
  }

  String _mapTypeToString(MapType type) {
    switch (type) {
      case MapType.satellite:
        return 'satellite';
      case MapType.terrain:
        return 'terrain';
      case MapType.hybrid:
        return 'hybrid';
      case MapType.normal:
      case MapType.none:
        return 'normal';
    }
  }
}
