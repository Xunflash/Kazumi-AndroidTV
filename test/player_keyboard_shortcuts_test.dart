import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/pages/player/player_keyboard_shortcuts.dart';

void main() {
  test('remote back keys leave directional controls', () {
    expect(
      isPlayerDirectionalControlsExitKey(LogicalKeyboardKey.goBack),
      isTrue,
    );
    expect(
      isPlayerDirectionalControlsExitKey(LogicalKeyboardKey.browserBack),
      isTrue,
    );
    expect(
      isPlayerDirectionalControlsExitKey(LogicalKeyboardKey.gameButtonB),
      isTrue,
    );
  });

  testWidgets('viewing layer keeps left and right playback shortcuts', (
    tester,
  ) async {
    final playerFocus = FocusNode();
    final controlsFocus = FocusNode();
    addTearDown(playerFocus.dispose);
    addTearDown(controlsFocus.dispose);
    var forwardCount = 0;
    var rewindCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(splashFactory: NoSplash.splashFactory),
        home: Focus(
          focusNode: playerFocus,
          autofocus: true,
          child: Column(
            children: [
              PlayerKeyboardShortcuts(
                focusScopeNode: playerFocus,
                actions: {
                  'forward': () => forwardCount++,
                  'rewind': () => rewindCount++,
                },
                shortcuts: const {},
                directionalControlsFocusNode: controlsFocus,
                directionalControlsEnabled: () => true,
              ),
              IconButton(
                focusNode: controlsFocus,
                onPressed: () {},
                icon: const Icon(Icons.play_arrow),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);

    expect(forwardCount, 1);
    expect(rewindCount, 1);
    expect(playerFocus.hasPrimaryFocus, isTrue);
  });

  testWidgets(
    'visible TV controls consume horizontal arrows and take focus',
    (tester) async {
      final playerFocus = FocusNode();
      final controlsFocus = FocusNode();
      addTearDown(playerFocus.dispose);
      addTearDown(controlsFocus.dispose);
      var forwardCount = 0;
      var rewindCount = 0;
      var enterCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Focus(
            focusNode: playerFocus,
            autofocus: true,
            child: Column(
              children: [
                PlayerKeyboardShortcuts(
                  focusScopeNode: playerFocus,
                  actions: {
                    'forward': () => forwardCount++,
                    'rewind': () => rewindCount++,
                  },
                  shortcuts: const {},
                  directionalControlsFocusNode: controlsFocus,
                  directionalControlsEnabled: () => true,
                  directionalControlsVisible: () => true,
                  onEnterDirectionalControls: () => enterCount++,
                ),
                IconButton(
                  focusNode: controlsFocus,
                  onPressed: () {},
                  icon: const Icon(Icons.play_arrow),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();

      expect(forwardCount, 0);
      expect(rewindCount, 0);
      expect(enterCount, 1);
      expect(controlsFocus.hasPrimaryFocus, isTrue);
    },
  );

  testWidgets('non-TV mode keeps custom shortcut mapping', (tester) async {
    final playerFocus = FocusNode();
    addTearDown(playerFocus.dispose);
    var forwardCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Focus(
          focusNode: playerFocus,
          autofocus: true,
          child: PlayerKeyboardShortcuts(
            focusScopeNode: playerFocus,
            actions: {'forward': () => forwardCount++},
            shortcuts: {
              'forward': [LogicalKeyboardKey.keyF.keyLabel],
            },
            directionalControlsEnabled: () => false,
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    expect(forwardCount, 0);

    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    expect(forwardCount, 1);
  });

  testWidgets('down enters controls and select activates focused button', (
    tester,
  ) async {
    final playerFocus = FocusNode();
    final controlsFocus = FocusNode();
    addTearDown(playerFocus.dispose);
    addTearDown(controlsFocus.dispose);
    var controlsVisible = false;
    var controlActivationCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(splashFactory: NoSplash.splashFactory),
        home: MediaQuery(
          data: const MediaQueryData(
            navigationMode: NavigationMode.directional,
          ),
          child: StatefulBuilder(
            builder: (context, setState) {
              return Focus(
                focusNode: playerFocus,
                autofocus: true,
                child: Column(
                  children: [
                    PlayerKeyboardShortcuts(
                      focusScopeNode: playerFocus,
                      actions: const {},
                      shortcuts: const {},
                      directionalControlsFocusNode: controlsFocus,
                      directionalControlsEnabled: () => true,
                      onEnterDirectionalControls: () {
                        setState(() => controlsVisible = true);
                      },
                    ),
                    if (controlsVisible)
                      IconButton(
                        focusNode: controlsFocus,
                        onPressed: () => controlActivationCount++,
                        icon: const Icon(Icons.play_arrow),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(controlsVisible, isTrue);
    expect(controlsFocus.hasPrimaryFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump();
    expect(controlActivationCount, 1);
  });

  testWidgets('up and remote back hide controls and restore viewing focus', (
    tester,
  ) async {
    final playerFocus = FocusNode();
    final controlsFocus = FocusNode();
    addTearDown(playerFocus.dispose);
    addTearDown(controlsFocus.dispose);
    var playerActivationCount = 0;
    var exitCount = 0;
    var controlsVisible = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(splashFactory: NoSplash.splashFactory),
        home: MediaQuery(
          data: const MediaQueryData(
            navigationMode: NavigationMode.directional,
          ),
          child: StatefulBuilder(
            builder: (context, setState) {
              return Focus(
                focusNode: playerFocus,
                autofocus: true,
                child: Column(
                  children: [
                    PlayerKeyboardShortcuts(
                      focusScopeNode: playerFocus,
                      actions: {
                        'playorpause': () => playerActivationCount++,
                      },
                      shortcuts: const {},
                      directionalControlsFocusNode: controlsFocus,
                      directionalControlsEnabled: () => true,
                      onEnterDirectionalControls: () {
                        setState(() => controlsVisible = true);
                      },
                      onExitDirectionalControls: () {
                        exitCount++;
                        setState(() => controlsVisible = false);
                      },
                    ),
                    if (controlsVisible)
                      IconButton(
                        focusNode: controlsFocus,
                        onPressed: () {},
                        icon: const Icon(Icons.play_arrow),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(controlsVisible, isTrue);
    expect(controlsFocus.hasPrimaryFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(controlsVisible, isFalse);
    expect(playerFocus.hasPrimaryFocus, isTrue);
    expect(exitCount, 1);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(controlsVisible, isTrue);
    expect(controlsFocus.hasPrimaryFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.gameButtonB);
    await tester.pump();
    expect(controlsVisible, isFalse);
    expect(playerFocus.hasPrimaryFocus, isTrue);
    expect(exitCount, 2);
    expect(playerActivationCount, 0);
  });

  testWidgets(
    'controls traverse across bottom groups and then reach top actions without seeking',
    (tester) async {
      final playerFocus = FocusNode(debugLabel: 'viewing layer');
      final playFocus = FocusNode(debugLabel: 'play');
      final danmakuFocus = FocusNode(debugLabel: 'danmaku');
      final superResolutionFocus = FocusNode(debugLabel: 'super resolution');
      final episodeFocus = FocusNode(debugLabel: 'episodes');
      final favoriteFocus = FocusNode(debugLabel: 'favorite');
      final backFocus = FocusNode(debugLabel: 'back');
      addTearDown(playerFocus.dispose);
      addTearDown(playFocus.dispose);
      addTearDown(danmakuFocus.dispose);
      addTearDown(superResolutionFocus.dispose);
      addTearDown(episodeFocus.dispose);
      addTearDown(favoriteFocus.dispose);
      addTearDown(backFocus.dispose);
      var forwardCount = 0;
      var rewindCount = 0;
      var episodeActivationCount = 0;
      var favoriteActivationCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              navigationMode: NavigationMode.directional,
            ),
            child: Focus(
              focusNode: playerFocus,
              autofocus: true,
              child: Stack(
                children: [
                  PlayerKeyboardShortcuts(
                    focusScopeNode: playerFocus,
                    actions: {
                      'forward': () => forwardCount++,
                      'rewind': () => rewindCount++,
                    },
                    shortcuts: const {},
                    directionalControlsFocusNode: playFocus,
                    directionalControlsEnabled: () => true,
                  ),
                  PlayerDirectionalControlsTraversal(
                    child: Column(
                      children: [
                        FocusTraversalOrder(
                          order: playerTopControlsFocusOrder,
                          child: Row(
                            children: [
                              FocusTraversalOrder(
                                order: playerTopLeadingControlsFocusOrder,
                                child: IconButton(
                                  focusNode: backFocus,
                                  onPressed: () {},
                                  icon: const Icon(Icons.arrow_back),
                                ),
                              ),
                              IconButton(
                                focusNode: favoriteFocus,
                                onPressed: () => favoriteActivationCount++,
                                icon: const Icon(Icons.favorite),
                              ),
                            ],
                          ),
                        ),
                        FocusTraversalOrder(
                          order: playerBottomControlsFocusOrder,
                          child: Row(
                            children: [
                              IconButton(
                                focusNode: playFocus,
                                onPressed: () {},
                                icon: const Icon(Icons.play_arrow),
                              ),
                              IconButton(
                                focusNode: danmakuFocus,
                                onPressed: () {},
                                icon: const Icon(Icons.closed_caption),
                              ),
                              const Spacer(),
                              TextButton(
                                focusNode: superResolutionFocus,
                                onPressed: () {},
                                child: const Text('Super resolution'),
                              ),
                              IconButton(
                                focusNode: episodeFocus,
                                onPressed: () => episodeActivationCount++,
                                icon: const Icon(Icons.list),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(playFocus.hasPrimaryFocus, isTrue);

      for (final expectedFocus in <FocusNode>[
        danmakuFocus,
        superResolutionFocus,
        episodeFocus,
        favoriteFocus,
      ]) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pump();
        expect(expectedFocus.hasPrimaryFocus, isTrue);
        if (expectedFocus == episodeFocus || expectedFocus == favoriteFocus) {
          await tester.sendKeyEvent(LogicalKeyboardKey.select);
          await tester.pump();
        }
      }

      expect(forwardCount, 0);
      expect(rewindCount, 0);
      expect(episodeActivationCount, 1);
      expect(favoriteActivationCount, 1);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(backFocus.hasPrimaryFocus, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(playFocus.hasPrimaryFocus, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      expect(backFocus.hasPrimaryFocus, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      expect(favoriteFocus.hasPrimaryFocus, isTrue);
      expect(forwardCount, 0);
      expect(rewindCount, 0);
    },
  );

  testWidgets('ordered player traversal is limited to directional mode', (
    tester,
  ) async {
    final backFocus = FocusNode(debugLabel: 'back');
    final favoriteFocus = FocusNode(debugLabel: 'favorite');
    final playFocus = FocusNode(debugLabel: 'play');
    final episodeFocus = FocusNode(debugLabel: 'episodes');
    addTearDown(backFocus.dispose);
    addTearDown(favoriteFocus.dispose);
    addTearDown(playFocus.dispose);
    addTearDown(episodeFocus.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            navigationMode: NavigationMode.traditional,
          ),
          child: PlayerDirectionalControlsTraversal(
            child: Column(
              children: [
                FocusTraversalOrder(
                  order: playerTopControlsFocusOrder,
                  child: Row(
                    children: [
                      FocusTraversalOrder(
                        order: playerTopLeadingControlsFocusOrder,
                        child: IconButton(
                          focusNode: backFocus,
                          onPressed: () {},
                          icon: const Icon(Icons.arrow_back),
                        ),
                      ),
                      IconButton(
                        focusNode: favoriteFocus,
                        onPressed: () {},
                        icon: const Icon(Icons.favorite),
                      ),
                    ],
                  ),
                ),
                FocusTraversalOrder(
                  order: playerBottomControlsFocusOrder,
                  child: Row(
                    children: [
                      IconButton(
                        focusNode: playFocus,
                        onPressed: () {},
                        icon: const Icon(Icons.play_arrow),
                      ),
                      IconButton(
                        focusNode: episodeFocus,
                        onPressed: () {},
                        icon: const Icon(Icons.list),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      FocusTraversalGroup.maybeOfNode(playFocus),
      isNot(isA<OrderedTraversalPolicy>()),
    );

    episodeFocus.requestFocus();
    await tester.pump();
    episodeFocus.nextFocus();
    await tester.pump();
    expect(backFocus.hasPrimaryFocus, isTrue);
  });

  testWidgets('up from a top control exits once and never invokes volume', (
    tester,
  ) async {
    final playerFocus = FocusNode(debugLabel: 'viewing layer');
    final favoriteFocus = FocusNode(debugLabel: 'favorite');
    addTearDown(playerFocus.dispose);
    addTearDown(favoriteFocus.dispose);
    var exitCount = 0;
    var volumeCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Focus(
          focusNode: playerFocus,
          autofocus: true,
          child: Column(
            children: [
              PlayerKeyboardShortcuts(
                focusScopeNode: playerFocus,
                actions: {'volumeup': () => volumeCount++},
                shortcuts: {
                  'volumeup': [LogicalKeyboardKey.arrowUp.keyLabel],
                },
                directionalControlsFocusNode: favoriteFocus,
                directionalControlsEnabled: () => true,
                onExitDirectionalControls: () => exitCount++,
              ),
              IconButton(
                focusNode: favoriteFocus,
                onPressed: () {},
                icon: const Icon(Icons.favorite),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    favoriteFocus.requestFocus();
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();

    expect(playerFocus.hasPrimaryFocus, isTrue);
    expect(exitCount, 1);
    expect(volumeCount, 0);
  });
}
