import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' show LatLng;
import 'package:http/http.dart' as http;

import '../model/location_address.dart';
import '../model/location_result.dart';
import '../utils/location_utils.dart';
import 'location_picker_api.dart';

/// Fornece os headers de cada requisição. É um callback assíncrono, não um
/// `Map` fixo, porque um token de autenticação expira e precisa ser renovado
/// entre uma chamada e outra.
typedef LocationPickerHeadersBuilder = Future<Map<String, String>> Function();

/// Implementação que fala com um backend próprio em vez das APIs do Google.
///
/// Existe para tirar o geocoding do cliente: um backend com cache compartilhado
/// entre usuários resolve cada ponto uma vez para todo mundo, enquanto o cache
/// do pacote é por aparelho. Como consequência, a chave do Google embarcada no
/// app pode ser restrita a Maps SDK / Maps JS API, sem Geocoding nem Places.
///
/// Instale no boot do app:
///
/// ```dart
/// LocationPickerApi.instance = BackendLocationPickerApi(
///   baseUrl: 'https://api.exemplo.com',
///   headers: () async => {'authorization': await pegarToken()},
/// );
/// ```
///
/// Espera os seguintes endpoints, todos devolvendo o corpo cru (sem envelope):
///
/// | Método | Rota |
/// |---|---|
/// | [reverseGeocode] | `GET /geocode/reverse?lat&lng&language` |
/// | [forwardGeocode] | `GET /geocode/forward?address&language` |
/// | [autocomplete] | `GET /geocode/autocomplete?input&language&sessionToken&countries&lat&lng` |
/// | [placeDetails] | `GET /geocode/place/{placeId}?language&sessionToken` |
/// | [resolveMapsUrl] | `GET /geocode/expand-url?url` |
///
/// O `apiKey` que chega em cada método vem do widget e é **ignorado** — a chave
/// do Google fica no servidor.
class BackendLocationPickerApi extends LocationPickerApi {
  BackendLocationPickerApi({
    required String baseUrl,
    required this.headers,
    http.Client? client,
    this.timeout = const Duration(seconds: 15),
  })  : baseUrl = _stripTrailingSlash(baseUrl),
        httpClient = client ?? http.Client();

  /// Raiz da API, sem barra final. Pode incluir prefixo de path
  /// (`https://api.exemplo.com/v1`).
  final String baseUrl;

  final LocationPickerHeadersBuilder headers;

  final http.Client httpClient;

  final Duration timeout;

  static String _stripTrailingSlash(String url) =>
      url.endsWith('/') ? url.substring(0, url.length - 1) : url;

  // ---------------------------------------------------------------------------
  // Geocoding
  // ---------------------------------------------------------------------------

  @override
  Future<LocationResult?> reverseGeocode({
    required String apiKey,
    required LatLng latLng,
    required String language,
  }) async {
    final Map<String, dynamic>? body = await _get(
      '/geocode/reverse',
      <String, String?>{
        'lat': latLng.latitude.toString(),
        'lng': latLng.longitude.toString(),
        'language': language,
      },
      'reverseGeocode',
    );
    if (body == null) return null;

    // A coordenada devolvida vem arredondada no grid do servidor (~11 m). Para
    // o resultado usamos a que o usuário escolheu, não a do grid — senão o pin
    // se deslocaria do ponto marcado no mapa.
    return _locationResultFrom(body, latLng: latLng);
  }

  @override
  Future<LocationResult?> forwardGeocode({
    required String apiKey,
    required String address,
    required String language,
  }) async {
    final Map<String, dynamic>? body = await _get(
      '/geocode/forward',
      <String, String?>{'address': address, 'language': language},
      'forwardGeocode',
    );
    if (body == null) return null;

    // Aqui a coordenada É o resultado — o endpoint devolve a exata, não a do
    // grid, justamente para o mapa centralizar no lugar buscado.
    return _locationResultFrom(body, latLng: _latLngFrom(body));
  }

  // ---------------------------------------------------------------------------
  // Places
  // ---------------------------------------------------------------------------

  @override
  Future<List<PlaceSuggestion>> autocomplete({
    required String apiKey,
    required String input,
    required String language,
    required String sessionToken,
    List<String>? countries,
    LatLng? locationBias,
  }) async {
    final Map<String, dynamic>? body = await _get(
      '/geocode/autocomplete',
      <String, String?>{
        'input': input,
        'language': language,
        'sessionToken': sessionToken,
        'countries': (countries != null && countries.isNotEmpty)
            ? countries.join(',')
            : null,
        'lat': locationBias?.latitude.toString(),
        'lng': locationBias?.longitude.toString(),
      },
      'autocomplete',
    );
    if (body == null) return const [];

    final List<dynamic>? suggestions = body['suggestions'] as List<dynamic>?;
    if (suggestions == null) return const [];

    return suggestions
        .whereType<Map<String, dynamic>>()
        .map(_suggestionFrom)
        .toList();
  }

  PlaceSuggestion _suggestionFrom(Map<String, dynamic> item) {
    return PlaceSuggestion(
      id: item['id'] as String?,
      description: item['description'] as String? ?? '',
      matchOffset: (item['matchOffset'] as num?)?.toInt() ?? 0,
      matchLength: (item['matchLength'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  Future<PlaceDetails?> placeDetails({
    required String apiKey,
    required String placeId,
    required String language,
    required String sessionToken,
  }) async {
    final Map<String, dynamic>? body = await _get(
      '/geocode/place/${Uri.encodeComponent(placeId)}',
      <String, String?>{'language': language, 'sessionToken': sessionToken},
      'placeDetails',
    );
    if (body == null) return null;

    final LatLng? latLng = _latLngFrom(body);
    if (latLng == null) {
      debugPrint('placeDetails: resposta sem latitude/longitude');
      return null;
    }

    return PlaceDetails(
      latLng: latLng,
      formattedAddress: body['formattedAddress'] as String?,
      placeId: body['placeId'] as String?,
      // Para certos tipos de lugar (cidade, estabelecimento) o Places Details
      // não devolve os componentes — vem tudo nulo, e quem chama cai no reverse
      // geocode da coordenada.
      locationAddress: _addressFrom(body),
    );
  }

  // ---------------------------------------------------------------------------
  // Link do Google Maps
  // ---------------------------------------------------------------------------

  @override
  Future<LatLng?> resolveMapsUrl(String url) async {
    final String trimmed = url.trim();
    if (!LocationPickerUtils.isGoogleMapsUrl(trimmed)) return null;

    // Link longo já carrega a coordenada no próprio texto: resolve local e
    // poupa o round-trip. O servidor faz o mesmo, mas de graça é melhor.
    final LatLng? direct = LocationPickerUtils.extractCoordsFromUrl(trimmed);
    if (direct != null) return direct;

    final Map<String, dynamic>? body = await _get(
      '/geocode/expand-url',
      <String, String?>{'url': trimmed},
      'resolveMapsUrl',
    );
    if (body == null) return null;

    return _latLngFrom(body);
  }

  // ---------------------------------------------------------------------------
  // Conversão
  // ---------------------------------------------------------------------------

  /// Monta o resultado a partir do objeto de endereço canônico da API.
  ///
  /// [latLng] é passado explicitamente porque a coordenada correta depende do
  /// endpoint: no reverse é a que o usuário escolheu; no forward e no details é
  /// a que a API devolveu.
  LocationResult _locationResultFrom(
    Map<String, dynamic> body, {
    required LatLng? latLng,
  }) {
    return LocationResult(
      latLng: latLng,
      address: body['formattedAddress'] as String?,
      placeId: body['placeId'] as String?,
      locationAddress: _addressFrom(body),
    );
  }

  /// Mapeia os campos planos da API para o modelo do pacote, que usa a
  /// nomenclatura do Google.
  LocationAddress _addressFrom(Map<String, dynamic> body) {
    return LocationAddress(
      streetNumber: body['number'] as String?,
      route: body['street'] as String?,
      sublocalityLevel1: body['neighborhood'] as String?,
      administrativeAreaLevel1: body['state'] as String?,
      administrativeAreaLevel2: body['city'] as String?,
      country: body['country'] as String?,
      postalCode: body['cep'] as String?,
      stateCode: body['stateCode'] as String?,
      countryCode: body['countryCode'] as String?,
      locationType: body['locationType'] as String?,
    );
  }

  static LatLng? _latLngFrom(Map<String, dynamic> body) {
    final Object? lat = body['latitude'];
    final Object? lng = body['longitude'];
    if (lat is! num || lng is! num) return null;
    return LatLng(lat.toDouble(), lng.toDouble());
  }

  // ---------------------------------------------------------------------------
  // Transporte
  // ---------------------------------------------------------------------------

  /// GET com montagem de URL, headers do callback, timeout e tratamento de
  /// status. Devolve `null` em qualquer caminho que não seja um `200` com corpo
  /// JSON — o contrato de [LocationPickerApi] é nunca lançar.
  Future<Map<String, dynamic>?> _get(
    String path,
    Map<String, String?> parameters,
    String label,
  ) async {
    try {
      final Map<String, String> query = <String, String>{};
      parameters.forEach((key, value) {
        if (value != null && value.isNotEmpty) query[key] = value;
      });

      final Uri uri = Uri.parse('$baseUrl$path')
          .replace(queryParameters: query.isEmpty ? null : query);

      final http.Response response = await httpClient
          .get(uri, headers: await headers())
          .timeout(timeout);

      // 404 não é falha: significa "não há endereço aqui". O servidor já
      // cacheia esse negativo, então repetir a consulta não custa.
      if (response.statusCode == 404) return null;

      if (response.statusCode != 200) {
        debugPrint('$label: HTTP ${response.statusCode} ${response.body}');
        return null;
      }

      final Object? decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        debugPrint('$label: corpo inesperado');
        return null;
      }

      return decoded;
    } catch (e) {
      // Inclui falha do callback de headers (ex.: renovação de token).
      debugPrint('$label failed: $e');
      return null;
    }
  }
}
