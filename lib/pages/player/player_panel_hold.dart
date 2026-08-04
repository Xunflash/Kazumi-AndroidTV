import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kazumi/bean/widget/collect_button.dart';
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

/// Binds a hover/menu widget lifecycle to a panel hold so callers do not manage
/// counters or menu identities by hand.
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
  PlayerPanelHold? _hold;

  @override
  void dispose() {
    _releaseHold();
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

  @override
  Widget build(BuildContext context) {
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: (hasFocus) {
        if (hasFocus) {
          _acquireHold();
        } else {
          _releaseHold();
        }
      },
      child: MouseRegion(
        cursor: widget.cursor,
        onEnter: (_) => _acquireHold(),
        onExit: (_) => _releaseHold(),
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
    this.consumeOutsideTap = false,
  });

  final PlayerPanelHold Function() acquirePlayerPanelHold;
  final ValueChanged<bool> onVisibilityChanged;
  final Widget Function(
    BuildContext context,
    MenuController controller,
    Widget? child,
  ) builder;
  final List<Widget> menuChildren;
  final bool consumeOutsideTap;

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
    _menuController.close();
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
      // menu anchors without replacing the MenuAnchor subtree.
      onBackButtonPressed: () => _handleSystemBackButton(),
      child: MenuAnchor(
        controller: _menuController,
        consumeOutsideTap: widget.consumeOutsideTap,
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
    required this.onVisibilityChanged,
    this.color = Colors.white,
    this.collectController,
  });

  final PlayerPanelHold Function() acquirePlayerPanelHold;
  final BangumiItem bangumiItem;
  final ValueChanged<bool> onVisibilityChanged;
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
    _menuController.close();
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
    widget.onVisibilityChanged(true);
    _acquireHold();
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
