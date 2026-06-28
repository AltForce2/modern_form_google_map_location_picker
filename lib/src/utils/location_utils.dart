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

  /// Extrai [LatLng] a partir de padrões conhecidos em URLs completas do Google Maps.
  static LatLng? _extractCoordsFromUrl(String url) {
    // @lat,lng[,zoom]
    var m = RegExp(r'@(-?\d+\.?\d*),(-?\d+\.?\d*)').firstMatch(url);
    if (m != null) {
      final lat = double.tryParse(m.group(1)!);
      final lng = double.tryParse(m.group(2)!);
      if (_validCoords(lat, lng)) return LatLng(lat!, lng!);
    }

    // ?q=lat,lng  ou  &query=lat,lng
    m = RegExp(r'[?&](?:q|query)=(-?\d+\.?\d*),(-?\d+\.?\d*)')
        .firstMatch(url);
    if (m != null) {
      final lat = double.tryParse(m.group(1)!);
      final lng = double.tryParse(m.group(2)!);
      if (_validCoords(lat, lng)) return LatLng(lat!, lng!);
    }

    // ll=lat,lng
    m = RegExp(r'[?&]ll=(-?\d+\.?\d*),(-?\d+\.?\d*)').firstMatch(url);
    if (m != null) {
      final lat = double.tryParse(m.group(1)!);
      final lng = double.tryParse(m.group(2)!);
      if (_validCoords(lat, lng)) return LatLng(lat!, lng!);
    }

    // !3dlat!4dlng  (parâmetro data= em URLs de embed/share)
    m = RegExp(r'!3d(-?\d+\.?\d*)!4d(-?\d+\.?\d*)').firstMatch(url);
    if (m != null) {
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
  /// para um [LatLng]. Segue redirects manualmente para poder ler o header
  /// `Location` a cada salto. No Flutter Web retorna null (CORS bloqueia
  /// a leitura do header fora do mesmo domínio).
  static Future<LatLng?> resolveGoogleMapsUrl(String input) async {
    final trimmed = input.trim();
    if (!isGoogleMapsUrl(trimmed)) return null;

    // Tenta extrair coords diretamente da URL de entrada (links longos)
    final direct = _extractCoordsFromUrl(trimmed);
    if (direct != null) return direct;

    // Links curtos exigem seguir o redirect; no web CORS bloqueia o header Location
    if (kIsWeb) return null;

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
