import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_map_location_picker/src/model/location_result.dart';
import 'package:google_map_location_picker/src/api/google_location_picker_api.dart';
import 'package:google_map_location_picker/src/utils/location_utils.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' show LatLng;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Resposta mínima de um `geocode/json` bem-sucedido.
String _okBody({String address = 'Rua Teste, 100'}) => jsonEncode({
      'status': 'OK',
      'results': [
        {
          'formatted_address': address,
          'place_id': 'place-123',
          'geometry': {
            'location': {'lat': -23.5505, 'lng': -46.6333}
          },
          'address_components': [
            {
              'long_name': '100',
              'short_name': '100',
              'types': ['street_number']
            },
            {
              'long_name': 'Rua Teste',
              'short_name': 'R. Teste',
              'types': ['route']
            },
            {
              'long_name': '01310-100',
              'short_name': '01310-100',
              'types': ['postal_code']
            },
          ],
        }
      ],
    });

void main() {
  const LatLng saoPaulo = LatLng(-23.5505, -46.6333);
  final http.Client realClient = GoogleLocationPickerApi.httpClient;

  setUp(LocationPickerUtils.clearGeocodeCache);

  tearDown(() {
    GoogleLocationPickerApi.httpClient = realClient;
    LocationPickerUtils.clearGeocodeCache();
  });

  group('reverseGeocode — cache', () {
    test('a mesma coordenada custa uma única requisição', () async {
      int calls = 0;
      GoogleLocationPickerApi.httpClient = MockClient((request) async {
        calls++;
        return http.Response(_okBody(), 200);
      });

      final first = await LocationPickerUtils.reverseGeocode(
        apiKey: 'k',
        latLng: saoPaulo,
      );
      final second = await LocationPickerUtils.reverseGeocode(
        apiKey: 'k',
        latLng: saoPaulo,
      );

      expect(calls, 1, reason: 'a segunda chamada deve ser cache hit');
      expect(first?.address, 'Rua Teste, 100');
      expect(second?.address, 'Rua Teste, 100');
    });

    test('single-flight: chamadas concorrentes compartilham a requisição',
        () async {
      // Este é o caso que gerava a fatura: os caminhos do picker disparavam
      // quase ao mesmo tempo, antes de qualquer um preencher o cache.
      int calls = 0;
      GoogleLocationPickerApi.httpClient = MockClient((request) async {
        calls++;
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return http.Response(_okBody(), 200);
      });

      final results = await Future.wait<LocationResult?>([
        LocationPickerUtils.reverseGeocode(apiKey: 'k', latLng: saoPaulo),
        LocationPickerUtils.reverseGeocode(apiKey: 'k', latLng: saoPaulo),
        LocationPickerUtils.reverseGeocode(apiKey: 'k', latLng: saoPaulo),
      ]);

      expect(calls, 1);
      expect(results.every((r) => r?.address == 'Rua Teste, 100'), isTrue);
    });

    test('coordenadas a ~1 m compartilham a mesma chave', () async {
      int calls = 0;
      GoogleLocationPickerApi.httpClient = MockClient((request) async {
        calls++;
        return http.Response(_okBody(), 200);
      });

      await LocationPickerUtils.reverseGeocode(apiKey: 'k', latLng: saoPaulo);
      // 6ª casa decimal ≈ 0,1 m — abaixo da precisão de 5 casas da chave.
      await LocationPickerUtils.reverseGeocode(
        apiKey: 'k',
        latLng: const LatLng(-23.5505004, -46.6333004),
      );

      expect(calls, 1);
    });

    test('idiomas diferentes não compartilham cache', () async {
      int calls = 0;
      GoogleLocationPickerApi.httpClient = MockClient((request) async {
        calls++;
        return http.Response(_okBody(), 200);
      });

      await LocationPickerUtils.reverseGeocode(
          apiKey: 'k', latLng: saoPaulo, language: 'pt-BR');
      await LocationPickerUtils.reverseGeocode(
          apiKey: 'k', latLng: saoPaulo, language: 'en');

      expect(calls, 2, reason: 'a resposta muda conforme o idioma');
    });

    test('falha não é cacheada — a próxima tentativa refaz a chamada',
        () async {
      int calls = 0;
      GoogleLocationPickerApi.httpClient = MockClient((request) async {
        calls++;
        // Primeira falha, segunda sucede.
        if (calls == 1) return http.Response('boom', 500);
        return http.Response(_okBody(), 200);
      });

      expect(
        await LocationPickerUtils.reverseGeocode(apiKey: 'k', latLng: saoPaulo),
        isNull,
      );
      expect(
        (await LocationPickerUtils.reverseGeocode(
                apiKey: 'k', latLng: saoPaulo))
            ?.address,
        'Rua Teste, 100',
      );
      expect(calls, 2);
    });
  });

  group('reverseGeocode — tratamento de resposta', () {
    test('devolve null em status != OK sem estourar', () async {
      GoogleLocationPickerApi.httpClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'status': 'OVER_QUERY_LIMIT',
            'error_message': 'quota',
            'results': <dynamic>[],
          }),
          200,
        );
      });

      expect(
        await LocationPickerUtils.reverseGeocode(apiKey: 'k', latLng: saoPaulo),
        isNull,
      );
    });

    test('devolve null em ZERO_RESULTS (results vazio)', () async {
      GoogleLocationPickerApi.httpClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'status': 'ZERO_RESULTS', 'results': <dynamic>[]}),
          200,
        );
      });

      expect(
        await LocationPickerUtils.reverseGeocode(apiKey: 'k', latLng: saoPaulo),
        isNull,
      );
    });

    test('devolve null em corpo não-JSON', () async {
      GoogleLocationPickerApi.httpClient = MockClient((request) async {
        return http.Response('<html>502 Bad Gateway</html>', 200);
      });

      expect(
        await LocationPickerUtils.reverseGeocode(apiKey: 'k', latLng: saoPaulo),
        isNull,
      );
    });

    test('monta a query com os parâmetros escapados', () async {
      Uri? captured;
      GoogleLocationPickerApi.httpClient = MockClient((request) async {
        captured = request.url;
        return http.Response(_okBody(), 200);
      });

      await LocationPickerUtils.reverseGeocode(
        apiKey: 'chave com espaço&x',
        latLng: saoPaulo,
        language: 'pt-BR',
      );

      expect(captured, isNotNull);
      expect(captured!.path, '/maps/api/geocode/json');
      expect(captured!.queryParameters['latlng'], '-23.5505,-46.6333');
      expect(captured!.queryParameters['language'], 'pt-BR');
      // O valor decodificado bate, ou seja, o escaping foi aplicado na URL.
      expect(captured!.queryParameters['key'], 'chave com espaço&x');
    });

    test('preenche locationAddress a partir de address_components', () async {
      GoogleLocationPickerApi.httpClient = MockClient((request) async {
        return http.Response(_okBody(), 200);
      });

      final result =
          await LocationPickerUtils.reverseGeocode(apiKey: 'k', latLng: saoPaulo);

      expect(result?.locationAddress?.streetNumber, '100');
      expect(result?.locationAddress?.route, 'Rua Teste');
      expect(result?.locationAddress?.postalCode, '01310-100');
    });
  });

  group('forwardGeocode', () {
    test('cacheia por endereço normalizado', () async {
      int calls = 0;
      GoogleLocationPickerApi.httpClient = MockClient((request) async {
        calls++;
        return http.Response(_okBody(), 200);
      });

      await LocationPickerUtils.forwardGeocode(
          apiKey: 'k', address: 'Rua Teste, 100');
      await LocationPickerUtils.forwardGeocode(
          apiKey: 'k', address: '  RUA TESTE, 100  ');

      expect(calls, 1);
    });

    test('extrai latLng de geometry.location', () async {
      GoogleLocationPickerApi.httpClient = MockClient((request) async {
        return http.Response(_okBody(), 200);
      });

      final result = await LocationPickerUtils.forwardGeocode(
        apiKey: 'k',
        address: 'Rua Teste, 100',
      );

      expect(result?.latLng?.latitude, closeTo(-23.5505, 1e-9));
      expect(result?.latLng?.longitude, closeTo(-46.6333, 1e-9));
    });

    test('endereço vazio não gera requisição', () async {
      int calls = 0;
      GoogleLocationPickerApi.httpClient = MockClient((request) async {
        calls++;
        return http.Response(_okBody(), 200);
      });

      expect(
        await LocationPickerUtils.forwardGeocode(apiKey: 'k', address: '   '),
        isNull,
      );
      expect(calls, 0);
    });
  });
}
