import 'dart:async';

import 'package:kazumi/services/logging/logger.dart';
import 'package:kazumi/services/network/metered_network_service.dart';
import 'package:kazumi/services/storage/storage.dart';
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
    required this.isLocalPlayback,
    required this.currentPlayer,
    bool Function()? lowMemoryEnabled,
    bool Function()? constrainedDevice,
    bool Function()? meteredNetwork,
  })  : _lowMemoryEnabled = lowMemoryEnabled ??
            (() => GStorage.getSetting<bool>(SettingsKeys.lowMemoryMode)),
        _constrainedDevice = constrainedDevice ?? isConstrainedAndroidDevice,
        _meteredNetwork =
            meteredNetwork ?? (() => MeteredNetworkService.isMetered);

  static const int _lowMemoryBufferSize = 2 * 1024 * 1024;
  static const int _constrainedForwardBufferSize = 64 * 1024 * 1024;
  static const int _constrainedBackBufferSize = 16 * 1024 * 1024;
  static const int _defaultBufferSize = 1500 * 1024 * 1024;

  final bool Function() isLocalPlayback;
  final Player? Function() currentPlayer;
  final bool Function() _lowMemoryEnabled;
  final bool Function() _constrainedDevice;
  final bool Function() _meteredNetwork;
  final AsyncSerialQueue _writes = AsyncSerialQueue();

  bool _watching = false;

  bool get _userEnabled => _lowMemoryEnabled();

  /// Temporary override; local playback is exempt because it costs no data.
  bool get networkForced =>
      !_userEnabled && !isLocalPlayback() && _meteredNetwork();

  PlaybackCacheSizes get cacheSizes {
    if (_userEnabled || networkForced) {
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
    if (_watching) {
      return;
    }
    _watching = true;
    MeteredNetworkService.listenable.addListener(_onNetworkChanged);
  }

  void stopWatching() {
    if (!_watching) {
      return;
    }
    _watching = false;
    MeteredNetworkService.listenable.removeListener(_onNetworkChanged);
  }

  /// Waits for initialization so the seed cannot land after this write. That
  /// wait stays outside the queue, where an unresolved one would stall every
  /// later write.
  Future<void> apply() async {
    final player = currentPlayer();
    if (player == null) {
      return;
    }
    try {
      final pp = player.platform as NativePlayer;
      await pp.waitForPlayerInitialization;
      await _writes.run(() async {
        if (!identical(currentPlayer(), player)) {
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

  void _onNetworkChanged() {
    unawaited(apply());
  }
}
