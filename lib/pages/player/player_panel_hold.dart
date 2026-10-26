import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kazumi/bean/widget/collect_button.dart';
import 'package:kazumi/bean/widget/kazumi_menu.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/pages/collect/collect_controller.dart';

bool isPlayerPanelMenuDismissKey(LogicalKeyboardKey key) {
  return key == LogicalKeyboardKey.goBack ||
      key == LogicalKeyboardKey.browserBack ||
      key == LogicalKeyboardKey.gameButtonB ||
      key == LogicalKeyboardKey.escape;
}

/// A one-shot lease that keeps the player panel visible until released.
class PlayerPanelHold {
  PlayerPanelHold({required VoidCallback onRelease}) : _onRelease = onRelease;

  VoidCallback? _onRelease;

  bool get isReleased => _onRelease == null;

  void release() {
    final onRelease = _onRelease;
    if (onRelease == null) {
      return;
    }
    _onRelease = null;
    onRelease();
  }

  void releaseSilently() {
    _onRelease = null;
  }
}

/// Release focus holds when resizing removes the input but preserves its panel.
class PlayerPanelHoldFocusRegion extends StatefulWidget {
  const PlayerPanelHoldFocusRegion({
    super.key,
    required this.acquirePlayerPanelHold,
    required this.child,
  });

  final PlayerPanelHold Function() acquirePlayerPanelHold;
  final Widget child;

  @override
  State<PlayerPanelHoldFocusRegion> createState() =>
      _PlayerPanelHoldFocusRegionState();
}

class _PlayerPanelHoldFocusRegionState
    extends State<PlayerPanelHoldFocusRegion> {
  PlayerPanelHold? _hold;

  void _onFocusChange(bool focused) {
    if (focused) {
      _hold ??= widget.acquirePlayerPanelHold();
    } else {
      _hold?.release();
      _hold = null;
    }
  }

  @override
  void dispose() {
    _hold?.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Focus(
    canRequestFocus: false,
    onFocusChange: _onFocusChange,
    child: widget.child,
  );
}

/// Release hover holds when their controls unmount.
///
/// Focus is tracked separately so a D-pad highlight keeps the panel up without
/// cancelling an in-progress hover hold.
class PlayerPanelHoldMouseRegion extends StatefulWidget {
  const PlayerPanelHoldMouseRegion({
    super.key,
    required this.acquirePlayerPanelHold,
    required this.child,
    this.cursor = MouseCursor.defer,
  });

  final PlayerPanelHold Function() acquirePlayerPanelHold;
  final Widget child;
  final MouseCursor cursor;

  @override
  State<PlayerPanelHoldMouseRegion> createState() =>
      _PlayerPanelHoldMouseRegionState();
}

class _PlayerPanelHoldMouseRegionState
    extends State<PlayerPanelHoldMouseRegion> {
  PlayerPanelHold? _hoverHold;
  PlayerPanelHold? _focusHold;

  @override
  void dispose() {
    _releaseHoverHold();
    _releaseFocusHold();
    super.dispose();
  }

  void _acquireHoverHold() {
    if (_hoverHold?.isReleased == false) {
      return;
    }
    _hoverHold = widget.acquirePlayerPanelHold();
  }

  void _releaseHoverHold() {
    _hoverHold?.release();
    _hoverHold = null;
  }

  void _onFocusChange(bool hasFocus) {
    if (hasFocus) {
      if (_focusHold?.isReleased == false) {
        return;
      }
      _focusHold = widget.acquirePlayerPanelHold();
    } else {
      _releaseFocusHold();
    }
  }

  void _releaseFocusHold() {
    _focusHold?.release();
    _focusHold = null;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: _onFocusChange,
      child: MouseRegion(
        cursor: widget.cursor,
        onEnter: (_) => _acquireHoverHold(),
        onExit: (_) => _releaseHoverHold(),
        child: widget.child,
      ),
    );
  }
}

class PlayerPanelHoldMenuAnchor extends StatefulWidget {
  const PlayerPanelHoldMenuAnchor({
    super.key,
    required this.acquirePlayerPanelHold,
    required this.onVisibilityChanged,
    required this.builder,
    required this.menuChildren,
  });

  final PlayerPanelHold Function() acquirePlayerPanelHold;
  final ValueChanged<bool> onVisibilityChanged;
  final KazumiMenuBuilder builder;
  final List<Widget> menuChildren;

  @override
  State<PlayerPanelHoldMenuAnchor> createState() =>
      _PlayerPanelHoldMenuAnchorState();
}

class _PlayerPanelHoldMenuAnchorState extends State<PlayerPanelHoldMenuAnchor> {
  final MenuController _menuController = MenuController();
  PlayerPanelHold? _hold;
  bool _isOpen = false;
  bool _keyHandlerRegistered = false;
  bool _consumePairedSystemBack = false;

  KeyEventResult _handleMenuKeyEvent(KeyEvent event) {
    final route = ModalRoute.of(context);
    if ((route != null && !route.isCurrent) ||
        !_isOpen ||
        event is! KeyDownEvent ||
        !isPlayerPanelMenuDismissKey(event.logicalKey)) {
      return KeyEventResult.ignored;
    }
    _closeMenuForBack();
    return KeyEventResult.handled;
  }

  void _closeMenuForBack() {
    _consumePairedSystemBack = true;
    if (_menuController.isOpen) {
      _menuController.close();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _consumePairedSystemBack = false;
      }
    });
  }

  Future<bool> _handleSystemBackButton() async {
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) {
      return false;
    }
    if (_consumePairedSystemBack) {
      return true;
    }
    if (!_menuController.isOpen) {
      return false;
    }
    _closeMenuForBack();
    return true;
  }

  @override
  void dispose() {
    _handleClose();
    super.dispose();
  }

  void _handleOpen() {
    if (_isOpen) {
      return;
    }
    setState(() {
      _isOpen = true;
      _consumePairedSystemBack = false;
    });
    FocusManager.instance.addEarlyKeyEventHandler(_handleMenuKeyEvent);
    _keyHandlerRegistered = true;
    widget.onVisibilityChanged(true);
    if (_hold?.isReleased == false) {
      return;
    }
    _hold = widget.acquirePlayerPanelHold();
  }

  void _handleClose() {
    if (_keyHandlerRegistered) {
      FocusManager.instance.removeEarlyKeyEventHandler(_handleMenuKeyEvent);
      _keyHandlerRegistered = false;
    }
    if (_isOpen) {
      _isOpen = false;
      widget.onVisibilityChanged(false);
    }
    _hold?.release();
    _hold = null;
  }

  @override
  Widget build(BuildContext context) {
    return BackButtonListener(
      // Rebuilding on open gives this listener priority over closed sibling
      // menu anchors without replacing the menu subtree.
      onBackButtonPressed: () => _handleSystemBackButton(),
      child: KazumiMenuButton(
        controller: _menuController,
        animated: false,
        onOpen: _handleOpen,
        onClose: _handleClose,
        builder: widget.builder,
        menuChildren: widget.menuChildren,
      ),
    );
  }
}

class PlayerPanelHoldCollectButton extends StatefulWidget {
  const PlayerPanelHoldCollectButton({
    super.key,
    required this.acquirePlayerPanelHold,
    required this.bangumiItem,
    this.onVisibilityChanged,
    this.color = Colors.white,
    this.collectController,
  });

  final PlayerPanelHold Function() acquirePlayerPanelHold;
  final BangumiItem bangumiItem;
  final ValueChanged<bool>? onVisibilityChanged;
  final Color color;
  final CollectController? collectController;

  @override
  State<PlayerPanelHoldCollectButton> createState() =>
      _PlayerPanelHoldCollectButtonState();
}

class _PlayerPanelHoldCollectButtonState
    extends State<PlayerPanelHoldCollectButton> {
  final MenuController _menuController = MenuController();
  PlayerPanelHold? _hold;
  bool _isOpen = false;
  bool _keyHandlerRegistered = false;
  bool _consumePairedSystemBack = false;

  KeyEventResult _handleMenuKeyEvent(KeyEvent event) {
    final route = ModalRoute.of(context);
    if ((route != null && !route.isCurrent) ||
        !_isOpen ||
        event is! KeyDownEvent ||
        !isPlayerPanelMenuDismissKey(event.logicalKey)) {
      return KeyEventResult.ignored;
    }
    _closeMenuForBack();
    return KeyEventResult.handled;
  }

  void _closeMenuForBack() {
    _consumePairedSystemBack = true;
    if (_menuController.isOpen) {
      _menuController.close();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _consumePairedSystemBack = false;
      }
    });
  }

  Future<bool> _handleSystemBackButton() async {
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) {
      return false;
    }
    if (_consumePairedSystemBack) {
      return true;
    }
    if (!_menuController.isOpen) {
      return false;
    }
    _closeMenuForBack();
    return true;
  }

  @override
  void dispose() {
    _handleClose();
    super.dispose();
  }

  void _acquireHold() {
    if (_hold?.isReleased == false) {
      return;
    }
    _hold = widget.acquirePlayerPanelHold();
  }

  void _releaseHold() {
    _hold?.release();
    _hold = null;
  }

  void _handleOpen() {
    if (_isOpen) {
      return;
    }
    setState(() {
      _isOpen = true;
      _consumePairedSystemBack = false;
    });
    FocusManager.instance.addEarlyKeyEventHandler(_handleMenuKeyEvent);
    _keyHandlerRegistered = true;
    widget.onVisibilityChanged?.call(true);
    _acquireHold();
  }

  void _handleClose() {
    if (_keyHandlerRegistered) {
      FocusManager.instance.removeEarlyKeyEventHandler(_handleMenuKeyEvent);
      _keyHandlerRegistered = false;
    }
    if (_isOpen) {
      _isOpen = false;
      widget.onVisibilityChanged?.call(false);
    }
    _releaseHold();
  }

  @override
  Widget build(BuildContext context) {
    return BackButtonListener(
      onBackButtonPressed: _handleSystemBackButton,
      child: CollectButton(
        bangumiItem: widget.bangumiItem,
        color: widget.color,
        onOpen: _handleOpen,
        onClose: _handleClose,
        menuController: _menuController,
        collectController: widget.collectController,
      ),
    );
  }
}
