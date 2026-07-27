import 'package:flutter_test/flutter_test.dart';
import 'package:google_map_location_picker/src/api/google_location_picker_api.dart';
import 'package:google_map_location_picker/src/api/location_picker_api.dart';
import 'package:google_map_location_picker/src/model/location_address.dart';
import 'package:google_map_location_picker/src/model/location_result.dart';
import 'package:google_map_location_picker/src/utils/location_utils.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' show LatLng;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Implementação de exemplo: é exatamente o que um consumidor escreveria para
/// apontar o picker para o próprio backend em vez do Google.
class _FakeBackendApi extends LocationPickerApi {
  int reverseCalls = 0;
  int forwardCalls = 0;
  int autocompleteCalls = 0;
  int detailsCalls = 0;
  int resolveCalls = 0;

  String? lastApiKeySeen;

  @override
  Future<LocationResult?> reverseGeocode({
    required String apiKey,
    required LatLng latLng,
    required String language,
  }) async {
    reverseCalls++;
    lastApiKeySeen = apiKey;
    return LocationResult(
      latLng: latLng,
      address: 'endereço do backend',
      placeId: 'backend-1',
      locationAddress: LocationAddress(route: 'Rua do Backend'),
    );
  }

  @override
  Future<LocationResult?> forwardGeocode({
    required String apiKey,
    required String address,
    required String language,
  }) async {
    forwardCalls++;
    return LocationResult(
      latLng: const LatLng(1, 2),
      address: address,
    );
  }

  @override
  Future<List<PlaceSuggestion>> autocomplete({
    required String apiKey,
    required String input,
    required String language,
    required String sessionToken,
    List<String>? countries,
    LatLng? locationBias,
  }) async {
    autocompleteCalls++;
    return <PlaceSuggestion>[
      PlaceSuggestion(description: 'Resultado para $input', id: 'b-1'),
    ];
  }

  @override
  Future<PlaceDetails?> placeDetails({
    required String apiKey,
    required String placeId,
    required String language,
    required String sessionToken,
  }) async {
    detailsCalls++;
    return const PlaceDetails(
      latLng: LatLng(3, 4),
      formattedAddress: 'detalhe do backend',
      placeId: 'b-1',
    );
  }

  @override
  Future<LatLng?> resolveMapsUrl(String url) async {
    resolveCalls++;
    // Um backend resolve links curtos sem esbarrar em CORS — o que a
    // implementação padrão não consegue no Flutter Web.
    return const LatLng(5, 6);
  }
}

void main() {
  late _FakeBackendApi fake;

  setUp(() {
    fake = _FakeBackendApi();
    LocationPickerApi.instance = fake;
    LocationPickerUtils.clearGeocodeCache();
  });

  tearDown(() {
    LocationPickerApi.resetToDefault();
    LocationPickerUtils.clearGeocodeCache();
  });

  test('o default é a implementação Google', () {
    LocationPickerApi.resetToDefault();
    expect(LocationPickerApi.instance, isA<GoogleLocationPickerApi>());
  });

  test('trocar a instance redireciona o geocoding, sem tocar no Google',
      () async {
    // Se alguma chamada escapasse para o Google, este client acusaria.
    GoogleLocationPickerApi.httpClient = MockClient((_) async {
      fail('nenhuma requisição deveria chegar à implementação Google');
    });
    addTearDown(() => GoogleLocationPickerApi.httpClient = http.Client());

    final result = await LocationPickerUtils.reverseGeocode(
      apiKey: 'k',
      latLng: const LatLng(-23.5505, -46.6333),
    );

    expect(result?.address, 'endereço do backend');
    expect(result?.locationAddress?.route, 'Rua do Backend');
    expect(fake.reverseCalls, 1);
  });

  test('o cache continua valendo para a implementação customizada', () async {
    const LatLng point = LatLng(-23.5505, -46.6333);

    await LocationPickerUtils.reverseGeocode(apiKey: 'k', latLng: point);
    await LocationPickerUtils.reverseGeocode(apiKey: 'k', latLng: point);

    expect(
      fake.reverseCalls,
      1,
      reason: 'cache e single-flight vivem acima da interface, '
          'então a implementação não precisa reimplementá-los',
    );
  });

  test('single-flight também vale para a implementação customizada', () async {
    const LatLng point = LatLng(10, 20);

    await Future.wait<LocationResult?>([
      LocationPickerUtils.reverseGeocode(apiKey: 'k', latLng: point),
      LocationPickerUtils.reverseGeocode(apiKey: 'k', latLng: point),
      LocationPickerUtils.reverseGeocode(apiKey: 'k', latLng: point),
    ]);

    expect(fake.reverseCalls, 1);
  });

  test('forwardGeocode e resolveGoogleMapsUrl também passam pela instance',
      () async {
    final forward = await LocationPickerUtils.forwardGeocode(
      apiKey: 'k',
      address: 'Av Paulista, 1000',
    );
    expect(forward?.address, 'Av Paulista, 1000');
    expect(fake.forwardCalls, 1);

    final resolved = await LocationPickerUtils.resolveGoogleMapsUrl(
      'https://maps.app.goo.gl/abc',
    );
    expect(resolved, const LatLng(5, 6));
    expect(fake.resolveCalls, 1);
  });

  test('autocomplete e placeDetails passam pela instance', () async {
    final suggestions = await LocationPickerApi.instance.autocomplete(
      apiKey: 'k',
      input: 'paulista',
      language: 'pt-BR',
      sessionToken: 't',
    );
    expect(suggestions.single.description, 'Resultado para paulista');
    expect(fake.autocompleteCalls, 1);

    final details = await LocationPickerApi.instance.placeDetails(
      apiKey: 'k',
      placeId: 'b-1',
      language: 'pt-BR',
      sessionToken: 't',
    );
    expect(details?.toLocationResult().address, 'detalhe do backend');
    expect(fake.detailsCalls, 1);
  });

  test('o apiKey do widget continua chegando na implementação', () async {
    // Uma implementação própria pode ignorá-lo, mas ele é repassado para quem
    // ainda precise falar com o Google em algum caminho.
    await LocationPickerUtils.reverseGeocode(
      apiKey: 'minha-chave',
      latLng: const LatLng(1, 1),
    );
    expect(fake.lastApiKeySeen, 'minha-chave');
  });
}
