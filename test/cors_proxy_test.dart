import 'package:flutter_test/flutter_test.dart';
import 'package:google_map_location_picker/src/api/google_location_picker_api.dart';
import 'package:google_map_location_picker/src/utils/location_utils.dart';
import 'package:http/http.dart' as http;

void main() {
  final http.Client realClient = GoogleLocationPickerApi.httpClient;

  setUp(() => GoogleLocationPickerApi.corsProxy = '');

  tearDown(() {
    GoogleLocationPickerApi.httpClient = realClient;
    GoogleLocationPickerApi.corsProxy = '';
  });

  test('corsProxy nasce vazio (sem proxy é o comportamento padrão)', () {
    expect(GoogleLocationPickerApi.corsProxy, isEmpty);
  });

  test('o atalho depreciado em LocationPickerUtils continua funcionando', () {
    // O app configura via InitHelper; mover o campo não pode quebrá-lo.
    // ignore: deprecated_member_use_from_same_package
    LocationPickerUtils.corsProxy = 'https://proxy.exemplo.com/';

    expect(
      GoogleLocationPickerApi.corsProxy,
      'https://proxy.exemplo.com/',
      reason: 'o setter antigo deve escrever no novo campo',
    );
    // ignore: deprecated_member_use_from_same_package
    expect(LocationPickerUtils.corsProxy, 'https://proxy.exemplo.com/');
  });

  test('links longos são resolvidos sem rede, mesmo com proxy configurado',
      () async {
    GoogleLocationPickerApi.corsProxy = 'https://proxy.exemplo.com/';
    GoogleLocationPickerApi.httpClient = http.Client();

    // Coords já estão na própria URL: nenhuma requisição deve sair.
    final result = await LocationPickerUtils.resolveGoogleMapsUrl(
      'https://www.google.com/maps/search/-24.737106,+-53.740050?entry=tts',
    );

    expect(result?.latitude, closeTo(-24.737106, 1e-6));
    expect(result?.longitude, closeTo(-53.740050, 1e-6));
  });

  test('URL que não é do Google Maps devolve null sem tocar na rede', () async {
    final result =
        await LocationPickerUtils.resolveGoogleMapsUrl('https://example.com');
    expect(result, isNull);
  });
}
