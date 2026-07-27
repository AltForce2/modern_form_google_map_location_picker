import 'package:flutter_test/flutter_test.dart';
import 'package:google_map_location_picker/src/utils/location_utils.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' show LatLng;

void main() {
  group('parseLatLng', () {
    test('aceita par com ponto decimal', () {
      final result = LocationPickerUtils.parseLatLng('-23.5505, -46.6333');
      expect(result, isNotNull);
      expect(result!.latitude, closeTo(-23.5505, 1e-9));
      expect(result.longitude, closeTo(-46.6333, 1e-9));
    });

    test('aceita notação europeia com vírgula decimal', () {
      final result = LocationPickerUtils.parseLatLng('-23,5505, -46,6333');
      expect(result, isNotNull);
      expect(result!.latitude, closeTo(-23.5505, 1e-9));
      expect(result.longitude, closeTo(-46.6333, 1e-9));
    });

    test('aceita inteiros e tolera espaçamento', () {
      expect(LocationPickerUtils.parseLatLng('10,20'), isNotNull);
      expect(LocationPickerUtils.parseLatLng('  10 , 20  '), isNotNull);
    });

    test('"1,5" é lido como o par (1, 5), não como o decimal 1.5', () {
      // Ambiguidade real da notação europeia. Um número solto não é um par de
      // coordenadas, então a leitura como par é a única útil — este teste trava
      // a decisão para que ninguém a inverta sem perceber.
      final result = LocationPickerUtils.parseLatLng('1,5');
      expect(result, isNotNull);
      expect(result!.latitude, 1);
      expect(result.longitude, 5);
    });

    test('rejeita coordenadas fora de faixa', () {
      expect(LocationPickerUtils.parseLatLng('91, 0'), isNull);
      expect(LocationPickerUtils.parseLatLng('-91, 0'), isNull);
      expect(LocationPickerUtils.parseLatLng('0, 181'), isNull);
      expect(LocationPickerUtils.parseLatLng('0, -181'), isNull);
    });

    test('rejeita coordenada única sem par', () {
      // "-23,5505" casa como (-23, 5505) e é rejeitado pela faixa da longitude.
      expect(LocationPickerUtils.parseLatLng('-23,5505'), isNull);
    });

    test('não dispara em digitação parcial de endereço', () {
      expect(LocationPickerUtils.parseLatLng('Rua 25 de Março, 100'), isNull);
      expect(LocationPickerUtils.parseLatLng('Av Paulista'), isNull);
      expect(LocationPickerUtils.parseLatLng(''), isNull);
      expect(LocationPickerUtils.parseLatLng('-23.5505, -46.6333 SP'), isNull);
    });
  });

  group('isGoogleMapsUrl', () {
    test('reconhece os domínios suportados', () {
      const urls = <String>[
        'https://maps.app.goo.gl/abc123',
        'https://goo.gl/maps/abc123',
        'https://maps.google.com/?q=1,2',
        'https://www.google.com/maps/place/Foo',
      ];
      for (final url in urls) {
        expect(LocationPickerUtils.isGoogleMapsUrl(url), isTrue, reason: url);
      }
    });

    test('é case-insensitive e tolera espaços', () {
      expect(
        LocationPickerUtils.isGoogleMapsUrl('  HTTPS://MAPS.APP.GOO.GL/x  '),
        isTrue,
      );
    });

    test('rejeita o que não é URL do Maps', () {
      expect(LocationPickerUtils.isGoogleMapsUrl('https://example.com'), isFalse);
      expect(LocationPickerUtils.isGoogleMapsUrl('Rua das Flores, 100'), isFalse);
    });
  });

  group('extractCoordsFromUrl', () {
    void expectCoords(String url, double lat, double lng) {
      final LatLng? result = LocationPickerUtils.extractCoordsFromUrl(url);
      expect(result, isNotNull, reason: url);
      expect(result!.latitude, closeTo(lat, 1e-6), reason: url);
      expect(result.longitude, closeTo(lng, 1e-6), reason: url);
    }

    test('padrão @lat,lng', () {
      expectCoords(
        'https://www.google.com/maps/@-23.5505,-46.6333,15z',
        -23.5505,
        -46.6333,
      );
    });

    test('padrão ?q= e &query=', () {
      expectCoords('https://maps.google.com/?q=-23.5505,-46.6333', -23.5505,
          -46.6333);
      expectCoords(
        'https://www.google.com/maps/search/?api=1&query=10.5,20.25',
        10.5,
        20.25,
      );
    });

    test('padrão ll=', () {
      expectCoords('https://maps.google.com/?ll=1.5,2.5&z=10', 1.5, 2.5);
    });

    test('padrão !3d!4d do parâmetro data=', () {
      expectCoords(
        'https://www.google.com/maps/place/X/data=!3m1!4b1!3d-23.5505!4d-46.6333',
        -23.5505,
        -46.6333,
      );
    });

    test('coordenadas soltas no path (/maps/search|place|dir/lat,lng)', () {
      // Regressão da 9.5.2: sem este padrão o link caía no autocomplete e
      // dava "Nenhum resultado encontrado".
      expectCoords(
        'https://www.google.com/maps/search/-24.737106,-53.740050?entry=tts',
        -24.737106,
        -53.740050,
      );
      expectCoords(
        'https://www.google.com/maps/place/10.5,20.25',
        10.5,
        20.25,
      );
      expectCoords(
        'https://www.google.com/maps/dir/1.5,2.5',
        1.5,
        2.5,
      );
    });

    test('tolera espaço URL-encoded após a vírgula', () {
      // Links de busca compartilhados trazem `lat,+lng`.
      expectCoords(
        'https://www.google.com/maps/search/-24.737106,+-53.740050?entry=tts',
        -24.737106,
        -53.740050,
      );
      expectCoords(
        'https://maps.google.com/?q=-23.5505,%20-46.6333',
        -23.5505,
        -46.6333,
      );
      expectCoords(
        'https://maps.google.com/?q=-23.5505, -46.6333',
        -23.5505,
        -46.6333,
      );
    });

    test('devolve null sem padrão reconhecível', () {
      expect(
        LocationPickerUtils.extractCoordsFromUrl('https://maps.app.goo.gl/abc'),
        isNull,
      );
    });

    test('devolve null para coordenadas fora de faixa', () {
      expect(
        LocationPickerUtils.extractCoordsFromUrl('https://x/@91.0,0.0,15z'),
        isNull,
      );
    });
  });
}
