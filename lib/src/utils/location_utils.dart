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
