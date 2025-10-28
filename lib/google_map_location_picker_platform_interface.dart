import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'google_map_location_picker_method_channel.dart';

abstract class GoogleMapLocationPickerPlatform extends PlatformInterface {
  /// Constructs a GoogleMapLocationPickerPlatform.
  GoogleMapLocationPickerPlatform() : super(token: _token);

  static final Object _token = Object();

  static GoogleMapLocationPickerPlatform _instance = MethodChannelGoogleMapLocationPicker();

  /// The default instance of [GoogleMapLocationPickerPlatform] to use.
  ///
  /// Defaults to [MethodChannelGoogleMapLocationPicker].
  static GoogleMapLocationPickerPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [GoogleMapLocationPickerPlatform] when
  /// they register themselves.
  static set instance(GoogleMapLocationPickerPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
