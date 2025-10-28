import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'google_map_location_picker_platform_interface.dart';

/// An implementation of [GoogleMapLocationPickerPlatform] that uses method channels.
class MethodChannelGoogleMapLocationPicker extends GoogleMapLocationPickerPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('google_map_location_picker');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}
