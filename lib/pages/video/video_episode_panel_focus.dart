import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

int resolveVideoEpisodePanelFocusIndex({
  required int itemCount,
  required int selectedEpisode,
  required int selectedRoad,
  required int visibleRoad,
}) {
  if (itemCount <= 0) {
    return -1;
  }
  final selectedIndex = selectedEpisode - 1;
  if (selectedRoad == visibleRoad &&
      selectedIndex >= 0 &&
      selectedIndex < itemCount) {
    return selectedIndex;
  }
  return 0;
}

bool isVideoEpisodePanelBackKey(LogicalKeyboardKey key) {
  return key == LogicalKeyboardKey.goBack ||
      key == LogicalKeyboardKey.browserBack ||
      key == LogicalKeyboardKey.gameButtonB ||
      key == LogicalKeyboardKey.escape;
}

/// Keeps the paired system Back suppressed after the episode panel unmounts.
class VideoEpisodePanelBackGuard {
  bool _armed = false;
  int _generation = 0;

  bool get shouldConsumeSystemBack => _armed;

  void armUntilNextFrame() {
    _armed = true;
    final generation = ++_generation;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (generation == _generation) {
        _armed = false;
      }
    });
  }
}

/// Gives the TV episode panel its own autofocus scope and consumes Back before
/// the surrounding player route can react to the same remote event.
class VideoEpisodePanelFocusBoundary extends StatefulWidget {
  const VideoEpisodePanelFocusBoundary({
    super.key,
    required this.onClose,
    this.onRemoteBack,
    required this.child,
  });

  final VoidCallback onClose;
  final VoidCallback? onRemoteBack;
  final Widget child;

  @override
  State<VideoEpisodePanelFocusBoundary> createState() =>
      _VideoEpisodePanelFocusBoundaryState();
}

class _VideoEpisodePanelFocusBoundaryState
    extends State<VideoEpisodePanelFocusBoundary> {
  bool _consumePairedSystemBack = false;

  void _closeForRemoteBack() {
    _consumePairedSystemBack = true;
    (widget.onRemoteBack ?? widget.onClose)();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _consumePairedSystemBack = false;
      }
    });
  }

  KeyEventResult _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent ||
        !isVideoEpisodePanelBackKey(event.logicalKey)) {
      return KeyEventResult.ignored;
    }
    _closeForRemoteBack();
    return KeyEventResult.handled;
  }

  Future<bool> _handleSystemBackButton() async {
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) {
      return false;
    }
    if (_consumePairedSystemBack) {
      return true;
    }
    widget.onClose();
    return true;
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.maybeNavigationModeOf(context) !=
        NavigationMode.directional) {
      return widget.child;
    }
    return BackButtonListener(
      onBackButtonPressed: _handleSystemBackButton,
      child: Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onKeyEvent: (_, event) => _handleKeyEvent(event),
        child: FocusScope(
          debugLabel: 'video episode panel',
          child: widget.child,
        ),
      ),
    );
  }
}
