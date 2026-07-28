import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_map_location_picker/src/api/backend_location_picker_api.dart';
import 'package:google_map_location_picker/src/api/google_location_picker_api.dart';
import 'package:google_map_location_picker/src/api/location_picker_api.dart';
import 'package:google_map_location_picker/src/utils/location_utils.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' show LatLng;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Objeto de endereço canônico devolvido pela API.
Map<String, dynamic> _canonical({
  double latitude = -25.2521,
  double longitude = -52.0215,
  bool withLanguage = true,
}) =>
    {
      'latitude': latitude,
      'longitude': longitude,
      if (withLanguage) 'language': 'pt-BR',
      'formattedAddress':
          'R. XV de Novembro, 1200 - Centro, Turvo - PR, 85150-000',
      'placeId': 'ChIJabc',
      'street': 'R. XV de Novembro',
      'number': '1200',
      'neighborhood': 'Centro',
      'city': 'Turvo',
      'state': 'Paraná',
      'stateCode': 'PR',
      'country': 'Brasil',
      'countryCode': 'BR',
      'cep': '85150-000',
      'locationType': 'ROOFTOP',
    };

void main() {
  const LatLng ponto = LatLng(-25.25208883, -52.02154155);
  late List<Uri> requests;
  late List<Map<String, String>> sentHeaders;

  BackendLocationPickerApi apiWith(
    Future<http.Response> Function(http.Request) handler, {
    Future<Map<String, String>> Function()? headers,
  }) {
    return BackendLocationPickerApi(
      baseUrl: 'https://api.exemplo.com/',
      headers: headers ?? () async => {'authorization': 'token-123'},
      client: MockClient((request) async {
        requests.add(request.url);
        sentHeaders.add(request.headers);
        return handler(request);
      }),
    );
  }

  setUp(() {
    requests = [];
    sentHeaders = [];
    LocationPickerUtils.clearGeocodeCache();
  });

  tearDown(() {
    LocationPickerApi.resetToDefault();
    LocationPickerUtils.clearGeocodeCache();
  });

  group('reverseGeocode', () {
    test('mapeia o objeto canônico para LocationResult/LocationAddress',
        () async {
      final api = apiWith((_) async => http.Response(
            jsonEncode(_canonical()),
            200,
          ));

      final result = await api.reverseGeocode(
        apiKey: 'ignorada',
        latLng: ponto,
        language: 'pt-BR',
      );

      expect(result, isNotNull);
      expect(result!.address,
          'R. XV de Novembro, 1200 - Centro, Turvo - PR, 85150-000');
      expect(result.placeId, 'ChIJabc');

      final address = result.locationAddress!;
      expect(address.route, 'R. XV de Novembro');
      expect(address.streetNumber, '1200');
      expect(address.sublocalityLevel1, 'Centro');
      expect(address.administrativeAreaLevel2, 'Turvo');
      expect(address.administrativeAreaLevel1, 'Paraná');
      expect(address.stateCode, 'PR');
      expect(address.country, 'Brasil');
      expect(address.countryCode, 'BR');
      expect(address.postalCode, '85150-000');
      expect(address.locationType, 'ROOFTOP');
    });

    test('devolve a coordenada de ENTRADA, não a arredondada da resposta',
        () async {
      // A API responde com a coordenada do grid (~11 m). Usá-la deslocaria o
      // pin do ponto que o usuário marcou.
      final api = apiWith((_) async => http.Response(
            jsonEncode(_canonical(latitude: -25.2521, longitude: -52.0215)),
            200,
          ));

      final result = await api.reverseGeocode(
        apiKey: 'k',
        latLng: ponto,
        language: 'pt-BR',
      );

      expect(result!.latLng, ponto);
      expect(result.latLng!.latitude, -25.25208883);
    });

    test('404 vira null, sem lançar', () async {
      final api = apiWith((_) async => http.Response(
            jsonEncode({'error': 'Nenhum endereço encontrado para a coordenada.'}),
            404,
          ));

      expect(
        await api.reverseGeocode(apiKey: 'k', latLng: ponto, language: 'pt-BR'),
        isNull,
      );
    });

    test('resposta sem "language" não quebra', () async {
      // No cache hit o servidor omite a chave — e a maioria das respostas vem
      // do cache.
      final api = apiWith((_) async => http.Response(
            jsonEncode(_canonical(withLanguage: false)),
            200,
          ));

      final result = await api.reverseGeocode(
        apiKey: 'k',
        latLng: ponto,
        language: 'pt-BR',
      );

      expect(result?.placeId, 'ChIJabc');
    });

    test('campos de endereço nulos são tolerados', () async {
      final api = apiWith((_) async => http.Response(
            jsonEncode({
              'latitude': -25.2521,
              'longitude': -52.0215,
              'formattedAddress': null,
              'placeId': null,
              'street': null,
              'number': null,
              'neighborhood': null,
              'city': 'Turvo',
              'state': null,
              'cep': null,
            }),
            200,
          ));

      final result = await api.reverseGeocode(
        apiKey: 'k',
        latLng: ponto,
        language: 'pt-BR',
      );

      expect(result, isNotNull);
      expect(result!.address, isNull);
      expect(result.locationAddress?.administrativeAreaLevel2, 'Turvo');
      expect(result.locationAddress?.route, isNull);
    });

    test('monta a URL e envia os headers do callback', () async {
      final api = apiWith((_) async => http.Response(
            jsonEncode(_canonical()),
            200,
          ));

      await api.reverseGeocode(apiKey: 'k', latLng: ponto, language: 'pt-BR');

      final uri = requests.single;
      // baseUrl com barra final não pode virar `//geocode`.
      expect(uri.path, '/geocode/reverse');
      expect(uri.queryParameters['lat'], '-25.25208883');
      expect(uri.queryParameters['lng'], '-52.02154155');
      expect(uri.queryParameters['language'], 'pt-BR');
      expect(sentHeaders.single['authorization'], 'token-123');
    });
  });

  group('erros que não podem lançar', () {
    test('401 do guard vira null', () async {
      final api = apiWith((_) async => http.Response(
            jsonEncode({
              'error': 'notAuthenticated',
              'message': 'Você não está autenticado',
            }),
            401,
          ));

      expect(
        await api.reverseGeocode(apiKey: 'k', latLng: ponto, language: 'pt-BR'),
        isNull,
      );
    });

    test('500 vira null', () async {
      final api = apiWith((_) async => http.Response('boom', 500));
      expect(
        await api.reverseGeocode(apiKey: 'k', latLng: ponto, language: 'pt-BR'),
        isNull,
      );
    });

    test('corpo não-JSON vira null', () async {
      final api = apiWith(
          (_) async => http.Response('<html>502</html>', 200));
      expect(
        await api.reverseGeocode(apiKey: 'k', latLng: ponto, language: 'pt-BR'),
        isNull,
      );
    });

    test('falha ao montar headers vira null, não exceção', () async {
      // Renovação de token que falha não pode derrubar o picker.
      final api = apiWith(
        (_) async => http.Response(jsonEncode(_canonical()), 200),
        headers: () async => throw StateError('token expirado'),
      );

      expect(
        await api.reverseGeocode(apiKey: 'k', latLng: ponto, language: 'pt-BR'),
        isNull,
      );
    });
  });

  group('forwardGeocode', () {
    test('usa a coordenada DA RESPOSTA (não arredondada)', () async {
      final api = apiWith((_) async => http.Response(
            jsonEncode(_canonical(latitude: -23.5631, longitude: -46.6544)),
            200,
          ));

      final result = await api.forwardGeocode(
        apiKey: 'k',
        address: 'Av Paulista, 1000',
        language: 'pt-BR',
      );

      expect(result!.latLng!.latitude, closeTo(-23.5631, 1e-9));
      expect(result.latLng!.longitude, closeTo(-46.6544, 1e-9));
      expect(requests.single.queryParameters['address'], 'Av Paulista, 1000');
    });
  });

  group('autocomplete', () {
    test('converte as sugestões e envia os parâmetros', () async {
      final api = apiWith((_) async => http.Response(
            jsonEncode({
              'suggestions': [
                {
                  'id': 'ChIJ1',
                  'description': 'R. XV de Novembro, 1200',
                  'matchOffset': 0,
                  'matchLength': 16,
                },
                {'id': 'ChIJ2', 'description': 'Sem destaque'},
              ]
            }),
            200,
          ));

      final suggestions = await api.autocomplete(
        apiKey: 'k',
        input: 'xv de novembro',
        language: 'pt-BR',
        sessionToken: 'sess-1',
        countries: ['BR', 'AR'],
        locationBias: ponto,
      );

      expect(suggestions, hasLength(2));
      expect(suggestions.first.id, 'ChIJ1');
      expect(suggestions.first.matchLength, 16);
      // Sem matchOffset/matchLength a UI só deixa de destacar.
      expect(suggestions.last.matchOffset, 0);
      expect(suggestions.last.matchLength, 0);

      final q = requests.single.queryParameters;
      expect(q['input'], 'xv de novembro');
      expect(q['sessionToken'], 'sess-1');
      expect(q['countries'], 'BR,AR');
      expect(q['lat'], '-25.25208883');
    });

    test('lista vazia quando não há resultado', () async {
      final api = apiWith((_) async => http.Response(
            jsonEncode({'suggestions': <dynamic>[]}),
            200,
          ));

      expect(
        await api.autocomplete(
          apiKey: 'k',
          input: 'zzz',
          language: 'pt-BR',
          sessionToken: 't',
        ),
        isEmpty,
      );
    });

    test('erro devolve lista vazia, não null nem exceção', () async {
      final api = apiWith((_) async => http.Response('erro', 500));

      expect(
        await api.autocomplete(
          apiKey: 'k',
          input: 'x',
          language: 'pt-BR',
          sessionToken: 't',
        ),
        isEmpty,
      );
    });

    test('countries ausente não vira parâmetro vazio', () async {
      final api = apiWith((_) async => http.Response(
            jsonEncode({'suggestions': <dynamic>[]}),
            200,
          ));

      await api.autocomplete(
        apiKey: 'k',
        input: 'x',
        language: 'pt-BR',
        sessionToken: 't',
      );

      expect(requests.single.queryParameters.containsKey('countries'), isFalse);
      expect(requests.single.queryParameters.containsKey('lat'), isFalse);
    });
  });

  group('placeDetails', () {
    test('devolve a coordenada do lugar e escapa o placeId no path', () async {
      final api = apiWith((_) async => http.Response(
            jsonEncode(_canonical(latitude: 10.5, longitude: 20.25)),
            200,
          ));

      final details = await api.placeDetails(
        apiKey: 'k',
        placeId: 'ChIJ/com+barra',
        language: 'pt-BR',
        sessionToken: 'sess-1',
      );

      expect(details!.latLng.latitude, closeTo(10.5, 1e-9));
      expect(details.toLocationResult().placeId, 'ChIJabc');
      expect(requests.single.path, '/geocode/place/ChIJ%2Fcom%2Bbarra');
      expect(requests.single.queryParameters['sessionToken'], 'sess-1');
    });

    test('resposta sem coordenada vira null', () async {
      final api = apiWith((_) async => http.Response(
            jsonEncode({'formattedAddress': 'X', 'placeId': 'p'}),
            200,
          ));

      expect(
        await api.placeDetails(
          apiKey: 'k',
          placeId: 'p',
          language: 'pt-BR',
          sessionToken: 't',
        ),
        isNull,
      );
    });
  });

  group('resolveMapsUrl', () {
    test('link longo resolve local, sem tocar na rede', () async {
      final api = apiWith((_) async => http.Response('não deveria', 200));

      final result = await api.resolveMapsUrl(
        'https://www.google.com/maps/@-23.5505,-46.6333,15z',
      );

      expect(result!.latitude, closeTo(-23.5505, 1e-6));
      expect(requests, isEmpty, reason: 'nenhuma requisição para link longo');
    });

    test('link curto vai para o endpoint de expansão', () async {
      final api = apiWith((_) async => http.Response(
            jsonEncode({'latitude': -25.2521, 'longitude': -52.0215}),
            200,
          ));

      final result = await api.resolveMapsUrl('https://maps.app.goo.gl/abc');

      expect(result!.latitude, closeTo(-25.2521, 1e-9));
      expect(requests.single.path, '/geocode/expand-url');
      expect(requests.single.queryParameters['url'],
          'https://maps.app.goo.gl/abc');
    });

    test('URL que não é do Maps nem chega ao servidor', () async {
      final api = apiWith((_) async => http.Response('não deveria', 200));

      expect(await api.resolveMapsUrl('https://example.com'), isNull);
      expect(requests, isEmpty);
    });

    test('404 na expansão vira null', () async {
      final api = apiWith((_) async => http.Response('{}', 404));
      expect(await api.resolveMapsUrl('https://maps.app.goo.gl/x'), isNull);
    });
  });

  group('integração com o cache do pacote', () {
    test('cache e single-flight valem para esta implementação', () async {
      int calls = 0;
      LocationPickerApi.instance = apiWith((_) async {
        calls++;
        await Future<void>.delayed(const Duration(milliseconds: 10));
        return http.Response(jsonEncode(_canonical()), 200);
      });

      // Nada pode escapar para a implementação Google.
      GoogleLocationPickerApi.httpClient = MockClient((_) async {
        fail('nenhuma requisição deveria chegar ao Google');
      });
      addTearDown(() => GoogleLocationPickerApi.httpClient = http.Client());

      await Future.wait([
        LocationPickerUtils.reverseGeocode(apiKey: 'k', latLng: ponto),
        LocationPickerUtils.reverseGeocode(apiKey: 'k', latLng: ponto),
      ]);
      await LocationPickerUtils.reverseGeocode(apiKey: 'k', latLng: ponto);

      expect(calls, 1, reason: 'single-flight + cache acima da interface');
    });
  });
}
