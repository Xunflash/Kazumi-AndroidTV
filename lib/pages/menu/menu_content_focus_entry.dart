import 'package:flutter/widgets.dart';

/// Marks the preferred focus target when entering a routed page from the menu.
///
/// The marker can stay mounted while an asynchronously loaded target is not
/// yet attached. The menu boundary will keep the navigation focus and retry on
/// the next frame instead of falling back to unrelated page chrome.
class MenuContentFocusEntryNode extends FocusNode {
  MenuContentFocusEntryNode({
    required this.targetFocusNode,
    super.debugLabel,
  });

  final FocusNode targetFocusNode;

  bool requestTargetFocus() {
    if (!targetFocusNode.canRequestFocus || targetFocusNode.context == null) {
      return false;
    }
    targetFocusNode.requestFocus();
    return true;
  }
}
