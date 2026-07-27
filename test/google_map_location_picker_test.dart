import 'package:flutter_test/flutter_test.dart';
import 'package:google_map_location_picker/google_map_location_picker_method_channel.dart';
import 'package:google_map_location_picker/google_map_location_picker_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockGoogleMapLocationPickerPlatform
    with MockPlatformInterfaceMixin
    implements GoogleMapLocationPickerPlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  // Sem isto o acesso ao MethodChannel falha com
  // "Binding has not yet been initialized".
  TestWidgetsFlutterBinding.ensureInitialized();

  final GoogleMapLocationPickerPlatform initialPlatform =
      GoogleMapLocationPickerPlatform.instance;

  test('$MethodChannelGoogleMapLocationPicker is the default instance', () {
    expect(
      initialPlatform,
      isInstanceOf<MethodChannelGoogleMapLocationPicker>(),
    );
  });

  test('getPlatformVersion returns the mocked value', () async {
    // O teste original declarava o mock mas nunca o instalava, então batia no
    // MethodChannel real e falhava.
    final mock = MockGoogleMapLocationPickerPlatform();
    GoogleMapLocationPickerPlatform.instance = mock;
    addTearDown(() => GoogleMapLocationPickerPlatform.instance = initialPlatform);

    final version =
        await GoogleMapLocationPickerPlatform.instance.getPlatformVersion();
    expect(version, '42');
  });
}
