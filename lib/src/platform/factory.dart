import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

import 'interface.dart';
import 'native/core.dart';
import 'webview/core.dart';

class LocationPickerMapFactory {
  static LocationPickerMapInterface create({required String apiKey}) {
    if (_isDesktop()) {
      debugPrint('LocationPicker: Google Maps via WebView (Desktop)');
      return LocationPickerMapWebView(apiKey: apiKey);
    }
    debugPrint('LocationPicker: Google Maps nativo (Mobile)');
    return LocationPickerMapNative();
  }

  static bool _isDesktop() {
    if (kIsWeb) return false;
    try {
      return Platform.isWindows || Platform.isMacOS || Platform.isLinux;
    } catch (_) {
      return false;
    }
  }
}
