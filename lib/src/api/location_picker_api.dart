import 'package:google_maps_flutter/google_maps_flutter.dart' show LatLng;

import '../model/location_address.dart';
import '../model/location_result.dart';
import 'google_location_picker_api.dart';

/// Sugestão de lugar devolvida pela busca. Modelo próprio do pacote — não
/// espelha o JSON do Google, justamente para que uma implementação alternativa
/// não precise imitar o formato dele.
class PlaceSuggestion {
  const PlaceSuggestion({
    required this.description,
    this.id,
    this.matchOffset = 0,
    this.matchLength = 0,
  });

  /// Identificador usado para pedir os detalhes depois. No Google é o
  /// `place_id`; numa API própria pode ser qualquer chave.
  final String? id;

  /// Texto exibido na lista de sugestões.
  final String description;

  /// Trecho de [description] a destacar (o que casou com a busca). Uma
  /// implementação que não tenha essa informação pode deixar em zero — a UI
  /// simplesmente não destaca nada.
  final int matchOffset;
  final int matchLength;
}

/// Detalhes de um lugar, já normalizados. Diferente da resposta crua do Places
/// Details: quem implementar esta interface devolve os campos prontos, sem
/// precisar replicar `geometry.location` ou `address_components`.
class PlaceDetails {
  const PlaceDetails({
    required this.latLng,
    this.formattedAddress,
    this.placeId,
    this.locationAddress,
  });

  final LatLng latLng;
  final String? formattedAddress;
  final String? placeId;
  final LocationAddress? locationAddress;

  LocationResult toLocationResult() => LocationResult(
        latLng: latLng,
        address: formattedAddress,
        placeId: placeId,
        locationAddress: locationAddress,
      );
}

/// Ponto único de acesso à rede do pacote. **Toda** requisição do picker passa
/// por aqui — não há `http` em nenhum widget.
///
/// Para deixar de bater direto no Google (por exemplo, para roteirizar por um
/// backend próprio com cache compartilhado entre usuários), implemente esta
/// classe e instale a sua versão antes de abrir o picker:
///
/// ```dart
/// void main() {
///   LocationPickerApi.instance = MinhaApi();
///   runApp(const MyApp());
/// }
/// ```
///
/// O `apiKey` continua sendo repassado em cada chamada porque vem do widget;
/// uma implementação que não fale com o Google pode simplesmente ignorá-lo.
///
/// Cache e deduplicação de chamadas concorrentes ficam **fora** desta
/// interface — `LocationPickerUtils.reverseGeocode`/`forwardGeocode` os
/// aplicam por cima de qualquer implementação, então a sua não precisa
/// reimplementá-los.
abstract class LocationPickerApi {
  const LocationPickerApi();

  /// Implementação em uso. Trocar este campo redireciona todas as chamadas do
  /// pacote. O default fala direto com as APIs do Google.
  static LocationPickerApi instance = const GoogleLocationPickerApi();

  /// Restaura a implementação padrão (Google).
  static void resetToDefault() {
    instance = const GoogleLocationPickerApi();
  }

  /// Coordenada → endereço. Devolve `null` quando não há resultado ou a
  /// chamada falha; não lance para sinalizar erro esperado.
  Future<LocationResult?> reverseGeocode({
    required String apiKey,
    required LatLng latLng,
    required String language,
  });

  /// Endereço em texto livre → coordenada.
  Future<LocationResult?> forwardGeocode({
    required String apiKey,
    required String address,
    required String language,
  });

  /// Sugestões para o campo de busca. Devolva lista vazia quando não houver
  /// resultado — a UI exibe "No result found".
  ///
  /// [sessionToken] existe por causa do billing por sessão do Places; uma
  /// implementação própria pode ignorá-lo.
  Future<List<PlaceSuggestion>> autocomplete({
    required String apiKey,
    required String input,
    required String language,
    required String sessionToken,
    List<String>? countries,
    LatLng? locationBias,
  });

  /// Detalhes da sugestão escolhida. O [placeId] é o [PlaceSuggestion.id]
  /// devolvido por [autocomplete].
  Future<PlaceDetails?> placeDetails({
    required String apiKey,
    required String placeId,
    required String language,
    required String sessionToken,
  });

  /// Resolve um link do Google Maps (inclusive encurtado) para coordenada.
  ///
  /// A implementação padrão segue os redirects no cliente, o que **não
  /// funciona no Flutter Web** (CORS bloqueia a leitura do header `Location`).
  /// Resolver isso por um backend próprio é um dos motivos para trocar esta
  /// implementação.
  Future<LatLng?> resolveMapsUrl(String url);
}
