import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:kazumi/services/sync/webdav.dart';

class WebDavEditorPage extends StatefulWidget {
  const WebDavEditorPage({
    super.key,
  });

  @override
  State<WebDavEditorPage> createState() => _WebDavEditorPageState();
}

class _WebDavEditorPageState extends State<WebDavEditorPage> {
  final TextEditingController webDavURLController = TextEditingController();
  final TextEditingController webDavUsernameController =
      TextEditingController();
  final TextEditingController webDavPasswordController =
      TextEditingController();
  final FocusNode _urlFocusNode = FocusNode(debugLabel: 'webdav url');
  final FocusNode _usernameFocusNode = FocusNode(
    debugLabel: 'webdav username',
  );
  final FocusNode _passwordFocusNode = FocusNode(
    debugLabel: 'webdav password',
  );
  final FocusNode _saveFocusNode = FocusNode(debugLabel: 'webdav save');
  late final List<FocusNode> _textInputFocusNodes;
  bool passwordVisible = false;

  @override
  void initState() {
    super.initState();
    _textInputFocusNodes = [
      _urlFocusNode,
      _usernameFocusNode,
      _passwordFocusNode,
    ];
    webDavURLController.text = GStorage.getSetting(SettingsKeys.webDavURL);
    webDavUsernameController.text =
        GStorage.getSetting(SettingsKeys.webDavUsername);
    webDavPasswordController.text =
        GStorage.getSetting(SettingsKeys.webDavPassword);
  }

  @override
  void dispose() {
    webDavURLController.dispose();
    webDavUsernameController.dispose();
    webDavPasswordController.dispose();
    _urlFocusNode.dispose();
    _usernameFocusNode.dispose();
    _passwordFocusNode.dispose();
    _saveFocusNode.dispose();
    super.dispose();
  }

  void _focusSave() {
    _saveFocusNode.requestFocus();
  }

  Future<void> _saveConfiguration() async {
    _focusSave();
    await GStorage.putSetting(
      SettingsKeys.webDavURL,
      webDavURLController.text,
    );
    await GStorage.putSetting(
      SettingsKeys.webDavUsername,
      webDavUsernameController.text,
    );
    await GStorage.putSetting(
      SettingsKeys.webDavPassword,
      webDavPasswordController.text,
    );
    final webDav = WebDav();
    try {
      await webDav.init();
    } catch (e) {
      KazumiDialog.showToast(message: '配置失败 ${e.toString()}');
      await GStorage.putSetting(SettingsKeys.webDavEnable, false);
      return;
    }
    KazumiDialog.showToast(message: '配置成功, 开始测试');
    try {
      await webDav.ping();
      KazumiDialog.showToast(message: '测试成功');
    } catch (e) {
      KazumiDialog.showToast(message: '测试失败 ${e.toString()}');
      await GStorage.putSetting(SettingsKeys.webDavEnable, false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return WebDavEditorFocusBoundary(
      textInputFocusNodes: _textInputFocusNodes,
      directionalFallbackFocusNode: _saveFocusNode,
      child: Scaffold(
        appBar: const SysAppBar(
          title: Text('WEBDAV编辑'),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Center(
            child: SizedBox(
              width: (MediaQuery.of(context).size.width > 1000) ? 1000 : null,
              child: Column(
                children: [
                  TextField(
                    controller: webDavURLController,
                    focusNode: _urlFocusNode,
                    keyboardType: TextInputType.url,
                    textInputAction: TextInputAction.next,
                    onSubmitted: (_) => _usernameFocusNode.requestFocus(),
                    decoration: const InputDecoration(
                      labelText: 'URL',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: webDavUsernameController,
                    focusNode: _usernameFocusNode,
                    textInputAction: TextInputAction.next,
                    onSubmitted: (_) => _passwordFocusNode.requestFocus(),
                    decoration: const InputDecoration(
                      labelText: 'Username',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: webDavPasswordController,
                    focusNode: _passwordFocusNode,
                    obscureText: !passwordVisible,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _focusSave(),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        tooltip: passwordVisible ? '隐藏密码' : '显示密码',
                        onPressed: () {
                          setState(() {
                            passwordVisible = !passwordVisible;
                          });
                        },
                        icon: Icon(passwordVisible
                            ? Icons.visibility_rounded
                            : Icons.visibility_off_rounded),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        floatingActionButton: WebDavEditorSaveButton(
          focusNode: _saveFocusNode,
          firstEditingFocusNode: _urlFocusNode,
          lastEditingFocusNode: _passwordFocusNode,
          onPressed: _saveConfiguration,
        ),
      ),
    );
  }
}

class WebDavEditorFocusBoundary extends StatefulWidget {
  const WebDavEditorFocusBoundary({
    super.key,
    required this.textInputFocusNodes,
    required this.directionalFallbackFocusNode,
    required this.child,
  });

  final List<FocusNode> textInputFocusNodes;
  final FocusNode directionalFallbackFocusNode;
  final Widget child;

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
        canPop: !isEditing,
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
  });

  final FocusNode focusNode;
  final FocusNode firstEditingFocusNode;
  final FocusNode lastEditingFocusNode;
  final VoidCallback onPressed;

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
        tooltip: '保存并测试',
        onPressed: onPressed,
        icon: const Icon(Icons.save_rounded),
        label: const Text('保存并测试'),
      ),
    );
  }
}
