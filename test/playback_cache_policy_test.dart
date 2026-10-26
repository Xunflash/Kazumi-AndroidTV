import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/services/player/low_memory_mode.dart';
import 'package:kazumi/services/player/playback_cache_policy.dart';

void main() {
  const mib = 1024 * 1024;

  PlaybackCachePolicy policy({
    bool lowMemory = false,
    bool constrained = false,
    bool metered = false,
    bool local = false,
  }) {
    return PlaybackCachePolicy(
      isLocalPlayback: () => local,
      currentPlayer: () => null,
      lowMemoryMode: () => lowMemory ? LowMemoryMode.always : LowMemoryMode.auto,
      constrainedDevice: () => constrained,
      meteredNetwork: () => metered,
    );
  }

  test('keeps the existing cache size on an unconstrained device', () {
    final sizes = policy().cacheSizes;

    expect(sizes.forwardBytes, 1500 * mib);
    expect(sizes.backBytes, 1500 * mib);
  });

  test('uses an asymmetric cache on constrained Android devices', () {
    final cachePolicy = policy(constrained: true);

    expect(cachePolicy.cacheSizes.forwardBytes, 64 * mib);
    expect(cachePolicy.cacheSizes.backBytes, 16 * mib);
    expect(cachePolicy.bufferSize, 64 * mib);
  });

  test('explicit low-memory mode takes precedence over device tier', () {
    final sizes = policy(lowMemory: true, constrained: true).cacheSizes;

    expect(sizes.forwardBytes, 2 * mib);
    expect(sizes.backBytes, 2 * mib);
  });

  test('metered remote playback takes precedence over device tier', () {
    final sizes = policy(metered: true, constrained: true).cacheSizes;

    expect(sizes.forwardBytes, 2 * mib);
    expect(sizes.backBytes, 2 * mib);
  });

  test('local playback is exempt only from the metered override', () {
    expect(
      policy(metered: true, local: true).cacheSizes.forwardBytes,
      1500 * mib,
    );
    expect(
      policy(
        metered: true,
        local: true,
        constrained: true,
      ).cacheSizes.forwardBytes,
      64 * mib,
    );
    expect(
      policy(
        lowMemory: true,
        metered: true,
        local: true,
      ).cacheSizes.forwardBytes,
      2 * mib,
    );
  });
}
