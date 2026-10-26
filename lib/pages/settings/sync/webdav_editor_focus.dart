import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class WebDavEditorFocusBoundary extends StatefulWidget {
  const WebDavEditorFocusBoundary({
    super.key,
    required this.textInputFocusNodes,
    required this.directionalFallbackFocusNode,
    required this.child,
    this.canPop = true,
  });

  final List<FocusNode> textInputFocusNodes;
  final FocusNode directionalFallbackFocusNode;
  final Widget child;

  /// Extra route guard, such as blocking back while a connection test runs.
  final bool canPop;

  @override
  State<WebDavEditorFocusBoundary> createState() =>
      _WebDavEditorFocusBoundaryState();
}

class _WebDavEditorFocusBoundaryState extends State<WebDavEditorFocusBoundary> {
  bool _textInputHasFocus = false;

  @override
  void initState() {
    super.initState();
    _attachFocusListeners(widget.textInputFocusNodes);
    _syncTextInputFocus();
  }

  @override
  void didUpdateWidget(WebDavEditorFocusBoundary oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(
      oldWidget.textInputFocusNodes,
      widget.textInputFocusNodes,
    )) {
      _detachFocusListeners(oldWidget.textInputFocusNodes);
      _attachFocusListeners(widget.textInputFocusNodes);
      _syncTextInputFocus();
    }
  }

  @override
  void dispose() {
    _detachFocusListeners(widget.textInputFocusNodes);
    super.dispose();
  }

  void _attachFocusListeners(List<FocusNode> nodes) {
    for (final node in nodes) {
      node.addListener(_syncTextInputFocus);
    }
  }

  void _detachFocusListeners(List<FocusNode> nodes) {
    for (final node in nodes) {
      node.removeListener(_syncTextInputFocus);
    }
  }

  void _syncTextInputFocus() {
    final hasFocus = widget.textInputFocusNodes.any((node) => node.hasFocus);
    if (_textInputHasFocus == hasFocus) {
      return;
    }
    if (!mounted) {
      _textInputHasFocus = hasFocus;
      return;
    }
    setState(() {
      _textInputHasFocus = hasFocus;
    });
  }

  void _finishEditing() {
    if (MediaQuery.navigationModeOf(context) == NavigationMode.directional &&
        widget.directionalFallbackFocusNode.canRequestFocus) {
      widget.directionalFallbackFocusNode.requestFocus();
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
  }

  bool _isEditing(BuildContext context) {
    return _textInputHasFocus || MediaQuery.viewInsetsOf(context).bottom > 0;
  }

  KeyEventResult _handleKeyEvent(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent ||
        !isWebDavEditorBackKey(event.logicalKey) ||
        !_isEditing(context)) {
      return KeyEventResult.ignored;
    }
    _finishEditing();
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = _isEditing(context);
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: _handleKeyEvent,
      child: PopScope(
        canPop: widget.canPop && !isEditing,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && isEditing) {
            _finishEditing();
          }
        },
        child: widget.child,
      ),
    );
  }
}

bool isWebDavEditorBackKey(LogicalKeyboardKey key) {
  return key == LogicalKeyboardKey.goBack ||
      key == LogicalKeyboardKey.browserBack ||
      key == LogicalKeyboardKey.gameButtonB ||
      key == LogicalKeyboardKey.escape;
}

class WebDavEditorSaveButton extends StatelessWidget {
  const WebDavEditorSaveButton({
    super.key,
    required this.focusNode,
    required this.firstEditingFocusNode,
    required this.lastEditingFocusNode,
    required this.onPressed,
    this.label = '保存并测试',
    this.icon = Icons.save_rounded,
    this.tooltip = '保存并测试',
  });

  final FocusNode focusNode;
  final FocusNode firstEditingFocusNode;
  final FocusNode lastEditingFocusNode;
  final VoidCallback? onPressed;
  final String label;
  final IconData icon;
  final String tooltip;

  KeyEventResult _handleKeyEvent(FocusNode _, KeyEvent event) {
    if (event is KeyDownEvent) {
      final target = switch (event.logicalKey) {
        LogicalKeyboardKey.arrowUp => lastEditingFocusNode,
        LogicalKeyboardKey.arrowLeft => firstEditingFocusNode,
        _ => null,
      };
      if (target?.canRequestFocus ?? false) {
        target!.requestFocus();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: _handleKeyEvent,
      child: FloatingActionButton.extended(
        focusNode: focusNode,
        autofocus:
            MediaQuery.navigationModeOf(context) == NavigationMode.directional,
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
      ),
    );
  }
}
