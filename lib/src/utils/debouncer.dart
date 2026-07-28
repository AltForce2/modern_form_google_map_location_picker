import 'dart:async';

/// Adia a execução de uma ação até que ela pare de ser solicitada por
/// [duration].
///
/// Cada chamada a [run] descarta a anterior que ainda não disparou. Com
/// [duration] igual a `Duration.zero` a ação roda de imediato — é a forma de
/// desligar o comportamento sem espalhar `if` por quem usa.
class Debouncer {
  Debouncer(this.duration);

  final Duration duration;

  Timer? _timer;
  void Function()? _pending;

  /// `true` quando há uma ação aguardando para disparar.
  bool get isPending => _timer?.isActive ?? false;

  /// Agenda [action], substituindo o agendamento anterior.
  void run(void Function() action) {
    _timer?.cancel();

    if (duration == Duration.zero) {
      _pending = null;
      action();
      return;
    }

    _pending = action;
    _timer = Timer(duration, () {
      _pending = null;
      action();
    });
  }

  /// Executa agora a ação pendente, se houver, sem esperar o prazo.
  ///
  /// Serve para os momentos em que não dá para esperar — confirmar uma
  /// seleção, por exemplo, onde o valor precisa estar atualizado na hora.
  void flush() {
    if (!isPending) return;
    _timer?.cancel();
    _timer = null;
    final void Function()? action = _pending;
    _pending = null;
    action?.call();
  }

  /// Descarta a ação pendente sem executá-la.
  void cancel() {
    _timer?.cancel();
    _timer = null;
    _pending = null;
  }

  /// Alias de [cancel], para casar com o ciclo de vida de um `State`.
  void dispose() => cancel();
}
