import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

import '../model/location_adress.dart';
import '../model/location_result.dart';

class LocationPickerUtils {
  static const _platform = const MethodChannel('google_map_location_picker');
  static Map<String, String> _appHeaderCache = {};

  static String autoCompleteUrl =
      "https://maps.googleapis.com/maps/api/place/autocomplete/json";
  static String autoCompleteWebUrl =
      "https://maps.googleapis.com/maps/api/place/autocomplete/json";

  static String detailsUrl =
      "https://maps.googleapis.com/maps/api/place/details/json";
  static String detailsWebUrl =
      "https://maps.googleapis.com/maps/api/place/details/json";

  static String geocodeUrl =
      "https://maps.googleapis.com/maps/api/geocode/json";

  /// Prefixo de um proxy de CORS (ex.: `https://proxy.altfor.com.br/`) injetado
  /// pelo app via `InitHelper`. Default vazio = sem proxy. Usado no Flutter Web
  /// para expandir links curtos do Google Maps, contornando o bloqueio de CORS
  /// que impede ler o header `Location` do redirect direto no navegador.
  static String corsProxy = '';

  static Future<Map<String, String>?> getAppHeaders() async {
    if (kIsWeb) {
      return _appHeaderCache;
    }
    if (_appHeaderCache.isEmpty) {
      PackageInfo packageInfo = await PackageInfo.fromPlatform();

      if (Platform.isIOS) {
        _appHeaderCache = {
          "X-Ios-Bundle-Identifier": packageInfo.packageName,
        };
      } else if (Platform.isAndroid) {
        String sha1 = "";
        try {
          sha1 = await _platform.invokeMethod(
              'getSigningCertSha1', packageInfo.packageName);
        } on PlatformException {
          _appHeaderCache = {};
        }

        _appHeaderCache = {
          "X-Android-Package": packageInfo.packageName,
          "X-Android-Cert": sha1,
        };
      }
    }

    return _appHeaderCache;
  }

  /// Reverse geocoding headless: dado um `latLng`, consulta o Geocoding API
  /// e devolve um `LocationResult` com `address`, `placeId` e `locationAdress`
  /// preenchidos a partir do primeiro `results[0]`. Retorna `null` se a API
  /// falhar ou não houver resultados.
  static Future<LocationResult?> reverseGeocode({
    required String apiKey,
    required LatLng latLng,
    String language = 'en',
  }) async {
    try {
      final endpoint =
          '$geocodeUrl?latlng=${latLng.latitude},${latLng.longitude}'
          '&key=$apiKey&language=$language';

      final response = await http.get(
        Uri.parse(endpoint),
        headers: await getAppHeaders(),
      );

      if (response.statusCode != 200) return null;

      final Map<String, dynamic> body =
          jsonDecode(response.body) as Map<String, dynamic>;
      final List<dynamic>? results = body['results'] as List<dynamic>?;
      if (results == null || results.isEmpty) return null;

      final Map<String, dynamic> first = results[0] as Map<String, dynamic>;
      return LocationResult(
        latLng: latLng,
        address: first['formatted_address'] as String?,
        placeId: first['place_id'] as String?,
        locationAdress: LocationAdress.fromMap(first),
      );
    } catch (e) {
      debugPrint("reverseGeocode failed: $e");
      return null;
    }
  }

  /// Tenta interpretar [input] como um par "lat, lng" (notação inglesa ou
  /// europeia com vírgula decimal). O regex é ancorado em ambas as extremidades
  /// para não disparar durante a digitação parcial de um endereço.
  /// Retorna null se o texto não casar exatamente ou as faixas forem inválidas.
  static LatLng? parseLatLng(String input) {
    final trimmed = input.trim();
    // Aceita sinal opcional, dígitos, decimal opcional (ponto ou vírgula),
    // separador vírgula com espaços opcionais, e o mesmo para lng.
    final re = RegExp(r'^(-?\d+(?:[.,]\d+)?)\s*,\s*(-?\d+(?:[.,]\d+)?)$');
    final match = re.firstMatch(trimmed);
    if (match == null) return null;

    final lat = double.tryParse(match.group(1)!.replaceAll(',', '.'));
    final lng = double.tryParse(match.group(2)!.replaceAll(',', '.'));
    if (!_validCoords(lat, lng)) return null;

    return LatLng(lat!, lng!);
  }

  /// Retorna `true` se [input] parece ser uma URL do Google Maps.
  static bool isGoogleMapsUrl(String input) {
    final lower = input.toLowerCase().trim();
    return lower.contains('maps.app.goo.gl') ||
        lower.contains('goo.gl/maps') ||
        lower.contains('maps.google.') ||
        lower.contains('google.com/maps');
  }

  /// Padrões de coordenadas reconhecidos em URLs completas do Google Maps.
  /// Cada regex precisa expor `lat` no group(1) e `lng` no group(2). São
  /// testados em ordem; o primeiro que casar com coords válidas vence.
  /// Onde a vírgula pode trazer espaço URL-encoded (`+`, `%20` ou espaço
  /// literal), usa-se `,(?:\+|%20|\s)*` no separador.
  static final List<RegExp> _coordPatterns = [
    // @lat,lng[,zoom]
    RegExp(r'@(-?\d+\.?\d*),(-?\d+\.?\d*)'),
    // ?q=lat,lng  ou  &query=lat,lng
    RegExp(r'[?&](?:q|query)=(-?\d+\.?\d*),(?:\+|%20|\s)*(-?\d+\.?\d*)'),
    // ll=lat,lng
    RegExp(r'[?&]ll=(-?\d+\.?\d*),(-?\d+\.?\d*)'),
    // /maps/search|place|dir/lat,lng  (coords soltas no path)
    RegExp(r'/maps/(?:search|place|dir)/(-?\d+\.?\d*),(?:\+|%20|\s)*(-?\d+\.?\d*)'),
    // !3dlat!4dlng  (parâmetro data= em URLs de embed/share)
    RegExp(r'!3d(-?\d+\.?\d*)!4d(-?\d+\.?\d*)'),
  ];

  /// Extrai [LatLng] a partir de padrões conhecidos em URLs completas do Google Maps.
  static LatLng? _extractCoordsFromUrl(String url) {
    for (final re in _coordPatterns) {
      final m = re.firstMatch(url);
      if (m == null) continue;

      final lat = double.tryParse(m.group(1)!);
      final lng = double.tryParse(m.group(2)!);
      if (_validCoords(lat, lng)) return LatLng(lat!, lng!);
    }

    return null;
  }

  static bool _validCoords(double? lat, double? lng) {
    if (lat == null || lng == null) return false;
    return lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;
  }

  /// Resolve uma URL do Google Maps (incluindo links curtos como maps.app.goo.gl)
  /// para um [LatLng].
  ///
  /// Nativo/desktop: segue os redirects manualmente para ler o header `Location`
  /// a cada salto. Flutter Web: o navegador bloqueia a leitura do header
  /// `Location` (CORS), então, quando [corsProxy] está configurado, faz a
  /// requisição via proxy — que segue o redirect server-side e devolve a página
  /// final do Maps com CORS liberado — e extrai as coords do corpo da resposta
  /// (ou do header `X-Final-Url`, se o proxy o ecoar). Sem proxy no web, retorna
  /// null (degradação para o autocomplete).
  static Future<LatLng?> resolveGoogleMapsUrl(String input) async {
    final trimmed = input.trim();
    if (!isGoogleMapsUrl(trimmed)) return null;

    // Tenta extrair coords diretamente da URL de entrada (links longos)
    final direct = _extractCoordsFromUrl(trimmed);
    if (direct != null) return direct;

    // No web não dá pra ler o header Location do redirect (CORS). Quando há um
    // proxy configurado, ele expande o link curto server-side e devolve a página
    // final do Maps; sem proxy, degrada para o autocomplete.
    if (kIsWeb) {
      if (corsProxy.isEmpty) return null;
      return _resolveViaCorsProxy(trimmed);
    }

    try {
      final client = http.Client();
      try {
        String currentUrl = trimmed;
        for (int i = 0; i < 3; i++) {
          final request = http.Request('GET', Uri.parse(currentUrl))
            ..followRedirects = false
            ..headers['User-Agent'] = 'Mozilla/5.0';
          final streamed = await client
              .send(request)
              .timeout(const Duration(seconds: 5));
          await streamed.stream.drain<void>();

          final location = streamed.headers['location'];
          if (location == null || location.isEmpty) break;

          final coords = _extractCoordsFromUrl(location);
          if (coords != null) return coords;

          currentUrl = location;
        }
      } finally {
        client.close();
      }
    } catch (e) {
      debugPrint('resolveGoogleMapsUrl failed: $e');
    }

    return null;
  }

  /// Expande um link curto do Google Maps no Flutter Web usando [corsProxy].
  /// O proxy segue o redirect server-side e devolve a página final do Maps com
  /// CORS liberado.
  ///
  /// Em `package:http`, `response.request` é sempre a Request original (o
  /// endpoint do proxy) — o pacote NÃO surfa a URL pós-redirect. Por isso a
  /// extração da URL final depende de o proxy ecoá-la num header `X-Final-Url`;
  /// quando ausente, caímos no parse do corpo da página expandida, que costuma
  /// carregar os padrões `@lat,lng` e `!3d!4d`.
  static Future<LatLng?> _resolveViaCorsProxy(String url) async {
    try {
      // Concatena a URL alvo crua após o prefixo do proxy — mesma convenção de
      // `autoCompleteWebUrl`/`detailsWebUrl`, em que o proxy lê tudo após o
      // prefixo (inclusive querystrings) como o endereço de destino.
      final endpoint = '$corsProxy$url';
      final response = await http
          .get(Uri.parse(endpoint))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return null;

      // 1) URL final pós-redirect, se o proxy a ecoar via header (mais confiável
      // que varrer o corpo, sem o risco de pegar coords de viewport vs pin).
      final finalUrl = response.headers['x-final-url'];
      if (finalUrl != null && finalUrl.isNotEmpty) {
        final fromUrl = _extractCoordsFromUrl(finalUrl);
        if (fromUrl != null) return fromUrl;
      }

      // 2) Fallback: varre o corpo da página expandida.
      return _extractCoordsFromUrl(response.body);
    } catch (e) {
      debugPrint('_resolveViaCorsProxy failed: $e');
      return null;
    }
  }

  /// Forward geocoding headless: dado um `address` em texto livre, consulta o
  /// Geocoding API e devolve um `LocationResult` com `latLng`, `address`,
  /// `placeId` e `locationAdress` preenchidos a partir do primeiro
  /// `results[0]`. Retorna `null` se a API falhar ou não houver resultados.
  static Future<LocationResult?> forwardGeocode({
    required String apiKey,
    required String address,
    String language = 'en',
  }) async {
    if (address.trim().isEmpty) return null;

    try {
      final endpoint =
          '$geocodeUrl?address=${Uri.encodeQueryComponent(address)}'
          '&key=$apiKey&language=$language';

      final response = await http.get(
        Uri.parse(endpoint),
        headers: await getAppHeaders(),
      );

      if (response.statusCode != 200) return null;

      final Map<String, dynamic> body =
          jsonDecode(response.body) as Map<String, dynamic>;
      final List<dynamic>? results = body['results'] as List<dynamic>?;
      if (results == null || results.isEmpty) return null;

      final Map<String, dynamic> first = results[0] as Map<String, dynamic>;
      final Map<String, dynamic>? geometry =
          first['geometry'] as Map<String, dynamic>?;
      final Map<String, dynamic>? location =
          geometry?['location'] as Map<String, dynamic>?;

      LatLng? latLng;
      if (location != null &&
          location['lat'] is num &&
          location['lng'] is num) {
        latLng = LatLng(
          (location['lat'] as num).toDouble(),
          (location['lng'] as num).toDouble(),
        );
      }

      return LocationResult(
        latLng: latLng,
        address: first['formatted_address'] as String?,
        placeId: first['place_id'] as String?,
        locationAdress: LocationAdress.fromMap(first),
      );
    } catch (e) {
      debugPrint("forwardGeocode failed: $e");
      return null;
    }
  }
}
