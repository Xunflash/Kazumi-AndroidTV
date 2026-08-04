import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Makes a Scaffold FAB reachable from directional content focus scopes.
class DirectionalFloatingActionFocus extends StatelessWidget {
  const DirectionalFloatingActionFocus({
    super.key,
    required this.floatingActionFocusNode,
    required this.child,
  });

  final FocusNode floatingActionFocusNode;
  final Widget child;

  KeyEventResult _handleKeyEvent(BuildContext context, KeyEvent event) {
    if (MediaQuery.navigationModeOf(context) != NavigationMode.directional ||
        event is KeyUpEvent) {
      return KeyEventResult.ignored;
    }

    final direction = switch (event.logicalKey) {
      LogicalKeyboardKey.arrowDown => TraversalDirection.down,
      LogicalKeyboardKey.arrowRight => TraversalDirection.right,
      _ => null,
    };
    if (direction == null) {
      return KeyEventResult.ignored;
    }

    final primaryFocus = FocusManager.instance.primaryFocus;
    if (primaryFocus == null ||
        primaryFocus == floatingActionFocusNode ||
        !floatingActionFocusNode.canRequestFocus ||
        floatingActionFocusNode.context == null) {
      return KeyEventResult.ignored;
    }

    final focusContext = primaryFocus.context;
    final focusIsEditingText = focusContext != null &&
        (focusContext.widget is EditableText ||
            focusContext.findAncestorWidgetOfExactType<EditableText>() != null);
    if (direction == TraversalDirection.right && focusIsEditingText) {
      return KeyEventResult.ignored;
    }

    if (primaryFocus.focusInDirection(direction)) {
      return KeyEventResult.handled;
    }

    floatingActionFocusNode.requestFocus();
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      canRequestFocus: false,
      onKeyEvent: (_, event) => _handleKeyEvent(context, event),
      child: child,
    );
  }
}
