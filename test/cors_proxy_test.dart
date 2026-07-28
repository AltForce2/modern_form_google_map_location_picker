import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_map_location_picker/src/api/google_location_picker_api.dart';
import 'package:google_map_location_picker/src/utils/location_utils.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' show LatLng;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

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

  test('a querystring é anexada sem deturpar uma URL proxiada', () {
    // O `_get` monta a URL com `Uri.parse(base).replace(queryParameters:)`.
    // Remontar a partir de scheme/host/path perderia o "https://" que fica
    // embutido no path quando o endpoint aponta para um proxy.
    const String proxy = 'https://proxy.altfor.com.br/';
    final Uri proxied = Uri.parse(
      '${proxy}https://maps.googleapis.com/maps/api/place/autocomplete/json',
    ).replace(queryParameters: {'input': 'Avenida Ipê', 'key': 'k'});

    expect(
      proxied.toString(),
      startsWith('${proxy}https://maps.googleapis.com/maps/api/place/'
          'autocomplete/json?'),
    );
    expect(proxied.queryParameters['input'], 'Avenida Ipê');
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

  group('roteamento das chamadas REST', () {
    // O `corsProxy` substituiu os antigos `autoCompleteWebUrl`/`detailsWebUrl`,
    // que o app sobrescrevia com a URL já proxiada. Estes testes travam o
    // roteamento para que ninguém volte a tratá-lo como configuração morta.
    late List<Uri> requests;

    setUp(() {
      requests = [];
      LocationPickerUtils.clearGeocodeCache();
      GoogleLocationPickerApi.httpClient = MockClient((request) async {
        requests.add(request.url);
        return http.Response(
          jsonEncode({'status': 'OK', 'results': <dynamic>[]}),
          200,
        );
      });
    });

    tearDown(LocationPickerUtils.clearGeocodeCache);

    test('fora do web a URL sai direta, mesmo com proxy configurado', () async {
      // A suíte roda na VM, então kIsWeb é false — é exatamente o caminho
      // mobile/desktop, onde não há CORS e o proxy só adicionaria um salto.
      GoogleLocationPickerApi.corsProxy = 'https://proxy.exemplo.com/';

      await const GoogleLocationPickerApi().reverseGeocode(
        apiKey: 'k',
        latLng: const LatLng(-23.5505, -46.6333),
        language: 'pt-BR',
      );

      expect(requests.single.host, 'maps.googleapis.com');
      expect(requests.single.path, '/maps/api/geocode/json');
    });

    test('a querystring completa sobrevive ao roteamento', () async {
      GoogleLocationPickerApi.corsProxy = '';

      await const GoogleLocationPickerApi().autocomplete(
        apiKey: 'k',
        input: 'Avenida Ipê',
        language: 'pt-BR',
        sessionToken: 'sess-1',
      );

      final q = requests.single.queryParameters;
      expect(q['input'], 'Avenida Ipê');
      expect(q['sessiontoken'], 'sess-1');
      expect(q['language'], 'pt-BR');
    });
  });
}
