import 'package:flutter_test/flutter_test.dart';
import 'package:google_map_location_picker/google_map_location_picker_platform_interface.dart';
import 'package:google_map_location_picker/google_map_location_picker_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockGoogleMapLocationPickerPlatform
    with MockPlatformInterfaceMixin
    implements GoogleMapLocationPickerPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}
void main() {
  final GoogleMapLocationPickerPlatform initialPlatform = GoogleMapLocationPickerPlatform.instance;

  test('$MethodChannelGoogleMapLocationPicker is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelGoogleMapLocationPicker>());
  });
  test('getPlatformVersion returns non-empty string', () async {
    final version = await GoogleMapLocationPickerPlatform.instance.getPlatformVersion();
    expect(version?.isNotEmpty, true);
  });

}
