import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../interface.dart';

class LocationPickerMapNative implements LocationPickerMapInterface {
  final Completer<GoogleMapController> _completer = Completer<GoogleMapController>();
  GoogleMapController? _controller;

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
  }) {
    return GoogleMap(
      myLocationButtonEnabled: false,
      initialCameraPosition: CameraPosition(target: initialCenter, zoom: initialZoom),
      style: mapStyleJson,
      mapType: mapType,
      myLocationEnabled: myLocationEnabled,
      onMapCreated: (controller) {
        _controller = controller;
        if (!_completer.isCompleted) _completer.complete(controller);
        onMapReady();
      },
      onCameraMove: (position) => onCameraMove(position.target),
      onCameraIdle: onCameraIdle,
      onCameraMoveStarted: onCameraMoveStarted,
    );
  }

  @override
  Future<void> animateCamera(LatLng target, double zoom) async {
    final controller = _controller ?? await _completer.future;
    await controller.animateCamera(
      CameraUpdate.newCameraPosition(CameraPosition(target: target, zoom: zoom)),
    );
  }

  @override
  Future<void> setMapType(MapType mapType) async {}

  @override
  void dispose() {
    _controller?.dispose();
    _controller = null;
  }
}
