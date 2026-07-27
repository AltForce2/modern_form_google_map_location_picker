import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' show LatLng;
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

import '../model/location_address.dart';
import '../model/location_result.dart';
import '../utils/location_utils.dart';
import 'location_picker_api.dart';

/// Implementação padrão: fala direto com as APIs do Google (Geocoding e
/// Places). É o único lugar do pacote que faz requisição HTTP.
class GoogleLocationPickerApi extends LocationPickerApi {
  const GoogleLocationPickerApi();

  // ---------------------------------------------------------------------------
  // Configuração
  // ---------------------------------------------------------------------------

  /// Cliente HTTP de todas as chamadas. Ponto de injeção para `MockClient`
  /// nos testes, ou para um cliente com interceptador/proxy.
  static http.Client httpClient = http.Client();

  /// Teto por requisição. Sem ele uma rede ruim deixa o picker travado no
  /// spinner indefinidamente.
  static const Duration requestTimeout = Duration(seconds: 15);

  /// Teto por salto ao seguir redirect de link encurtado.
  static const Duration redirectTimeout = Duration(seconds: 5);

  /// Teto da requisição via [corsProxy] (segue o redirect server-side e devolve
  /// a página final, então é mais lenta que um salto isolado).
  static const Duration corsProxyTimeout = Duration(seconds: 10);

  /// Prefixo de um proxy de CORS (ex.: `https://proxy.altfor.com.br/`) injetado
  /// pelo app. Default vazio = sem proxy. Usado no Flutter Web para expandir
  /// links curtos do Google Maps, contornando o bloqueio de CORS que impede
  /// ler o header `Location` do redirect direto no navegador.
  static String corsProxy = '';

  static String geocodeUrl =
      'https://maps.googleapis.com/maps/api/geocode/json';
  static String autoCompleteUrl =
      'https://maps.googleapis.com/maps/api/place/autocomplete/json';
  static String detailsUrl =
      'https://maps.googleapis.com/maps/api/place/details/json';

  /// Places Autocomplete filtra por até 5 países.
  static const int _maxCountries = 5;

  static const MethodChannel _platform =
      MethodChannel('google_map_location_picker');
  static Map<String, String> _appHeaderCache = {};

  // ---------------------------------------------------------------------------
  // Geocoding
  // ---------------------------------------------------------------------------

  @override
  Future<LocationResult?> reverseGeocode({
    required String apiKey,
    required LatLng latLng,
    required String language,
  }) async {
    final Map<String, dynamic>? first = await _firstGeocodeResult(
      label: 'reverseGeocode',
      parameters: <String, String>{
        'latlng': '${latLng.latitude},${latLng.longitude}',
        'key': apiKey,
        'language': language,
      },
    );
    if (first == null) return null;

    return LocationResult(
      latLng: latLng,
      address: first['formatted_address'] as String?,
      placeId: first['place_id'] as String?,
      locationAddress: LocationAddress.fromMap(first),
    );
  }

  @override
  Future<LocationResult?> forwardGeocode({
    required String apiKey,
    required String address,
    required String language,
  }) async {
    final Map<String, dynamic>? first = await _firstGeocodeResult(
      label: 'forwardGeocode',
      parameters: <String, String>{
        'address': address,
        'key': apiKey,
        'language': language,
      },
    );
    if (first == null) return null;

    return LocationResult(
      latLng: _latLngFrom(first['geometry'] as Map<String, dynamic>?),
      address: first['formatted_address'] as String?,
      placeId: first['place_id'] as String?,
      locationAddress: LocationAddress.fromMap(first),
    );
  }

  /// Chama o Geocoding API e devolve `results[0]`, ou `null` se a requisição
  /// falhar, o `status` não for `OK` ou não houver resultados.
  Future<Map<String, dynamic>?> _firstGeocodeResult({
    required String label,
    required Map<String, String> parameters,
  }) async {
    final Map<String, dynamic>? body =
        await _get(geocodeUrl, parameters, label);
    if (body == null) return null;

    final List<dynamic>? results = body['results'] as List<dynamic>?;
    if (results == null || results.isEmpty) return null;

    return results.first as Map<String, dynamic>;
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
    final Map<String, String> parameters = <String, String>{
      'key': apiKey,
      'input': input,
      'sessiontoken': sessionToken,
      'language': language,
    };

    if (countries != null && countries.isNotEmpty) {
      final List<String> limited =
          countries.sublist(0, min(countries.length, _maxCountries));
      parameters['components'] = limited.map((c) => 'country:$c').join('|');
    }

    if (locationBias != null) {
      parameters['location'] =
          '${locationBias.latitude},${locationBias.longitude}';
    }

    final Map<String, dynamic>? body =
        await _get(autoCompleteUrl, parameters, 'autocomplete');
    if (body == null) return const [];

    final List<dynamic>? predictions = body['predictions'] as List<dynamic>?;
    if (predictions == null) return const [];

    return predictions
        .whereType<Map<String, dynamic>>()
        .map(_suggestionFrom)
        .toList();
  }

  /// Converte uma `prediction`. Tolera `matched_substrings` ausente ou vazio —
  /// o Google omite o campo em algumas respostas e o acesso direto a `[0]`
  /// estourava `RangeError`.
  PlaceSuggestion _suggestionFrom(Map<String, dynamic> prediction) {
    final List<dynamic>? matched =
        prediction['matched_substrings'] as List<dynamic>?;
    final Map<String, dynamic>? firstMatch =
        (matched != null && matched.isNotEmpty)
            ? matched.first as Map<String, dynamic>
            : null;

    return PlaceSuggestion(
      id: prediction['place_id'] as String?,
      description: prediction['description'] as String? ?? '',
      matchOffset: (firstMatch?['offset'] as num?)?.toInt() ?? 0,
      matchLength: (firstMatch?['length'] as num?)?.toInt() ?? 0,
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
      detailsUrl,
      <String, String>{
        'key': apiKey,
        'placeid': placeId,
        'sessiontoken': sessionToken,
        'language': language,
      },
      'placeDetails',
    );
    if (body == null) return null;

    final Map<String, dynamic>? result =
        body['result'] as Map<String, dynamic>?;
    final LatLng? latLng =
        _latLngFrom(result?['geometry'] as Map<String, dynamic>?);

    if (result == null || latLng == null) {
      debugPrint('placeDetails: resposta sem geometry.location');
      return null;
    }

    return PlaceDetails(
      latLng: latLng,
      formattedAddress: result['formatted_address'] as String?,
      placeId: result['place_id'] as String?,
      // O Places Details não retorna `address_components` para alguns tipos de
      // place (cidade, estabelecimento); nesses casos vem vazio.
      locationAddress: LocationAddress.fromMap(result),
    );
  }

  // ---------------------------------------------------------------------------
  // Resolução de link do Google Maps
  // ---------------------------------------------------------------------------

  @override
  Future<LatLng?> resolveMapsUrl(String url) async {
    final String trimmed = url.trim();
    if (!LocationPickerUtils.isGoogleMapsUrl(trimmed)) return null;

    // Links longos já trazem as coordenadas no próprio texto.
    final LatLng? direct = LocationPickerUtils.extractCoordsFromUrl(trimmed);
    if (direct != null) return direct;

    // No web o navegador bloqueia a leitura do header `Location` do redirect
    // (CORS). Com um proxy configurado ele expande o link server-side; sem
    // proxy, degrada para o autocomplete.
    if (kIsWeb) {
      if (corsProxy.isEmpty) return null;
      return _resolveViaCorsProxy(trimmed);
    }

    try {
      final http.Client client = http.Client();
      try {
        String currentUrl = trimmed;
        for (int i = 0; i < 3; i++) {
          final http.Request request = http.Request('GET', Uri.parse(currentUrl))
            ..followRedirects = false
            ..headers['User-Agent'] = 'Mozilla/5.0';

          final http.StreamedResponse streamed =
              await client.send(request).timeout(redirectTimeout);
          await streamed.stream.drain<void>();

          final String? location = streamed.headers['location'];
          if (location == null || location.isEmpty) break;

          final LatLng? coords =
              LocationPickerUtils.extractCoordsFromUrl(location);
          if (coords != null) return coords;

          currentUrl = location;
        }
      } finally {
        client.close();
      }
    } catch (e) {
      debugPrint('resolveMapsUrl failed: $e');
    }

    return null;
  }

  /// Expande um link curto do Google Maps no Flutter Web usando [corsProxy].
  /// O proxy segue o redirect server-side e devolve a página final do Maps com
  /// CORS liberado.
  ///
  /// Em `package:http`, `response.request` é sempre a Request original (o
  /// endpoint do proxy) — o pacote NÃO expõe a URL pós-redirect. Por isso a
  /// extração da URL final depende de o proxy ecoá-la num header `X-Final-Url`;
  /// quando ausente, caímos no parse do corpo da página expandida, que costuma
  /// carregar os padrões `@lat,lng` e `!3d!4d`.
  Future<LatLng?> _resolveViaCorsProxy(String url) async {
    try {
      // Concatena a URL alvo crua após o prefixo do proxy — a convenção é o
      // proxy ler tudo após o prefixo (inclusive querystrings) como destino.
      final Uri endpoint = Uri.parse('$corsProxy$url');
      final http.Response response =
          await httpClient.get(endpoint).timeout(corsProxyTimeout);

      if (response.statusCode != 200) return null;

      // 1) URL final pós-redirect, se o proxy a ecoar via header (mais
      // confiável que varrer o corpo, sem o risco de pegar coords do viewport
      // em vez do pin).
      final String? finalUrl = response.headers['x-final-url'];
      if (finalUrl != null && finalUrl.isNotEmpty) {
        final LatLng? fromUrl = LocationPickerUtils.extractCoordsFromUrl(
          finalUrl,
        );
        if (fromUrl != null) return fromUrl;
      }

      // 2) Fallback: varre o corpo da página expandida.
      return LocationPickerUtils.extractCoordsFromUrl(response.body);
    } catch (e) {
      debugPrint('_resolveViaCorsProxy failed: $e');
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Transporte
  // ---------------------------------------------------------------------------

  /// GET com montagem de URL via [Uri] (escaping correto), timeout e checagem
  /// de `status`. `ZERO_RESULTS` não é tratado como erro: devolve o corpo para
  /// o chamador decidir.
  Future<Map<String, dynamic>?> _get(
    String baseUrl,
    Map<String, String> parameters,
    String label,
  ) async {
    try {
      final Uri base = Uri.parse(baseUrl);
      final Uri uri = Uri(
        scheme: base.scheme,
        host: base.host,
        path: base.path,
        queryParameters: parameters,
      );

      final http.Response response = await httpClient
          .get(uri, headers: await appHeaders())
          .timeout(requestTimeout);

      if (response.statusCode != 200) {
        debugPrint('$label: HTTP ${response.statusCode}');
        return null;
      }

      final Map<String, dynamic> body =
          jsonDecode(response.body) as Map<String, dynamic>;

      // Sem esta checagem um OVER_QUERY_LIMIT era indistinguível de
      // "lugar sem nome": o Google devolve HTTP 200 nos dois casos.
      final String? status = body['status'] as String?;
      if (status != null && status != 'OK' && status != 'ZERO_RESULTS') {
        debugPrint('$label: status=$status ${body['error_message'] ?? ''}');
        return null;
      }

      return body;
    } catch (e) {
      debugPrint('$label failed: $e');
      return null;
    }
  }

  static LatLng? _latLngFrom(Map<String, dynamic>? geometry) {
    final Map<String, dynamic>? location =
        geometry?['location'] as Map<String, dynamic>?;
    if (location == null ||
        location['lat'] is! num ||
        location['lng'] is! num) {
      return null;
    }
    return LatLng(
      (location['lat'] as num).toDouble(),
      (location['lng'] as num).toDouble(),
    );
  }

  /// Headers de restrição da API key. Só Android e iOS os usam — o Google não
  /// define equivalente para desktop/web.
  static Future<Map<String, String>?> appHeaders() async {
    if (kIsWeb) return _appHeaderCache;

    // `PackageInfo.fromPlatform()` era chamado antes de checar a plataforma:
    // em desktop o resultado era descartado, e a chamada lança quando o plugin
    // não está registrado (o que derrubava toda requisição em testes).
    final bool platformUsesHeaders = Platform.isIOS || Platform.isAndroid;
    if (!platformUsesHeaders || _appHeaderCache.isNotEmpty) {
      return _appHeaderCache;
    }

    try {
      final PackageInfo packageInfo = await PackageInfo.fromPlatform();

      if (Platform.isIOS) {
        _appHeaderCache = {
          'X-Ios-Bundle-Identifier': packageInfo.packageName,
        };
      } else {
        String sha1 = '';
        try {
          sha1 = await _platform.invokeMethod(
              'getSigningCertSha1', packageInfo.packageName);
        } on PlatformException catch (e) {
          // Assinatura indisponível: seguimos sem o header em vez de derrubar
          // a requisição.
          debugPrint('getSigningCertSha1 failed: $e');
        }

        _appHeaderCache = {
          'X-Android-Package': packageInfo.packageName,
          'X-Android-Cert': sha1,
        };
      }
    } catch (e) {
      debugPrint('appHeaders failed: $e');
    }

    return _appHeaderCache;
  }
}
