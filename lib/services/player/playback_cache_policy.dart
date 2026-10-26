import 'dart:async';

import 'package:kazumi/services/logging/logger.dart';
import 'package:kazumi/services/network/metered_network_service.dart';
import 'package:kazumi/services/player/low_memory_mode.dart';
import 'package:kazumi/utils/async_serial_queue.dart';
import 'package:kazumi/utils/device.dart';
import 'package:media_kit/media_kit.dart';

class PlaybackCacheSizes {
  const PlaybackCacheSizes({
    required this.forwardBytes,
    required this.backBytes,
  });

  final int forwardBytes;
  final int backBytes;
}

/// Owns the demuxer cache size of the player returned by [currentPlayer].
///
/// [PlayerConfiguration] seeds the size so a failed write degrades to the right
/// value instead of the media_kit default; [apply] is authoritative.
class PlaybackCachePolicy {
  PlaybackCachePolicy({
    required bool Function() isLocalPlayback,
    required Player? Function() currentPlayer,
    bool Function()? constrainedDevice,
    LowMemoryMode Function()? lowMemoryMode,
    bool Function()? meteredNetwork,
  })  : _isLocalPlayback = isLocalPlayback,
        _currentPlayer = currentPlayer,
        _constrainedDevice = constrainedDevice ?? isConstrainedAndroidDevice,
        _lowMemoryMode = lowMemoryMode ?? (() => LowMemoryMode.current),
        _meteredNetwork =
            meteredNetwork ?? (() => MeteredNetworkService.isMetered);

  static const int _lowMemoryBufferSize = 2 * 1024 * 1024;
  static const int _constrainedForwardBufferSize = 64 * 1024 * 1024;
  static const int _constrainedBackBufferSize = 16 * 1024 * 1024;
  static const int _defaultBufferSize = 1500 * 1024 * 1024;

  final bool Function() _isLocalPlayback;
  final Player? Function() _currentPlayer;
  final bool Function() _constrainedDevice;
  final LowMemoryMode Function() _lowMemoryMode;
  final bool Function() _meteredNetwork;
  final AsyncSerialQueue _writes = AsyncSerialQueue();

  StreamSubscription<void>? _settingsSubscription;

  bool get networkAutomatic =>
      _lowMemoryMode() == LowMemoryMode.auto &&
      !_isLocalPlayback() &&
      _meteredNetwork();

  PlaybackCacheSizes get cacheSizes {
    if (_lowMemoryMode().isEnabled(
      isMetered: _meteredNetwork(),
      isLocalPlayback: _isLocalPlayback(),
    )) {
      return const PlaybackCacheSizes(
        forwardBytes: _lowMemoryBufferSize,
        backBytes: _lowMemoryBufferSize,
      );
    }
    if (_constrainedDevice()) {
      return const PlaybackCacheSizes(
        forwardBytes: _constrainedForwardBufferSize,
        backBytes: _constrainedBackBufferSize,
      );
    }
    return const PlaybackCacheSizes(
      forwardBytes: _defaultBufferSize,
      backBytes: _defaultBufferSize,
    );
  }

  /// The initial [PlayerConfiguration] accepts one size, so seed it with the
  /// forward cache and let [apply] configure both directions precisely.
  int get bufferSize => cacheSizes.forwardBytes;

  void startWatching() {
    if (_settingsSubscription != null) {
      return;
    }
    _settingsSubscription = LowMemoryMode.watch().listen((_) => _onChanged());
    MeteredNetworkService.listenable.addListener(_onChanged);
  }

  void stopWatching() {
    MeteredNetworkService.listenable.removeListener(_onChanged);
    unawaited(_settingsSubscription?.cancel());
    _settingsSubscription = null;
  }

  Future<void> apply() async {
    final player = _currentPlayer();
    if (player == null) {
      return;
    }
    try {
      final pp = player.platform as NativePlayer;
      // A stale player's initialization must not block its replacement's writes.
      await pp.waitForPlayerInitialization;
      await _writes.run(() async {
        if (!identical(_currentPlayer(), player)) {
          return;
        }
        final sizes = cacheSizes;
        await pp.setProperty(
          'demuxer-max-bytes',
          sizes.forwardBytes.toString(),
        );
        await pp.setProperty(
          'demuxer-max-back-bytes',
          sizes.backBytes.toString(),
        );
      });
    } catch (e) {
      KazumiLogger().w(
        'PlaybackCachePolicy: failed to apply demuxer cache size',
        error: e,
      );
    }
  }

  void _onChanged() {
    unawaited(apply());
  }
}
