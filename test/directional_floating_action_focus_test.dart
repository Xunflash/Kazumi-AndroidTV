import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/bean/widget/directional_floating_action_focus.dart';

void main() {
  testWidgets('down reaches the FAB after normal content traversal ends', (
    tester,
  ) async {
    final firstFocus = FocusNode();
    final lastFocus = FocusNode();
    final fabFocus = FocusNode();
    addTearDown(firstFocus.dispose);
    addTearDown(lastFocus.dispose);
    addTearDown(fabFocus.dispose);

    await tester.pumpWidget(
      _testApp(
        fabFocus: fabFocus,
        content: FocusScope(
          child: Column(
            children: [
              TextButton(
                focusNode: firstFocus,
                onPressed: () {},
                child: const Text('第一行'),
              ),
              const Spacer(),
              TextButton(
                focusNode: lastFocus,
                onPressed: () {},
                child: const Text('最后一行'),
              ),
            ],
          ),
        ),
      ),
    );

    firstFocus.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(lastFocus.hasPrimaryFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(fabFocus.hasPrimaryFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(lastFocus.hasPrimaryFocus, isTrue);
  });

  testWidgets('right reaches and activates the FAB at a content scope edge', (
    tester,
  ) async {
    final contentFocus = FocusNode();
    final fabFocus = FocusNode();
    addTearDown(contentFocus.dispose);
    addTearDown(fabFocus.dispose);
    var activationCount = 0;

    await tester.pumpWidget(
      _testApp(
        fabFocus: fabFocus,
        onFabPressed: () => activationCount++,
        content: FocusScope(
          child: Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              focusNode: contentFocus,
              onPressed: () {},
              child: const Text('最右内容'),
            ),
          ),
        ),
      ),
    );

    contentFocus.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(fabFocus.hasPrimaryFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    expect(activationCount, 1);
  });

  testWidgets('traditional navigation keeps the existing arrow behavior', (
    tester,
  ) async {
    final contentFocus = FocusNode();
    final fabFocus = FocusNode();
    addTearDown(contentFocus.dispose);
    addTearDown(fabFocus.dispose);

    await tester.pumpWidget(
      _testApp(
        navigationMode: NavigationMode.traditional,
        fabFocus: fabFocus,
        content: FocusScope(
          child: TextButton(
            focusNode: contentFocus,
            onPressed: () {},
            child: const Text('正文'),
          ),
        ),
      ),
    );

    contentFocus.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();

    expect(contentFocus.hasPrimaryFocus, isTrue);
    expect(fabFocus.hasFocus, isFalse);
  });

  testWidgets('left at the content edge is left for the menu boundary', (
    tester,
  ) async {
    final navigationFocus = FocusNode();
    final contentFocus = FocusNode();
    final fabFocus = FocusNode();
    addTearDown(navigationFocus.dispose);
    addTearDown(contentFocus.dispose);
    addTearDown(fabFocus.dispose);
    var outerLeftCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(splashFactory: NoSplash.splashFactory),
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(1280, 720),
            navigationMode: NavigationMode.directional,
          ),
          child: Row(
            children: [
              Focus(
                focusNode: navigationFocus,
                child: const SizedBox(width: 80),
              ),
              Expanded(
                child: Actions(
                  actions: <Type, Action<Intent>>{
                    DirectionalFocusIntent:
                        CallbackAction<DirectionalFocusIntent>(
                      onInvoke: (intent) {
                        if (intent.direction == TraversalDirection.left) {
                          outerLeftCount++;
                          navigationFocus.requestFocus();
                        }
                        return null;
                      },
                    ),
                  },
                  child: DirectionalFloatingActionFocus(
                    floatingActionFocusNode: fabFocus,
                    child: Scaffold(
                      body: Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          focusNode: contentFocus,
                          onPressed: () {},
                          child: const Text('最左内容'),
                        ),
                      ),
                      floatingActionButton: FloatingActionButton(
                        focusNode: fabFocus,
                        onPressed: () {},
                        child: const Icon(Icons.tune),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    contentFocus.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();

    expect(outerLeftCount, 1);
    expect(navigationFocus.hasPrimaryFocus, isTrue);
  });

  testWidgets('right stays available for an active text editor',
      (tester) async {
    final editingFocus = FocusNode();
    final fabFocus = FocusNode();
    final controller = TextEditingController(text: 'AB');
    addTearDown(editingFocus.dispose);
    addTearDown(fabFocus.dispose);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _testApp(
        fabFocus: fabFocus,
        content: TextField(
          controller: controller,
          focusNode: editingFocus,
        ),
      ),
    );

    editingFocus.requestFocus();
    controller.selection = const TextSelection.collapsed(offset: 0);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();

    expect(controller.selection.baseOffset, 1);
    expect(editingFocus.hasPrimaryFocus, isTrue);
    expect(fabFocus.hasFocus, isFalse);
  });

  testWidgets('a multi-FAB row enters the first button then traverses right', (
    tester,
  ) async {
    final contentFocus = FocusNode();
    final firstFabFocus = FocusNode();
    final secondFabFocus = FocusNode();
    addTearDown(contentFocus.dispose);
    addTearDown(firstFabFocus.dispose);
    addTearDown(secondFabFocus.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(splashFactory: NoSplash.splashFactory),
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(1280, 720),
            navigationMode: NavigationMode.directional,
          ),
          child: DirectionalFloatingActionFocus(
            floatingActionFocusNode: firstFabFocus,
            child: Scaffold(
              body: FocusScope(
                child: TextButton(
                  focusNode: contentFocus,
                  onPressed: () {},
                  child: const Text('日志内容'),
                ),
              ),
              floatingActionButton: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  FloatingActionButton(
                    heroTag: null,
                    focusNode: firstFabFocus,
                    onPressed: () {},
                    child: const Icon(Icons.clear_all),
                  ),
                  const SizedBox(width: 15),
                  FloatingActionButton(
                    heroTag: null,
                    focusNode: secondFabFocus,
                    onPressed: () {},
                    child: const Icon(Icons.copy),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    contentFocus.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(firstFabFocus.hasPrimaryFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(secondFabFocus.hasPrimaryFocus, isTrue);
  });

  testWidgets('episode panel reaches and activates its download FAB', (
    tester,
  ) async {
    final episodeFocus = FocusNode(debugLabel: 'last episode');
    final downloadFocus = FocusNode(debugLabel: 'episode download');
    addTearDown(episodeFocus.dispose);
    addTearDown(downloadFocus.dispose);
    var downloadCount = 0;

    await tester.pumpWidget(
      _testApp(
        fabFocus: downloadFocus,
        onFabPressed: () => downloadCount++,
        content: FocusScope(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: TextButton(
              focusNode: episodeFocus,
              onPressed: () {},
              child: const Text('最后一集'),
            ),
          ),
        ),
      ),
    );

    episodeFocus.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(downloadFocus.hasPrimaryFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    expect(downloadCount, 1);
  });
}

Widget _testApp({
  required FocusNode fabFocus,
  required Widget content,
  VoidCallback? onFabPressed,
  NavigationMode navigationMode = NavigationMode.directional,
}) {
  return MaterialApp(
    theme: ThemeData(splashFactory: NoSplash.splashFactory),
    home: MediaQuery(
      data: MediaQueryData(
        size: const Size(1280, 720),
        navigationMode: navigationMode,
      ),
      child: DirectionalFloatingActionFocus(
        floatingActionFocusNode: fabFocus,
        child: Scaffold(
          body: content,
          floatingActionButton: FloatingActionButton(
            focusNode: fabFocus,
            onPressed: onFabPressed ?? () {},
            child: const Icon(Icons.tune),
          ),
        ),
      ),
    ),
  );
}
