import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:kazumi/utils/constants.dart';

typedef PlayerShortcutAction = FutureOr<void> Function();

const FocusOrder playerBottomControlsFocusOrder = NumericFocusOrder(1);
const FocusOrder playerTopControlsFocusOrder = NumericFocusOrder(2);
const FocusOrder playerTopLeadingControlsFocusOrder = NumericFocusOrder(3);

bool isPlayerDirectionalControlsExitKey(LogicalKeyboardKey key) {
  return key == LogicalKeyboardKey.arrowUp ||
      key == LogicalKeyboardKey.goBack ||
      key == LogicalKeyboardKey.browserBack ||
      key == LogicalKeyboardKey.gameButtonB ||
      key == LogicalKeyboardKey.escape;
}

class PlayerLongPressShortcutActions {
  const PlayerLongPressShortcutActions({
    required this.onRepeat,
    required this.onRelease,
  });

  final PlayerShortcutAction onRepeat;
  final PlayerShortcutAction onRelease;
}

/// Keeps TV player controls in a predictable, closed traversal loop.
///
/// The panel assigns [playerBottomControlsFocusOrder] and
/// [playerTopControlsFocusOrder] to its two visual control rows. Left and
/// right are translated to previous/next traversal by
/// [PlayerKeyboardShortcuts], so controls remain reachable even when they are
/// split across opposite sides of the screen.
class PlayerDirectionalControlsTraversal extends StatelessWidget {
  const PlayerDirectionalControlsTraversal({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.maybeNavigationModeOf(context) !=
        NavigationMode.directional) {
      return child;
    }
    return FocusScope(
      debugLabel: 'player directional controls',
      child: FocusTraversalGroup(
        policy: OrderedTraversalPolicy(),
        child: child,
      ),
    );
  }
}

/// Dispatches player shortcuts before focused controls handle the key event.
///
/// [focusScopeNode] must be attached to a stable ancestor of the player area.
/// Dialog routes and explicitly blocked overlay interactions keep their normal
/// key handling. Active long-press shortcuts are always released, even after
/// focus leaves the player or this widget is disposed.
class PlayerKeyboardShortcuts extends StatefulWidget {
  const PlayerKeyboardShortcuts({
    super.key,
    required this.focusScopeNode,
    required this.actions,
    this.longPressActions = const <String, PlayerLongPressShortcutActions>{},
    this.isBlocked,
    this.directionalControlsFocusNode,
    this.directionalControlsEnabled,
    this.directionalControlsVisible,
    this.onEnterDirectionalControls,
    this.onExitDirectionalControls,
    this.shortcuts,
  });

  final FocusNode focusScopeNode;
  final Map<String, PlayerShortcutAction> actions;
  final Map<String, PlayerLongPressShortcutActions> longPressActions;
  final bool Function()? isBlocked;
  final FocusNode? directionalControlsFocusNode;
  final bool Function()? directionalControlsEnabled;
  final bool Function()? directionalControlsVisible;
  final VoidCallback? onEnterDirectionalControls;
  final VoidCallback? onExitDirectionalControls;
  final Map<String, List<String>>? shortcuts;

  @override
  State<PlayerKeyboardShortcuts> createState() =>
      _PlayerKeyboardShortcutsState();
}

class _PlayerKeyboardShortcutsState extends State<PlayerKeyboardShortcuts> {
  late Map<String, List<String>> _shortcuts;
  final Map<LogicalKeyboardKey, PlayerLongPressShortcutActions>
      _activeLongPressKeys =
      <LogicalKeyboardKey, PlayerLongPressShortcutActions>{};

  @override
  void initState() {
    super.initState();
    _shortcuts = widget.shortcuts ?? _loadShortcuts();
    FocusManager.instance.addEarlyKeyEventHandler(_handleKeyEvent);
  }

  @override
  void didUpdateWidget(PlayerKeyboardShortcuts oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.shortcuts != oldWidget.shortcuts) {
      _shortcuts = widget.shortcuts ?? _loadShortcuts();
    }
  }

  @override
  void dispose() {
    FocusManager.instance.removeEarlyKeyEventHandler(_handleKeyEvent);
    _releaseAllLongPressShortcuts();
    super.dispose();
  }

  Map<String, List<String>> _loadShortcuts() {
    return <String, List<String>>{
      for (final entry in defaultShortcuts.entries)
        entry.key: GStorage.getStringListSettingByName(
          'shortcut_${entry.key}',
          defaultValue: entry.value,
        ),
    };
  }

  KeyEventResult _handleKeyEvent(KeyEvent event) {
    if (event is KeyUpEvent) {
      final longPressActions = _activeLongPressKeys.remove(event.logicalKey);
      if (longPressActions != null) {
        _invokeAction(longPressActions.onRelease);
        return KeyEventResult.handled;
      }
    }

    final primaryFocus = _primaryFocusInPlayer();
    if (primaryFocus == null) {
      return KeyEventResult.ignored;
    }

    final directionalControlsEnabled =
        widget.directionalControlsEnabled?.call() ?? false;
    if (primaryFocus != widget.focusScopeNode) {
      if (directionalControlsEnabled &&
          event is KeyDownEvent &&
          isPlayerDirectionalControlsExitKey(event.logicalKey)) {
        widget.focusScopeNode.requestFocus();
        widget.onExitDirectionalControls?.call();
        return KeyEventResult.handled;
      }
      if (directionalControlsEnabled &&
          (event is KeyDownEvent || event is KeyRepeatEvent)) {
        if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
          primaryFocus.previousFocus();
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
          primaryFocus.nextFocus();
          return KeyEventResult.handled;
        }
      }
      return KeyEventResult.ignored;
    }

    if (directionalControlsEnabled &&
        event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.arrowDown &&
        widget.directionalControlsFocusNode != null) {
      widget.onEnterDirectionalControls?.call();
      _focusDirectionalControlsAfterBuild();
      return KeyEventResult.handled;
    }

    final isHorizontalArrow =
        event.logicalKey == LogicalKeyboardKey.arrowLeft ||
            event.logicalKey == LogicalKeyboardKey.arrowRight;
    if (directionalControlsEnabled &&
        (widget.directionalControlsVisible?.call() ?? false) &&
        isHorizontalArrow &&
        (event is KeyDownEvent || event is KeyRepeatEvent)) {
      if (event is KeyDownEvent) {
        widget.onEnterDirectionalControls?.call();
        _focusDirectionalControlsAfterBuild();
      }
      return KeyEventResult.handled;
    }

    final keyLabel = event.logicalKey.keyLabel.isNotEmpty
        ? event.logicalKey.keyLabel
        : event.logicalKey.debugName ?? '';
    final actionName = directionalControlsEnabled
        ? _findTvDirectionalActionName(event.logicalKey) ??
            _findActionName(event.logicalKey, keyLabel)
        : _findActionName(event.logicalKey, keyLabel);
    if (actionName == null) {
      return KeyEventResult.ignored;
    }

    if (event is KeyDownEvent) {
      final action = widget.actions[actionName];
      if (action == null) {
        return KeyEventResult.ignored;
      }
      final longPressActions = widget.longPressActions[actionName];
      if (longPressActions != null) {
        _activeLongPressKeys[event.logicalKey] = longPressActions;
      }
      _invokeAction(action);
      return KeyEventResult.handled;
    }

    if (event is KeyRepeatEvent) {
      final longPressActions = _activeLongPressKeys[event.logicalKey];
      if (longPressActions == null) {
        return KeyEventResult.ignored;
      }
      _invokeAction(longPressActions.onRepeat);
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  FocusNode? _primaryFocusInPlayer() {
    if (widget.isBlocked?.call() ?? false) {
      return null;
    }

    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) {
      return null;
    }

    final primaryFocus = FocusManager.instance.primaryFocus;
    if (primaryFocus == null ||
        (primaryFocus != widget.focusScopeNode &&
            !primaryFocus.ancestors.contains(widget.focusScopeNode))) {
      return null;
    }

    final focusContext = primaryFocus.context;
    if (focusContext == null) {
      return primaryFocus;
    }
    if (focusContext.widget is EditableText ||
        focusContext.findAncestorWidgetOfExactType<EditableText>() != null) {
      return null;
    }
    return primaryFocus;
  }

  void _focusDirectionalControlsAfterBuild() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !(widget.directionalControlsEnabled?.call() ?? false)) {
        return;
      }
      final controlsFocusNode = widget.directionalControlsFocusNode;
      if (controlsFocusNode?.canRequestFocus ?? false) {
        controlsFocusNode!.requestFocus();
      }
    });
  }

  String? _findTvDirectionalActionName(LogicalKeyboardKey key) {
    if (key == LogicalKeyboardKey.arrowLeft) {
      return 'rewind';
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      return 'forward';
    }
    return null;
  }

  String? _findActionName(LogicalKeyboardKey key, String keyLabel) {
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.gameButtonA ||
        key == LogicalKeyboardKey.mediaPlayPause) {
      return 'playorpause';
    }
    for (final entry in _shortcuts.entries) {
      if (entry.value.contains(keyLabel)) {
        return entry.key;
      }
    }
    return null;
  }

  void _releaseAllLongPressShortcuts() {
    final actions = _activeLongPressKeys.values.toSet();
    _activeLongPressKeys.clear();
    for (final action in actions) {
      _invokeAction(action.onRelease);
    }
  }

  void _invokeAction(PlayerShortcutAction action) {
    unawaited(_runAction(action));
  }

  Future<void> _runAction(PlayerShortcutAction action) async {
    try {
      await action();
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'player keyboard shortcuts',
          context: ErrorDescription('while invoking a player shortcut'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
