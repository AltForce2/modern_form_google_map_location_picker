import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../api/google_location_picker_api.dart';
import '../api/location_picker_api.dart';
import '../model/location_result.dart';

/// Helpers de localização do picker.
///
/// Não faz requisição: toda a rede vive em [LocationPickerApi]. O que sobra
/// aqui é (a) parsing puro de coordenadas e URLs e (b) a camada de cache e
/// deduplicação por cima do geocoding, que vale para qualquer implementação
/// de [LocationPickerApi].
class LocationPickerUtils {
  /// Cache de reverse geocoding por coordenada arredondada (~11 metros).
  /// Evita pagar de novo pelo mesmo ponto dentro da sessão.
  static final Map<String, LocationResult> _reverseCache = {};

  /// Chamadas de reverse geocoding em andamento, por chave de coordenada. Sem
  /// isto, requisições concorrentes do mesmo ponto viram N chamadas COBRADAS
  /// antes de a primeira preencher o cache — o picker dispara reverse geocode
  /// por caminhos que rodam quase simultaneamente.
  static final Map<String, Future<LocationResult?>> _reverseInFlight = {};

  /// Cache e single-flight equivalentes para o forward geocoding.
  static final Map<String, LocationResult> _forwardCache = {};
  static final Map<String, Future<LocationResult?>> _forwardInFlight = {};

  /// 4 casas decimais ≈ 11 metros — o mesmo grid que o backend de geocoding
  /// usa para agrupar coordenadas. Alinhar as duas camadas evita que dois
  /// pontos a poucos metros gerem duas chaves locais e dois round-trips que o
  /// servidor responderia do mesmo registro.
  ///
  /// O `language` entra na chave porque a resposta muda conforme o idioma.
  static String _coordKey(LatLng latLng, String language) =>
      '${latLng.latitude.toStringAsFixed(4)},'
      '${latLng.longitude.toStringAsFixed(4)}|$language';

  static String _addressKey(String address, String language) =>
      '${address.trim().toLowerCase()}|$language';

  /// Prefixo de um proxy de CORS usado no Flutter Web para expandir links
  /// curtos do Google Maps.
  ///
  /// Movido para [GoogleLocationPickerApi.corsProxy] — é detalhe da
  /// implementação que fala com o Google, e deixa de fazer sentido quando o
  /// pacote aponta para um backend próprio (que resolve o link server-side).
  /// Este atalho continua funcionando para não quebrar quem já o configura.
  @Deprecated('Use GoogleLocationPickerApi.corsProxy. '
      'Este atalho será removido numa próxima major.')
  static String get corsProxy => GoogleLocationPickerApi.corsProxy;

  @Deprecated('Use GoogleLocationPickerApi.corsProxy. '
      'Este atalho será removido numa próxima major.')
  static set corsProxy(String value) =>
      GoogleLocationPickerApi.corsProxy = value;

  /// Esvazia os caches de geocoding. Usado nos testes para evitar que um caso
  /// veja o resultado cacheado por outro.
  @visibleForTesting
  static void clearGeocodeCache() {
    _reverseCache.clear();
    _reverseInFlight.clear();
    _forwardCache.clear();
    _forwardInFlight.clear();
  }

  /// Reverse geocoding: dado um `latLng`, devolve um [LocationResult] com
  /// `address`, `placeId` e `locationAddress`. Retorna `null` se a chamada
  /// falhar ou não houver resultados.
  ///
  /// O resultado é cacheado por coordenada (~11 m) + idioma, e chamadas
  /// concorrentes do mesmo ponto compartilham uma única requisição. Delega a
  /// rede para [LocationPickerApi.instance].
  static Future<LocationResult?> reverseGeocode({
    required String apiKey,
    required LatLng latLng,
    String language = 'en',
  }) {
    return _cached(
      key: _coordKey(latLng, language),
      cache: _reverseCache,
      inFlight: _reverseInFlight,
      fetch: () => LocationPickerApi.instance.reverseGeocode(
        apiKey: apiKey,
        latLng: latLng,
        language: language,
      ),
    );
  }

  /// Forward geocoding: dado um `address` em texto livre, devolve um
  /// [LocationResult] com `latLng` preenchido. Mesmo contrato de cache do
  /// [reverseGeocode], chaveado pelo endereço normalizado.
  static Future<LocationResult?> forwardGeocode({
    required String apiKey,
    required String address,
    String language = 'en',
  }) {
    if (address.trim().isEmpty) return Future.value(null);

    return _cached(
      key: _addressKey(address, language),
      cache: _forwardCache,
      inFlight: _forwardInFlight,
      fetch: () => LocationPickerApi.instance.forwardGeocode(
        apiKey: apiKey,
        address: address,
        language: language,
      ),
    );
  }

  /// Cache + single-flight. O single-flight é o que importa para o custo: sem
  /// ele, chamadas simultâneas do mesmo ponto saem todas antes de qualquer uma
  /// preencher o cache.
  static Future<LocationResult?> _cached({
    required String key,
    required Map<String, LocationResult> cache,
    required Map<String, Future<LocationResult?>> inFlight,
    required Future<LocationResult?> Function() fetch,
  }) async {
    final LocationResult? hit = cache[key];
    if (hit != null) return hit;

    final Future<LocationResult?>? pending = inFlight[key];
    if (pending != null) return pending;

    final Future<LocationResult?> future = fetch();
    inFlight[key] = future;

    try {
      final LocationResult? result = await future;
      // `null` (falha de rede, ZERO_RESULTS) não é cacheado de propósito, para
      // não fixar uma falha temporária.
      if (result != null) cache[key] = result;
      return result;
    } finally {
      inFlight.remove(key);
    }
  }

  /// Resolve uma URL do Google Maps (inclusive links curtos) para um [LatLng].
  /// Delega para [LocationPickerApi.instance].
  static Future<LatLng?> resolveGoogleMapsUrl(String input) =>
      LocationPickerApi.instance.resolveMapsUrl(input);

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
    RegExp(
        r'/maps/(?:search|place|dir)/(-?\d+\.?\d*),(?:\+|%20|\s)*(-?\d+\.?\d*)'),
    // !3dlat!4dlng  (parâmetro data= em URLs de embed/share)
    RegExp(r'!3d(-?\d+\.?\d*)!4d(-?\d+\.?\d*)'),
  ];

  /// Extrai [LatLng] a partir de padrões conhecidos em URLs completas do
  /// Google Maps. Função pura — usada pela implementação de
  /// [LocationPickerApi] que expande links curtos.
  static LatLng? extractCoordsFromUrl(String url) {
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
}
