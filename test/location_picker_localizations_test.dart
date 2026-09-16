import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_map_location_picker/google_map_location_picker.dart';

/// Monta o pacote como o app monta (delegate registrado no `MaterialApp`) e
/// devolve os textos resolvidos para [locale].
///
/// Testar pelo delegate, e não lendo o ARB, é o que pega renomeação silenciosa:
/// trocar o nome da classe, do arquivo gerado ou de uma chave quebra aqui antes
/// de quebrar o build do app.
Future<GoogleMapLocationPickerLocalizations> _textsFor(
  WidgetTester tester,
  Locale locale,
) async {
  late GoogleMapLocationPickerLocalizations texts;

  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates:
          GoogleMapLocationPickerLocalizations.localizationsDelegates,
      supportedLocales: GoogleMapLocationPickerLocalizations.supportedLocales,
      home: Builder(
        builder: (BuildContext context) {
          texts = GoogleMapLocationPickerLocalizations.of(context);
          return const SizedBox.shrink();
        },
      ),
    ),
  );

  return texts;
}

void main() {
  group('os três idiomas do app', () {
    testWidgets('português', (WidgetTester tester) async {
      final texts = await _textsFor(tester, const Locale('pt'));

      expect(texts.findingPlace, 'Encontrando lugar...');
      expect(texts.noResultFound, 'Nenhum resultado encontrado');
      expect(texts.unnamedPlace, 'Lugar sem nome');
      expect(
        texts.unableToLoadTheMap,
        'Não foi possível carregar o mapa',
        reason: 'a falha do mapa não pode voltar a dizer "Erro de servidor"',
      );
      expect(
        texts.serverError,
        'Erro de servidor',
        reason: 'a chave genérica continua existindo, para o erro desconhecido',
      );
    });

    testWidgets('inglês', (WidgetTester tester) async {
      final texts = await _textsFor(tester, const Locale('en'));

      expect(texts.findingPlace, 'Finding place...');
      expect(texts.noResultFound, 'No result found');
      expect(texts.unnamedPlace, 'Unnamed place');
      expect(texts.unableToLoadTheMap, 'Unable to load the map');
    });

    testWidgets('espanhol', (WidgetTester tester) async {
      final texts = await _textsFor(tester, const Locale('es'));

      expect(texts.findingPlace, 'Buscando lugar ...');
      expect(texts.noResultFound, 'No se encontraron resultados');
      expect(texts.unnamedPlace, 'Lugar sin nombre');
      expect(texts.unableToLoadTheMap, 'No se pudo cargar el mapa');
    });
  });

  group('idiomas herdados do fork', () {
    testWidgets('chave sem tradução cai no template inglês, sem quebrar', (
      WidgetTester tester,
    ) async {
      // `fr` e `sr` não têm a chave nova, e o `sr` nunca teve estas duas.
      final fr = await _textsFor(tester, const Locale('fr'));
      expect(fr.findingPlace, 'En train de trouver un lieu...');
      expect(fr.unableToLoadTheMap, 'Unable to load the map');

      final sr = await _textsFor(tester, const Locale('sr'));
      expect(sr.noResultFound, 'Nema rezultata');
      expect(sr.unnamedPlace, 'Unnamed place');
      expect(
        sr.accessToLocationPermanentlyDenied,
        'Access to location permanently denied',
      );
    });

    testWidgets('o francês não fala italiano', (WidgetTester tester) async {
      // Veio errado do fork original: `unnamedPlace` estava em italiano.
      final texts = await _textsFor(tester, const Locale('fr'));

      expect(texts.unnamedPlace, 'Lieu sans nom');
    });
  });

  testWidgets('sem o delegate registrado, o texto falha em vez de sumir', (
    WidgetTester tester,
  ) async {
    // Antes do `gen-l10n` cada ponto de uso tinha um literal em inglês de
    // reserva, então esquecer o delegate passava despercebido até alguém
    // reclamar da tela em inglês. Agora quebra na cara de quem esqueceu.
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (BuildContext context) {
            GoogleMapLocationPickerLocalizations.of(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(tester.takeException(), isNotNull);
  });
}
