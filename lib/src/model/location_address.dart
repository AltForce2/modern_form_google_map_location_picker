/// Componentes de endereço extraídos de `address_components` do Geocoding /
/// Places API.
///
/// Os campos usam camelCase, mas as chaves de [toMap] permanecem em snake_case
/// porque são formato de fio: consumidores que persistiram endereços
/// serializados precisam continuar conseguindo lê-los.
class LocationAddress {
  String? streetNumber;
  String? route;
  String? sublocalityLevel1;
  String? administrativeAreaLevel1;
  String? administrativeAreaLevel2;
  String? country;
  String? postalCode;

  LocationAddress({
    this.streetNumber,
    this.route,
    this.sublocalityLevel1,
    this.administrativeAreaLevel1,
    this.administrativeAreaLevel2,
    this.country,
    this.postalCode,
  });

  LocationAddress copyWith({
    String? streetNumber,
    String? route,
    String? sublocalityLevel1,
    String? administrativeAreaLevel1,
    String? administrativeAreaLevel2,
    String? country,
    String? postalCode,
  }) {
    return LocationAddress(
      streetNumber: streetNumber ?? this.streetNumber,
      route: route ?? this.route,
      sublocalityLevel1: sublocalityLevel1 ?? this.sublocalityLevel1,
      administrativeAreaLevel1:
          administrativeAreaLevel1 ?? this.administrativeAreaLevel1,
      administrativeAreaLevel2:
          administrativeAreaLevel2 ?? this.administrativeAreaLevel2,
      country: country ?? this.country,
      postalCode: postalCode ?? this.postalCode,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'street_number': streetNumber,
      'route': route,
      'sublocality_level_1': sublocalityLevel1,
      'administrative_area_level_1': administrativeAreaLevel1,
      'administrative_area_level_2': administrativeAreaLevel2,
      'country': country,
      'postal_code': postalCode,
    };
  }

  /// Constrói a partir de um `results[0]` do Geocoding ou de um `result` do
  /// Places Details. Tolera a ausência de `address_components` — o Places
  /// Details não retorna esse campo para alguns tipos de place (cidade,
  /// estabelecimento), e o acesso direto estourava.
  factory LocationAddress.fromMap(Map<String, dynamic>? map) {
    final LocationAddress address = LocationAddress();
    if (map == null) return address;

    final List<dynamic>? components =
        map['address_components'] as List<dynamic>?;
    if (components == null) return address;

    for (final component in components) {
      if (component is! Map) continue;

      final List<dynamic> types =
          (component['types'] as List<dynamic>?) ?? const <dynamic>[];
      final String? longName = component['long_name'] as String?;
      if (longName == null) continue;

      if (types.contains('street_number')) address.streetNumber = longName;
      if (types.contains('route')) address.route = longName;
      if (types.contains('sublocality_level_1')) {
        address.sublocalityLevel1 = longName;
      }
      if (types.contains('administrative_area_level_1')) {
        address.administrativeAreaLevel1 = longName;
      }
      if (types.contains('administrative_area_level_2')) {
        address.administrativeAreaLevel2 = longName;
      }
      if (types.contains('country')) address.country = longName;
      if (types.contains('postal_code')) address.postalCode = longName;
    }

    return address;
  }

  @override
  String toString() {
    return 'LocationAddress(streetNumber: $streetNumber, route: $route, '
        'sublocalityLevel1: $sublocalityLevel1, '
        'administrativeAreaLevel1: $administrativeAreaLevel1, '
        'administrativeAreaLevel2: $administrativeAreaLevel2, '
        'country: $country, postalCode: $postalCode)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is LocationAddress &&
        other.streetNumber == streetNumber &&
        other.route == route &&
        other.sublocalityLevel1 == sublocalityLevel1 &&
        other.administrativeAreaLevel1 == administrativeAreaLevel1 &&
        other.administrativeAreaLevel2 == administrativeAreaLevel2 &&
        other.country == country &&
        other.postalCode == postalCode;
  }

  @override
  int get hashCode {
    return Object.hash(
      streetNumber,
      route,
      sublocalityLevel1,
      administrativeAreaLevel1,
      administrativeAreaLevel2,
      country,
      postalCode,
    );
  }
}
