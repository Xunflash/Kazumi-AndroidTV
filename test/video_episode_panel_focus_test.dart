import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/pages/video/video_episode_panel_focus.dart';

void main() {
  test('episode panel prefers the current episode and falls back to first', () {
    expect(
      resolveVideoEpisodePanelFocusIndex(
        itemCount: 5,
        selectedEpisode: 3,
        selectedRoad: 1,
        visibleRoad: 1,
      ),
      2,
    );
    expect(
      resolveVideoEpisodePanelFocusIndex(
        itemCount: 5,
        selectedEpisode: 3,
        selectedRoad: 1,
        visibleRoad: 0,
      ),
      0,
    );
    expect(
      resolveVideoEpisodePanelFocusIndex(
        itemCount: 0,
        selectedEpisode: 1,
        selectedRoad: 0,
        visibleRoad: 0,
      ),
      -1,
    );
  });

  testWidgets(
    'opening the episode panel focuses current episode and supports select',
    (tester) async {
      final key = GlobalKey<_EpisodePanelHarnessState>();
      await tester.pumpWidget(_testApp(_EpisodePanelHarness(key: key)));
      await tester.pump();

      expect(key.currentState!.playerFocus.hasPrimaryFocus, isTrue);
      key.currentState!.open();
      await tester.pump();
      await tester.pump();

      expect(key.currentState!.episodeFocusNodes[1].hasPrimaryFocus, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(key.currentState!.episodeFocusNodes[2].hasPrimaryFocus, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pump();
      expect(key.currentState!.activatedEpisode, 3);
      expect(key.currentState!.panelVisible, isFalse);
      expect(key.currentState!.playerFocus.hasPrimaryFocus, isTrue);
    },
  );

  testWidgets('episode panel falls back to first item and Back closes it', (
    tester,
  ) async {
    final key = GlobalKey<_EpisodePanelHarnessState>();
    await tester.pumpWidget(
      _testApp(
        _EpisodePanelHarness(
          key: key,
          selectedRoad: 1,
          visibleRoad: 0,
        ),
      ),
    );
    await tester.pump();

    key.currentState!.open();
    await tester.pump();
    await tester.pump();
    expect(key.currentState!.episodeFocusNodes.first.hasPrimaryFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.gameButtonB);
    await tester.pump();
    expect(key.currentState!.panelVisible, isFalse);
    expect(key.currentState!.closeCount, 1);
    expect(key.currentState!.playerFocus.hasPrimaryFocus, isTrue);
  });

  testWidgets('episode panel accepts Back again after a rapid reopen frame', (
    tester,
  ) async {
    var closeCount = 0;
    await tester.pumpWidget(
      _testApp(
        VideoEpisodePanelFocusBoundary(
          onClose: () => closeCount++,
          child: TextButton(
            autofocus: true,
            onPressed: () {},
            child: const Text('Episode'),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.gameButtonB);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.gameButtonB);
    await tester.pump();

    expect(closeCount, 2);
  });

  test('episode panel recognizes Android TV Back variants', () {
    expect(isVideoEpisodePanelBackKey(LogicalKeyboardKey.goBack), isTrue);
    expect(isVideoEpisodePanelBackKey(LogicalKeyboardKey.browserBack), isTrue);
    expect(isVideoEpisodePanelBackKey(LogicalKeyboardKey.gameButtonB), isTrue);
    expect(isVideoEpisodePanelBackKey(LogicalKeyboardKey.escape), isTrue);
    expect(isVideoEpisodePanelBackKey(LogicalKeyboardKey.arrowLeft), isFalse);
  });

  testWidgets('paired system Back remains guarded until the next frame', (
    tester,
  ) async {
    await tester.pumpWidget(_testApp(const SizedBox.shrink()));
    await tester.pump();

    final guard = VideoEpisodePanelBackGuard();

    guard.armUntilNextFrame();
    expect(guard.shouldConsumeSystemBack, isTrue);

    // Re-arming in the same frame must not let the earlier callback clear the
    // newer remote event.
    guard.armUntilNextFrame();
    tester.binding.scheduleFrame();
    await tester.pump();

    expect(guard.shouldConsumeSystemBack, isFalse);
  });
}

Widget _testApp(Widget child) {
  return MaterialApp(
    theme: ThemeData(splashFactory: NoSplash.splashFactory),
    home: Router<Object>(
      routerDelegate: _TestRouterDelegate(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(1280, 720),
            navigationMode: NavigationMode.directional,
          ),
          child: Scaffold(body: child),
        ),
      ),
      backButtonDispatcher: RootBackButtonDispatcher(),
    ),
  );
}

class _TestRouterDelegate extends RouterDelegate<Object> with ChangeNotifier {
  _TestRouterDelegate(this.child);

  final Widget child;

  @override
  Widget build(BuildContext context) => child;

  @override
  Future<bool> popRoute() => SynchronousFuture<bool>(false);

  @override
  Future<void> setNewRoutePath(Object configuration) {
    return SynchronousFuture<void>(null);
  }
}

class _EpisodePanelHarness extends StatefulWidget {
  const _EpisodePanelHarness({
    super.key,
    this.selectedRoad = 0,
    this.visibleRoad = 0,
  });

  final int selectedRoad;
  final int visibleRoad;

  @override
  State<_EpisodePanelHarness> createState() => _EpisodePanelHarnessState();
}

class _EpisodePanelHarnessState extends State<_EpisodePanelHarness> {
  final FocusNode playerFocus = FocusNode(debugLabel: 'player');
  final List<FocusNode> episodeFocusNodes = List<FocusNode>.generate(
    3,
    (index) => FocusNode(debugLabel: 'episode ${index + 1}'),
  );
  bool panelVisible = false;
  int? activatedEpisode;
  int closeCount = 0;

  void open() {
    setState(() => panelVisible = true);
  }

  void close() {
    if (!panelVisible) {
      return;
    }
    closeCount++;
    setState(() => panelVisible = false);
    playerFocus.requestFocus();
  }

  @override
  void dispose() {
    playerFocus.dispose();
    for (final focusNode in episodeFocusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final preferredIndex = resolveVideoEpisodePanelFocusIndex(
      itemCount: episodeFocusNodes.length,
      selectedEpisode: 2,
      selectedRoad: widget.selectedRoad,
      visibleRoad: widget.visibleRoad,
    );
    return Stack(
      children: [
        Focus(
          focusNode: playerFocus,
          autofocus: true,
          child: const SizedBox.expand(),
        ),
        if (panelVisible)
          Align(
            alignment: Alignment.centerRight,
            child: VideoEpisodePanelFocusBoundary(
              onClose: close,
              child: Material(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List<Widget>.generate(
                    episodeFocusNodes.length,
                    (index) => TextButton(
                      focusNode: episodeFocusNodes[index],
                      autofocus: index == preferredIndex,
                      onPressed: () {
                        activatedEpisode = index + 1;
                        close();
                      },
                      child: Text('Episode ${index + 1}'),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
