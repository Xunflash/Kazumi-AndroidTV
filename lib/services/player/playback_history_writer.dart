import 'dart:async';

typedef PlaybackHistoryWrite = Future<void> Function();
typedef PlaybackHistoryWriteError = void Function(
    Object error, StackTrace stackTrace);

/// Keeps only the newest playback-history snapshot between disk writes.
class PlaybackHistoryWriter {
  PlaybackHistoryWriter({
    this.interval = const Duration(seconds: 10),
    this.onError,
  });

  final Duration interval;
  final PlaybackHistoryWriteError? onError;

  PlaybackHistoryWrite? _pending;
  Timer? _timer;
  Future<void> _tail = Future<void>.value();
  Future<void>? _closeFuture;
  bool _closed = false;

  void schedule(PlaybackHistoryWrite write) {
    if (_closed) {
      return;
    }
    _pending = write;
    _armTimer();
  }

  /// Persists the newest pending snapshot after any write already in flight.
  Future<void> flush() {
    _timer?.cancel();
    _timer = null;
    return _enqueue(drainAll: true);
  }

  Future<void> close() {
    final existing = _closeFuture;
    if (existing != null) {
      return existing;
    }
    _closed = true;
    _timer?.cancel();
    _timer = null;
    return _closeFuture = _enqueue(drainAll: true);
  }

  void _armTimer() {
    if (_closed || _pending == null || _timer != null) {
      return;
    }
    _timer = Timer(interval, _onTimer);
  }

  void _onTimer() {
    _timer = null;
    final operation = _enqueue(drainAll: false);
    unawaited(
      operation.then<void>(
        (_) => _armTimer(),
        onError: (Object error, StackTrace stackTrace) {
          onError?.call(error, stackTrace);
          _armTimer();
        },
      ),
    );
  }

  Future<void> _enqueue({required bool drainAll}) {
    final operation = _tail.then((_) async {
      do {
        final write = _pending;
        if (write == null) {
          return;
        }
        _pending = null;
        try {
          await write();
        } catch (_) {
          _pending ??= write;
          rethrow;
        }
      } while (drainAll);
    });

    // A failed persistence must not poison later forced writes.
    _tail = operation.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return operation;
  }
}
