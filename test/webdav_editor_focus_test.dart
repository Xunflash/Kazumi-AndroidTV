import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/pages/webdav_editor/webdav_editor_page.dart';

void main() {
  test('recognizes Android TV back key variants', () {
    expect(isWebDavEditorBackKey(LogicalKeyboardKey.goBack), isTrue);
    expect(isWebDavEditorBackKey(LogicalKeyboardKey.browserBack), isTrue);
    expect(isWebDavEditorBackKey(LogicalKeyboardKey.gameButtonB), isTrue);
    expect(isWebDavEditorBackKey(LogicalKeyboardKey.escape), isTrue);
    expect(isWebDavEditorBackKey(LogicalKeyboardKey.arrowLeft), isFalse);
  });

  testWidgets('first back ends TV editing and second back leaves the page', (
    tester,
  ) async {
    final inputFocus = FocusNode();
    final saveFocus = FocusNode();
    addTearDown(inputFocus.dispose);
    addTearDown(saveFocus.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(splashFactory: NoSplash.splashFactory),
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(1280, 720),
            navigationMode: NavigationMode.directional,
          ),
          child: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () {
                  Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (context) => MediaQuery(
                        data: const MediaQueryData(
                          size: Size(1280, 720),
                          navigationMode: NavigationMode.directional,
                        ),
                        child: WebDavEditorFocusBoundary(
                          textInputFocusNodes: [inputFocus],
                          directionalFallbackFocusNode: saveFocus,
                          child: Scaffold(
                            appBar: AppBar(title: const Text('WEBDAV编辑')),
                            body: TextField(focusNode: inputFocus),
                            floatingActionButton: WebDavEditorSaveButton(
                              focusNode: saveFocus,
                              firstEditingFocusNode: inputFocus,
                              lastEditingFocusNode: inputFocus,
                              onPressed: () {},
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
                child: const Text('打开编辑器'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开编辑器'));
    await tester.pumpAndSettle();

    for (final keyPair in _remoteBackKeys) {
      inputFocus.requestFocus();
      await tester.pump();
      expect(inputFocus.hasPrimaryFocus, isTrue);

      expect(_sendRemoteKey(tester, keyPair), isTrue);
      await tester.pump();

      expect(find.text('WEBDAV编辑'), findsOneWidget);
      expect(inputFocus.hasFocus, isFalse);
      expect(saveFocus.hasPrimaryFocus, isTrue);
    }

    inputFocus.requestFocus();
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pump();

    expect(find.text('WEBDAV编辑'), findsOneWidget);
    expect(inputFocus.hasFocus, isFalse);
    expect(saveFocus.hasPrimaryFocus, isTrue);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('WEBDAV编辑'), findsNothing);
    expect(find.text('打开编辑器'), findsOneWidget);
  });

  testWidgets('TV save action is initially reachable and activates on select', (
    tester,
  ) async {
    final firstInputController = TextEditingController();
    final lastInputController = TextEditingController();
    final firstInputFocus = FocusNode();
    final lastInputFocus = FocusNode();
    final saveFocus = FocusNode();
    addTearDown(firstInputController.dispose);
    addTearDown(lastInputController.dispose);
    addTearDown(firstInputFocus.dispose);
    addTearDown(lastInputFocus.dispose);
    addTearDown(saveFocus.dispose);
    var saveCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(splashFactory: NoSplash.splashFactory),
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(1280, 720),
            navigationMode: NavigationMode.directional,
          ),
          child: Scaffold(
            body: Column(
              children: [
                TextField(
                  controller: firstInputController,
                  focusNode: firstInputFocus,
                ),
                TextField(
                  controller: lastInputController,
                  focusNode: lastInputFocus,
                ),
              ],
            ),
            floatingActionButton: WebDavEditorSaveButton(
              focusNode: saveFocus,
              firstEditingFocusNode: firstInputFocus,
              lastEditingFocusNode: lastInputFocus,
              onPressed: () => saveCount++,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(saveFocus.hasPrimaryFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    expect(saveCount, 1);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(lastInputFocus.hasPrimaryFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.enterText(find.byType(TextField).last, 'secret');
    expect(lastInputController.text, 'secret');

    saveFocus.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(firstInputFocus.hasPrimaryFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.enterText(find.byType(TextField).first, 'dav.example');
    expect(firstInputController.text, 'dav.example');
  });

  testWidgets('traditional navigation does not autofocus save', (
    tester,
  ) async {
    final inputFocus = FocusNode();
    final saveFocus = FocusNode();
    addTearDown(inputFocus.dispose);
    addTearDown(saveFocus.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(splashFactory: NoSplash.splashFactory),
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(1280, 720),
            navigationMode: NavigationMode.traditional,
          ),
          child: Scaffold(
            body: TextField(
              focusNode: inputFocus,
              autofocus: true,
            ),
            floatingActionButton: WebDavEditorSaveButton(
              focusNode: saveFocus,
              firstEditingFocusNode: inputFocus,
              lastEditingFocusNode: inputFocus,
              onPressed: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(inputFocus.hasPrimaryFocus, isTrue);
    expect(saveFocus.hasFocus, isFalse);
  });
}

const _remoteBackKeys =
    <({LogicalKeyboardKey logical, PhysicalKeyboardKey physical})>[
  (
    logical: LogicalKeyboardKey.goBack,
    physical: PhysicalKeyboardKey.escape,
  ),
  (
    logical: LogicalKeyboardKey.browserBack,
    physical: PhysicalKeyboardKey.escape,
  ),
  (
    logical: LogicalKeyboardKey.gameButtonB,
    physical: PhysicalKeyboardKey.escape,
  ),
  (
    logical: LogicalKeyboardKey.escape,
    physical: PhysicalKeyboardKey.escape,
  ),
];

bool _sendRemoteKey(
  WidgetTester tester,
  ({LogicalKeyboardKey logical, PhysicalKeyboardKey physical}) keyPair,
) {
  // Flutter's FocusManager still receives unsupported remote keys through
  // this compatibility handler; sendKeyEvent cannot synthesize goBack.
  // ignore: deprecated_member_use
  return tester.binding.keyEventManager.keyMessageHandler!(
    // ignore: deprecated_member_use
    KeyMessage(
      <KeyEvent>[
        KeyDownEvent(
          physicalKey: keyPair.physical,
          logicalKey: keyPair.logical,
          timeStamp: Duration.zero,
        ),
      ],
      null,
    ),
  );
}
