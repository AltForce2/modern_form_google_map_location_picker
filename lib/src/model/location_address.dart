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

  /// Sigla do estado (`SP`, `PR`) — o `short_name` de
  /// `administrative_area_level_1`.
  String? stateCode;

  /// Sigla ISO do país (`BR`) — o `short_name` de `country`.
  String? countryCode;

  /// Precisão do resultado: `ROOFTOP`, `RANGE_INTERPOLATED`,
  /// `GEOMETRIC_CENTER` ou `APPROXIMATE`.
  ///
  /// Vale usar na interface: em `APPROXIMATE` o endereço pode estar a centenas
  /// de metros do ponto real, e exibi-lo como exato induz o usuário ao erro.
  String? locationType;

  LocationAddress({
    this.streetNumber,
    this.route,
    this.sublocalityLevel1,
    this.administrativeAreaLevel1,
    this.administrativeAreaLevel2,
    this.country,
    this.postalCode,
    this.stateCode,
    this.countryCode,
    this.locationType,
  });

  LocationAddress copyWith({
    String? streetNumber,
    String? route,
    String? sublocalityLevel1,
    String? administrativeAreaLevel1,
    String? administrativeAreaLevel2,
    String? country,
    String? postalCode,
    String? stateCode,
    String? countryCode,
    String? locationType,
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
      stateCode: stateCode ?? this.stateCode,
      countryCode: countryCode ?? this.countryCode,
      locationType: locationType ?? this.locationType,
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
      // Chaves novas: aditivas, então dados serializados antes destes campos
      // continuam sendo lidos sem ajuste.
      'state_code': stateCode,
      'country_code': countryCode,
      'location_type': locationType,
    };
  }

  /// Constrói a partir de um `results[0]` do Geocoding ou de um `result` do
  /// Places Details. Tolera a ausência de `address_components` — o Places
  /// Details não retorna esse campo para alguns tipos de place (cidade,
  /// estabelecimento), e o acesso direto estourava.
  factory LocationAddress.fromMap(Map<String, dynamic>? map) {
    final LocationAddress address = LocationAddress();
    if (map == null) return address;

    // `location_type` vive em `geometry`, fora de `address_components` — por
    // isso é lido antes do early-return abaixo.
    final Map<String, dynamic>? geometry =
        map['geometry'] as Map<String, dynamic>?;
    address.locationType = geometry?['location_type'] as String?;

    final List<dynamic>? components =
        map['address_components'] as List<dynamic>?;
    if (components == null) return address;

    for (final component in components) {
      if (component is! Map) continue;

      final List<dynamic> types =
          (component['types'] as List<dynamic>?) ?? const <dynamic>[];
      final String? longName = component['long_name'] as String?;
      final String? shortName = component['short_name'] as String?;
      if (longName == null) continue;

      if (types.contains('street_number')) address.streetNumber = longName;
      if (types.contains('route')) address.route = longName;
      if (types.contains('sublocality_level_1')) {
        address.sublocalityLevel1 = longName;
      }
      if (types.contains('administrative_area_level_1')) {
        address.administrativeAreaLevel1 = longName;
        address.stateCode = shortName;
      }
      if (types.contains('administrative_area_level_2')) {
        address.administrativeAreaLevel2 = longName;
      }
      if (types.contains('country')) {
        address.country = longName;
        address.countryCode = shortName;
      }
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
        'country: $country, postalCode: $postalCode, '
        'stateCode: $stateCode, countryCode: $countryCode, '
        'locationType: $locationType)';
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
        other.postalCode == postalCode &&
        other.stateCode == stateCode &&
        other.countryCode == countryCode &&
        other.locationType == locationType;
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
      stateCode,
      countryCode,
      locationType,
    );
  }
}
