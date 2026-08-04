import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/services/player/playback_history_writer.dart';

void main() {
  test('periodic persistence keeps only the newest snapshot', () async {
    final writes = <int>[];
    final completed = Completer<void>();
    final writer = PlaybackHistoryWriter(
      interval: const Duration(milliseconds: 10),
    );

    writer.schedule(() async => writes.add(1));
    writer.schedule(() async => writes.add(2));
    writer.schedule(() async {
      writes.add(3);
      completed.complete();
    });

    await completed.future.timeout(const Duration(seconds: 1));
    expect(writes, [3]);
    await writer.close();
  });

  test('flush persists the latest snapshot immediately', () async {
    final writes = <int>[];
    final writer = PlaybackHistoryWriter();

    writer.schedule(() async => writes.add(1));
    writer.schedule(() async => writes.add(8));
    await writer.flush();

    expect(writes, [8]);
    await writer.close();
  });

  test(
    'flush does not lose an update arriving during an active write',
    () async {
      final writes = <int>[];
      final firstStarted = Completer<void>();
      final releaseFirst = Completer<void>();
      final writer = PlaybackHistoryWriter(
        interval: const Duration(milliseconds: 1),
      );

      writer.schedule(() async {
        writes.add(1);
        firstStarted.complete();
        await releaseFirst.future;
      });
      await firstStarted.future.timeout(const Duration(seconds: 1));

      writer.schedule(() async => writes.add(2));
      final flush = writer.flush();
      releaseFirst.complete();
      await flush;

      expect(writes, [1, 2]);
      await writer.close();
    },
  );
}
