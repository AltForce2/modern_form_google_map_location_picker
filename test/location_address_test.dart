import 'package:flutter_test/flutter_test.dart';
import 'package:google_map_location_picker/src/model/location_address.dart';

void main() {
  Map<String, dynamic> component(String longName, List<String> types) => {
        'long_name': longName,
        'short_name': longName,
        'types': types,
      };

  group('LocationAddress.fromMap', () {
    test('extrai todos os componentes conhecidos', () {
      final address = LocationAddress.fromMap({
        'address_components': [
          component('100', ['street_number']),
          component('Rua Teste', ['route']),
          component('Bela Vista', ['sublocality_level_1', 'sublocality']),
          component('São Paulo', ['administrative_area_level_2']),
          component('SP', ['administrative_area_level_1']),
          component('Brasil', ['country', 'political']),
          component('01310-100', ['postal_code']),
        ],
      });

      expect(address.streetNumber, '100');
      expect(address.route, 'Rua Teste');
      expect(address.sublocalityLevel1, 'Bela Vista');
      expect(address.administrativeAreaLevel2, 'São Paulo');
      expect(address.administrativeAreaLevel1, 'SP');
      expect(address.country, 'Brasil');
      expect(address.postalCode, '01310-100');
    });

    test('devolve objeto vazio para map nulo', () {
      expect(LocationAddress.fromMap(null), LocationAddress());
    });

    test('tolera address_components ausente', () {
      // Caso real: Places Details de cidade/estabelecimento não traz o campo.
      // O acesso direto estourava aqui.
      expect(
        LocationAddress.fromMap({'formatted_address': 'X'}),
        LocationAddress(),
      );
    });

    test('tolera components malformados', () {
      final address = LocationAddress.fromMap({
        'address_components': [
          'não é um mapa',
          {'types': null, 'long_name': 'sem tipos'},
          {'types': ['route']}, // sem long_name
          component('Rua Boa', ['route']),
        ],
      });

      expect(address.route, 'Rua Boa');
    });

    test('extrai stateCode e countryCode do short_name', () {
      final address = LocationAddress.fromMap({
        'address_components': [
          {
            'long_name': 'Paraná',
            'short_name': 'PR',
            'types': ['administrative_area_level_1'],
          },
          {
            'long_name': 'Brasil',
            'short_name': 'BR',
            'types': ['country', 'political'],
          },
        ],
      });

      expect(address.administrativeAreaLevel1, 'Paraná');
      expect(address.stateCode, 'PR');
      expect(address.country, 'Brasil');
      expect(address.countryCode, 'BR');
    });

    test('extrai locationType de geometry', () {
      final address = LocationAddress.fromMap({
        'geometry': {
          'location_type': 'ROOFTOP',
          'location': {'lat': -23.5, 'lng': -46.6},
        },
        'address_components': [component('Rua Teste', ['route'])],
      });

      expect(address.locationType, 'ROOFTOP');
      expect(address.route, 'Rua Teste');
    });

    test('locationType é lido mesmo sem address_components', () {
      // O Places Details de cidade/estabelecimento não traz address_components,
      // mas traz geometry — o early-return não pode engolir o locationType.
      final address = LocationAddress.fromMap({
        'geometry': {'location_type': 'APPROXIMATE'},
      });

      expect(address.locationType, 'APPROXIMATE');
      expect(address.route, isNull);
    });

    test('os três campos novos ficam nulos quando o payload não os traz', () {
      final address = LocationAddress.fromMap({
        'address_components': [
          {
            'long_name': 'Paraná',
            'types': ['administrative_area_level_1'],
          },
        ],
      });

      expect(address.administrativeAreaLevel1, 'Paraná');
      expect(address.stateCode, isNull);
      expect(address.countryCode, isNull);
      expect(address.locationType, isNull);
    });

    test('ignora tipos desconhecidos', () {
      final address = LocationAddress.fromMap({
        'address_components': [
          component('Algo', ['premise', 'point_of_interest']),
        ],
      });

      expect(address, LocationAddress());
    });
  });

  group('serialização', () {
    test('toMap mantém as chaves em snake_case (formato de fio)', () {
      // Consumidores persistiram endereços com estas chaves; renomeá-las
      // quebraria a leitura de dados antigos.
      final map = LocationAddress(
        streetNumber: '100',
        route: 'Rua Teste',
        sublocalityLevel1: 'Bela Vista',
        administrativeAreaLevel1: 'SP',
        administrativeAreaLevel2: 'São Paulo',
        country: 'Brasil',
        postalCode: '01310-100',
      ).toMap();

      expect(map.keys, containsAll(<String>[
        'street_number',
        'route',
        'sublocality_level_1',
        'administrative_area_level_1',
        'administrative_area_level_2',
        'country',
        'postal_code',
      ]));
      expect(map['street_number'], '100');
      expect(map['postal_code'], '01310-100');
    });

    test('toMap expõe os campos novos em chaves aditivas', () {
      // Aditivas: quem serializou antes destes campos continua sendo lido.
      final map = LocationAddress(
        stateCode: 'PR',
        countryCode: 'BR',
        locationType: 'ROOFTOP',
      ).toMap();

      expect(map['state_code'], 'PR');
      expect(map['country_code'], 'BR');
      expect(map['location_type'], 'ROOFTOP');
    });

    test('copyWith substitui só o informado', () {
      final original = LocationAddress(route: 'A', country: 'BR');
      final copy = original.copyWith(route: 'B');

      expect(copy.route, 'B');
      expect(copy.country, 'BR');
      expect(original.route, 'A', reason: 'não deve mutar o original');
    });

    test('== e hashCode consideram todos os campos', () {
      final a = LocationAddress(route: 'A', postalCode: '1');
      final b = LocationAddress(route: 'A', postalCode: '1');
      final c = LocationAddress(route: 'A', postalCode: '2');

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
    });
  });
}
