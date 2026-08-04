import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/pages/menu/menu.dart';
import 'package:kazumi/pages/menu/menu_content_focus_entry.dart';

void main() {
  testWidgets('left enters the rail and restores its last destination', (
    tester,
  ) async {
    final searchFocus = FocusNode();
    final contentFocus = FocusNode();
    addTearDown(searchFocus.dispose);
    addTearDown(contentFocus.dispose);
    var selectedDestination = -1;

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(splashFactory: NoSplash.splashFactory),
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(1280, 720),
            navigationMode: NavigationMode.directional,
          ),
          child: Scaffold(
            body: MenuDirectionalFocusBoundary(
              navigationEntryFocusNode: searchFocus,
              navigationRail: NavigationRail(
                leading: FloatingActionButton(
                  focusNode: searchFocus,
                  onPressed: () {},
                  child: const Icon(Icons.search),
                ),
                selectedIndex: 0,
                destinations: const [
                  NavigationRailDestination(
                    icon: Icon(Icons.home_outlined),
                    label: Text('推荐'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.timeline_outlined),
                    label: Text('时间表'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.favorite_border),
                    label: Text('追番'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.settings_outlined),
                    label: Text('我的'),
                  ),
                ],
                onDestinationSelected: (index) {
                  selectedDestination = index;
                },
              ),
              content: FocusScope(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    focusNode: contentFocus,
                    onPressed: () {},
                    child: const Text('内容'),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    contentFocus.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(searchFocus.hasPrimaryFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(selectedDestination, 0);

    for (var i = 0; i < 3; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(selectedDestination, 3);

    contentFocus.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(selectedDestination, 3);
  });

  testWidgets('left traverses content buttons before entering the rail', (
    tester,
  ) async {
    final navigationFocus = FocusNode();
    final leftContentFocus = FocusNode();
    final rightContentFocus = FocusNode();
    addTearDown(navigationFocus.dispose);
    addTearDown(leftContentFocus.dispose);
    addTearDown(rightContentFocus.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(splashFactory: NoSplash.splashFactory),
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(1280, 720),
            navigationMode: NavigationMode.directional,
          ),
          child: MenuDirectionalFocusBoundary(
            navigationEntryFocusNode: navigationFocus,
            navigationRail: Focus(
              focusNode: navigationFocus,
              child: const SizedBox(width: 80),
            ),
            content: FocusScope(
              child: Align(
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                      focusNode: leftContentFocus,
                      onPressed: () {},
                      child: const Text('左侧按钮'),
                    ),
                    TextButton(
                      focusNode: rightContentFocus,
                      onPressed: () {},
                      child: const Text('右侧按钮'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    rightContentFocus.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();

    expect(leftContentFocus.hasPrimaryFocus, isTrue);
    expect(navigationFocus.hasFocus, isFalse);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();

    expect(navigationFocus.hasPrimaryFocus, isTrue);
  });

  testWidgets('right enters content from the search button', (tester) async {
    final searchFocus = FocusNode();
    final contentFocus = FocusNode();
    addTearDown(searchFocus.dispose);
    addTearDown(contentFocus.dispose);

    await tester.pumpWidget(
      _navigationRailFocusTestApp(
        navigationFocus: searchFocus,
        content: TextButton(
          focusNode: contentFocus,
          onPressed: () {},
          child: const Text('当前页面内容'),
        ),
      ),
    );

    searchFocus.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();

    expect(contentFocus.hasPrimaryFocus, isTrue);
  });

  testWidgets(
    'right waits for the preferred card instead of entering persistent chrome',
    (tester) async {
      final searchFocus = FocusNode(debugLabel: 'search');
      final headerFocus = FocusNode(debugLabel: 'popular header');
      final firstCardFocus = FocusNode(debugLabel: 'first popular card');
      final contentEntryFocus = MenuContentFocusEntryNode(
        targetFocusNode: firstCardFocus,
        debugLabel: 'popular content entry',
      );
      addTearDown(searchFocus.dispose);
      addTearDown(headerFocus.dispose);
      addTearDown(firstCardFocus.dispose);
      addTearDown(contentEntryFocus.dispose);
      late StateSetter showFirstCard;
      var cardLoaded = false;

      await tester.pumpWidget(
        _navigationRailFocusTestApp(
          navigationFocus: searchFocus,
          content: StatefulBuilder(
            builder: (context, setState) {
              showFirstCard = setState;
              return Column(
                children: [
                  Focus(
                    focusNode: contentEntryFocus,
                    canRequestFocus: false,
                    skipTraversal: true,
                    child: const SizedBox.shrink(),
                  ),
                  TextButton(
                    focusNode: headerFocus,
                    onPressed: () {},
                    child: const Text('热门番组筛选'),
                  ),
                  if (cardLoaded)
                    TextButton(
                      focusNode: firstCardFocus,
                      onPressed: () {},
                      child: const Text('第一张番剧卡'),
                    ),
                ],
              );
            },
          ),
        ),
      );

      searchFocus.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();

      expect(searchFocus.hasPrimaryFocus, isTrue);
      expect(headerFocus.hasFocus, isFalse);

      showFirstCard(() => cardLoaded = true);
      await tester.pump();
      await tester.pump();

      expect(firstCardFocus.hasPrimaryFocus, isTrue);
      expect(headerFocus.hasFocus, isFalse);
    },
  );

  testWidgets('failed preferred content falls back to reachable page chrome', (
    tester,
  ) async {
    final searchFocus = FocusNode(debugLabel: 'search');
    final retryFocus = FocusNode(debugLabel: 'retry');
    final unavailableCardFocus = FocusNode(debugLabel: 'unavailable card');
    final contentEntryFocus = MenuContentFocusEntryNode(
      targetFocusNode: unavailableCardFocus,
      debugLabel: 'popular content entry',
    );
    addTearDown(searchFocus.dispose);
    addTearDown(retryFocus.dispose);
    addTearDown(unavailableCardFocus.dispose);
    addTearDown(contentEntryFocus.dispose);
    late StateSetter finishWithError;
    var loading = true;

    await tester.pumpWidget(
      _navigationRailFocusTestApp(
        navigationFocus: searchFocus,
        content: StatefulBuilder(
          builder: (context, setState) {
            finishWithError = setState;
            return Column(
              children: [
                if (loading)
                  Focus(
                    focusNode: contentEntryFocus,
                    canRequestFocus: false,
                    skipTraversal: true,
                    child: const SizedBox.shrink(),
                  ),
                TextButton(
                  focusNode: retryFocus,
                  onPressed: () {},
                  child: const Text('重试'),
                ),
              ],
            );
          },
        ),
      ),
    );

    searchFocus.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(searchFocus.hasPrimaryFocus, isTrue);

    finishWithError(() => loading = false);
    await tester.pump();
    await tester.pump();

    expect(retryFocus.hasPrimaryFocus, isTrue);
  });

  testWidgets(
      'one right enters nested route content when the first page finishes loading',
      (
    tester,
  ) async {
    final navigationFocus = FocusNode();
    final contentFocus = FocusNode();
    final pageKey = GlobalKey<_DeferredFocusablePageState>();
    addTearDown(navigationFocus.dispose);
    addTearDown(contentFocus.dispose);

    await tester.pumpWidget(
      _focusTestApp(
        navigationFocus: navigationFocus,
        content: Navigator(
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            builder: (_) => _DeferredFocusablePage(
              key: pageKey,
              contentFocus: contentFocus,
            ),
          ),
        ),
      ),
    );

    navigationFocus.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(navigationFocus.hasPrimaryFocus, isTrue);

    pageKey.currentState!.showContent();
    await tester.pump();
    await tester.pump();

    expect(contentFocus.hasPrimaryFocus, isTrue);
  });

  testWidgets('right targets the mounted page and restores it after switching',
      (
    tester,
  ) async {
    final navigationFocus = FocusNode();
    final firstPageFocus = FocusNode();
    final secondPageFocus = FocusNode();
    final pageKey = GlobalKey<_SwitchingFocusablePageState>();
    addTearDown(navigationFocus.dispose);
    addTearDown(firstPageFocus.dispose);
    addTearDown(secondPageFocus.dispose);

    await tester.pumpWidget(
      _focusTestApp(
        navigationFocus: navigationFocus,
        content: _SwitchingFocusablePage(
          key: pageKey,
          firstPageFocus: firstPageFocus,
          secondPageFocus: secondPageFocus,
        ),
      ),
    );

    navigationFocus.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(firstPageFocus.hasPrimaryFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    pageKey.currentState!.showSecondPage();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(secondPageFocus.hasPrimaryFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    pageKey.currentState!.showFirstPage();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(firstPageFocus.hasPrimaryFocus, isTrue);
  });

  testWidgets('content can consume left without losing focus', (tester) async {
    final navigationFocus = FocusNode();
    final contentFocus = FocusNode();
    addTearDown(navigationFocus.dispose);
    addTearDown(contentFocus.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(splashFactory: NoSplash.splashFactory),
        home: MenuDirectionalFocusBoundary(
          navigationEntryFocusNode: navigationFocus,
          navigationRail: Focus(
            focusNode: navigationFocus,
            child: const SizedBox(width: 80),
          ),
          content: Focus(
            focusNode: contentFocus,
            onKeyEvent: (node, event) {
              return event is KeyDownEvent &&
                      event.logicalKey == LogicalKeyboardKey.arrowLeft
                  ? KeyEventResult.handled
                  : KeyEventResult.ignored;
            },
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );

    contentFocus.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();

    expect(contentFocus.hasPrimaryFocus, isTrue);
    expect(navigationFocus.hasFocus, isFalse);
  });

  testWidgets('traditional navigation keeps the surrounding arrow action', (
    tester,
  ) async {
    final navigationFocus = FocusNode();
    addTearDown(navigationFocus.dispose);
    var surroundingActionCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(1280, 720),
            navigationMode: NavigationMode.traditional,
          ),
          child: Actions(
            actions: <Type, Action<Intent>>{
              DirectionalFocusIntent: CallbackAction<DirectionalFocusIntent>(
                onInvoke: (_) {
                  surroundingActionCount++;
                  return null;
                },
              ),
            },
            child: MenuDirectionalFocusBoundary(
              navigationEntryFocusNode: navigationFocus,
              navigationRail: Focus(
                focusNode: navigationFocus,
                child: const SizedBox(width: 80),
              ),
              content: const SizedBox.expand(),
            ),
          ),
        ),
      ),
    );

    navigationFocus.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();

    expect(surroundingActionCount, 1);
  });
}

Widget _focusTestApp({
  required FocusNode navigationFocus,
  required Widget content,
}) {
  return MaterialApp(
    theme: ThemeData(splashFactory: NoSplash.splashFactory),
    home: MediaQuery(
      data: const MediaQueryData(
        size: Size(1280, 720),
        navigationMode: NavigationMode.directional,
      ),
      child: MenuDirectionalFocusBoundary(
        navigationEntryFocusNode: navigationFocus,
        navigationRail: Focus(
          focusNode: navigationFocus,
          child: const SizedBox(width: 80),
        ),
        content: content,
      ),
    ),
  );
}

Widget _navigationRailFocusTestApp({
  required FocusNode navigationFocus,
  required Widget content,
}) {
  return MaterialApp(
    theme: ThemeData(splashFactory: NoSplash.splashFactory),
    home: MediaQuery(
      data: const MediaQueryData(
        size: Size(1280, 720),
        navigationMode: NavigationMode.directional,
      ),
      child: Scaffold(
        body: MenuDirectionalFocusBoundary(
          navigationEntryFocusNode: navigationFocus,
          navigationRail: NavigationRail(
            leading: FloatingActionButton(
              focusNode: navigationFocus,
              onPressed: () {},
              child: const Icon(Icons.search),
            ),
            selectedIndex: 0,
            onDestinationSelected: (_) {},
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.home_outlined),
                label: Text('推荐'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.settings_outlined),
                label: Text('我的'),
              ),
            ],
          ),
          content: content,
        ),
      ),
    ),
  );
}

class _DeferredFocusablePage extends StatefulWidget {
  const _DeferredFocusablePage({
    super.key,
    required this.contentFocus,
  });

  final FocusNode contentFocus;

  @override
  State<_DeferredFocusablePage> createState() => _DeferredFocusablePageState();
}

class _DeferredFocusablePageState extends State<_DeferredFocusablePage> {
  bool _showContent = false;

  void showContent() => setState(() => _showContent = true);

  @override
  Widget build(BuildContext context) {
    if (!_showContent) {
      return const SizedBox.expand();
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton(
        focusNode: widget.contentFocus,
        onPressed: () {},
        child: const Text('热门番剧'),
      ),
    );
  }
}

class _SwitchingFocusablePage extends StatefulWidget {
  const _SwitchingFocusablePage({
    super.key,
    required this.firstPageFocus,
    required this.secondPageFocus,
  });

  final FocusNode firstPageFocus;
  final FocusNode secondPageFocus;

  @override
  State<_SwitchingFocusablePage> createState() =>
      _SwitchingFocusablePageState();
}

class _SwitchingFocusablePageState extends State<_SwitchingFocusablePage> {
  bool _showSecond = false;

  void showFirstPage() => setState(() => _showSecond = false);

  void showSecondPage() => setState(() => _showSecond = true);

  @override
  Widget build(BuildContext context) {
    return TextButton(
      key: ValueKey(_showSecond),
      focusNode: _showSecond ? widget.secondPageFocus : widget.firstPageFocus,
      onPressed: () {},
      child: Text(_showSecond ? '第二页' : '热门番剧'),
    );
  }
}
