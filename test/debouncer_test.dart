import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_map_location_picker/src/utils/debouncer.dart';

void main() {
  const Duration janela = Duration(milliseconds: 400);

  test('a ação só dispara depois da janela', () {
    fakeAsync((async) {
      int calls = 0;
      final debouncer = Debouncer(janela);

      debouncer.run(() => calls++);
      expect(calls, 0, reason: 'não pode disparar de imediato');

      async.elapse(const Duration(milliseconds: 399));
      expect(calls, 0);

      async.elapse(const Duration(milliseconds: 1));
      expect(calls, 1);
    });
  });

  test('chamadas seguidas colapsam em uma só', () {
    // É o caso do mapa: arrastar em etapas dispara um onCameraIdle por pausa,
    // e cada um seria um geocode cobrado.
    fakeAsync((async) {
      int calls = 0;
      final debouncer = Debouncer(janela);

      for (int i = 0; i < 5; i++) {
        debouncer.run(() => calls++);
        async.elapse(const Duration(milliseconds: 100));
      }
      expect(calls, 0, reason: 'nenhuma pausa durou a janela inteira');

      async.elapse(janela);
      expect(calls, 1, reason: 'só a última posição é consultada');
    });
  });

  test('vale a última ação agendada, não a primeira', () {
    fakeAsync((async) {
      final List<String> vistos = [];
      final debouncer = Debouncer(janela);

      debouncer.run(() => vistos.add('antiga'));
      async.elapse(const Duration(milliseconds: 100));
      debouncer.run(() => vistos.add('nova'));

      async.elapse(janela);
      expect(vistos, ['nova']);
    });
  });

  group('flush', () {
    test('executa na hora a ação pendente', () {
      // O botão de confirmar não pode esperar a janela: devolveria a posição
      // anterior à do pin na tela.
      fakeAsync((async) {
        int calls = 0;
        final debouncer = Debouncer(janela);

        debouncer.run(() => calls++);
        expect(calls, 0);

        debouncer.flush();
        expect(calls, 1);

        // Não pode disparar de novo quando a janela vencer.
        async.elapse(janela);
        expect(calls, 1);
      });
    });

    test('sem nada pendente é inofensivo', () {
      fakeAsync((async) {
        expect(() => Debouncer(janela).flush(), returnsNormally);
        async.elapse(janela);
      });
    });
  });

  group('cancel', () {
    test('descarta a ação sem executá-la', () {
      // É o que acontece quando a câmera volta a se mover: a consulta agendada
      // na pausa anterior perdeu o sentido.
      fakeAsync((async) {
        int calls = 0;
        final debouncer = Debouncer(janela);

        debouncer.run(() => calls++);
        debouncer.cancel();

        async.elapse(janela * 2);
        expect(calls, 0);
      });
    });

    test('dispose cancela o que estiver pendente', () {
      fakeAsync((async) {
        int calls = 0;
        final debouncer = Debouncer(janela);

        debouncer.run(() => calls++);
        debouncer.dispose();

        async.elapse(janela * 2);
        expect(calls, 0, reason: 'não pode disparar após o unmount');
      });
    });
  });

  test('Duration.zero executa de imediato', () {
    fakeAsync((async) {
      int calls = 0;
      final debouncer = Debouncer(Duration.zero);

      debouncer.run(() => calls++);
      expect(calls, 1, reason: 'é a forma de desligar o atraso');
      expect(debouncer.isPending, isFalse);
    });
  });

  test('isPending reflete o estado', () {
    fakeAsync((async) {
      final debouncer = Debouncer(janela);
      expect(debouncer.isPending, isFalse);

      debouncer.run(() {});
      expect(debouncer.isPending, isTrue);

      async.elapse(janela);
      expect(debouncer.isPending, isFalse);
    });
  });
}
