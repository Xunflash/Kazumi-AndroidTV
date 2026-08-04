// ignore_for_file: deprecated_member_use

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/modules/collect/collect_type.dart';
import 'package:kazumi/pages/collect/collect_controller.dart';
import 'package:kazumi/pages/player/player_panel_hold.dart';
import 'package:kazumi/repositories/collect_crud_repository.dart';
import 'package:kazumi/repositories/collect_repository.dart';

void main() {
  testWidgets('open menu consumes remote dismiss keys and releases its hold', (
    tester,
  ) async {
    final fixture = _MenuFixture(includeClosedSibling: true);
    addTearDown(fixture.dispose);
    await tester.pumpWidget(fixture.build());

    for (final keyPair in _remoteDismissKeys) {
      await fixture.openMenu(tester);

      final handled = _sendRemoteKey(tester, keyPair);
      await tester.pump();

      expect(handled, isTrue);
      expect(find.text('First item'), findsNothing);
      expect(fixture.fallbackBackCount, 0);
      expect(fixture.ancestorKeyCount, 0);
    }

    expect(fixture.acquireCount, 4);
    expect(fixture.releaseCount, 4);
    expect(
      fixture.visibilityChanges,
      <bool>[true, false, true, false, true, false, true, false],
    );
  });

  testWidgets('closed menu passes remote dismiss keys to its focus ancestor', (
    tester,
  ) async {
    final fixture = _MenuFixture();
    addTearDown(fixture.dispose);
    await tester.pumpWidget(fixture.build());
    fixture.anchorButtonFocus.requestFocus();
    await tester.pump();

    for (final keyPair in _remoteDismissKeys) {
      expect(_sendRemoteKey(tester, keyPair), isTrue);
    }

    expect(fixture.ancestorKeyCount, _remoteDismissKeys.length);
    expect(fixture.acquireCount, 0);
    expect(fixture.releaseCount, 0);
  });

  testWidgets('system back closes an open menu and passes through when closed',
      (
    tester,
  ) async {
    final fixture = _MenuFixture(includeClosedSibling: true);
    addTearDown(fixture.dispose);
    await tester.pumpWidget(fixture.build());
    await fixture.openMenu(tester);

    final openHandled = await fixture.backDispatcher.invokeCallback(
      SynchronousFuture<bool>(false),
    );
    await tester.pump();

    expect(openHandled, isTrue);
    expect(find.text('First item'), findsNothing);
    expect(fixture.fallbackBackCount, 0);
    expect(fixture.acquireCount, 1);
    expect(fixture.releaseCount, 1);

    final closedHandled = await fixture.backDispatcher.invokeCallback(
      SynchronousFuture<bool>(false),
    );

    expect(closedHandled, isTrue);
    expect(fixture.fallbackBackCount, 1);
  });

  testWidgets('remote back and paired system back close only the menu', (
    tester,
  ) async {
    final fixture = _MenuFixture(includeClosedSibling: true);
    addTearDown(fixture.dispose);
    await tester.pumpWidget(fixture.build());
    await fixture.openMenu(tester);

    _sendRemoteKey(tester, _remoteDismissKeys.first);
    final systemHandled = await fixture.backDispatcher.invokeCallback(
      SynchronousFuture<bool>(false),
    );

    expect(systemHandled, isTrue);
    expect(fixture.fallbackBackCount, 0);
    expect(fixture.releaseCount, 1);

    await tester.pump();
    final laterSystemHandled = await fixture.backDispatcher.invokeCallback(
      SynchronousFuture<bool>(false),
    );

    expect(laterSystemHandled, isTrue);
    expect(fixture.fallbackBackCount, 1);
  });

  testWidgets('menu keeps native directional navigation and activation', (
    tester,
  ) async {
    final fixture = _MenuFixture();
    addTearDown(fixture.dispose);
    await tester.pumpWidget(fixture.build());
    await fixture.openMenu(tester);

    fixture.firstItemFocus.requestFocus();
    await tester.pump();
    expect(fixture.firstItemFocus.hasPrimaryFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(fixture.secondItemFocus.hasPrimaryFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump();
    expect(fixture.secondActivationCount, 1);
    expect(find.text('First item'), findsNothing);
    expect(fixture.releaseCount, 1);
  });

  testWidgets(
    'collect menu consumes remote and paired system Back before player controls',
    (tester) async {
      final fixture = _CollectMenuFixture();
      addTearDown(fixture.dispose);
      await tester.pumpWidget(fixture.build());

      await tester.tap(find.byTooltip('未追'));
      await tester.pump();
      expect(find.text(' 在看'), findsOneWidget);
      expect(fixture.visibilityChanges, <bool>[true]);
      expect(fixture.acquireCount, 1);

      expect(_sendRemoteKey(tester, _remoteDismissKeys.first), isTrue);
      final systemHandled = await fixture.backDispatcher.invokeCallback(
        SynchronousFuture<bool>(false),
      );
      await tester.pump();

      expect(systemHandled, isTrue);
      expect(find.text(' 在看'), findsNothing);
      expect(fixture.visibilityChanges, <bool>[true, false]);
      expect(fixture.releaseCount, 1);
      expect(fixture.playerControlExitCount, 0);
      expect(fixture.fallbackBackCount, 0);
    },
  );
}

class _CollectMenuFixture {
  final RootBackButtonDispatcher backDispatcher = RootBackButtonDispatcher();
  final List<bool> visibilityChanges = <bool>[];
  late final CollectController collectController = CollectController(
    _FakeCollectCrudRepository(),
    _FakeCollectRepository(),
  );
  late final _TestRouterDelegate routerDelegate = _TestRouterDelegate(() {
    fallbackBackCount++;
  });

  int acquireCount = 0;
  int releaseCount = 0;
  int playerControlExitCount = 0;
  int fallbackBackCount = 0;

  Widget build() {
    routerDelegate.child = Material(
      child: Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onKeyEvent: (_, event) {
          if (event is KeyDownEvent &&
              isPlayerPanelMenuDismissKey(event.logicalKey)) {
            playerControlExitCount++;
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: Center(
          child: PlayerPanelHoldCollectButton(
            acquirePlayerPanelHold: () {
              acquireCount++;
              return PlayerPanelHold(onRelease: () => releaseCount++);
            },
            bangumiItem: _testBangumi,
            onVisibilityChanged: visibilityChanges.add,
            collectController: collectController,
          ),
        ),
      ),
    );
    return MaterialApp(
      home: Router<Object>(
        routerDelegate: routerDelegate,
        backButtonDispatcher: backDispatcher,
      ),
    );
  }

  void dispose() {
    routerDelegate.dispose();
  }
}

class _FakeCollectCrudRepository implements ICollectCrudRepository {
  @override
  int getCollectType(int id) => 0;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeCollectRepository implements ICollectRepository {
  @override
  Set<int> getBangumiIdsByType(CollectType type) => <int>{};

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final BangumiItem _testBangumi = BangumiItem(
  id: 1,
  type: 2,
  name: 'Test',
  nameCn: 'Test',
  summary: '',
  airDate: '',
  airWeekday: 1,
  rank: 0,
  images: <String, String>{},
  tags: const [],
  alias: const [],
  ratingScore: 0,
  votes: 0,
  votesCount: const [],
  info: '',
);

class _MenuFixture {
  _MenuFixture({this.includeClosedSibling = false});

  final bool includeClosedSibling;
  final RootBackButtonDispatcher backDispatcher = RootBackButtonDispatcher();
  final FocusNode anchorButtonFocus = FocusNode(debugLabel: 'menu anchor');
  final FocusNode firstItemFocus = FocusNode(debugLabel: 'first menu item');
  final FocusNode secondItemFocus = FocusNode(debugLabel: 'second menu item');
  final List<bool> visibilityChanges = <bool>[];

  late final _TestRouterDelegate routerDelegate = _TestRouterDelegate(() {
    fallbackBackCount++;
  });

  int acquireCount = 0;
  int releaseCount = 0;
  int fallbackBackCount = 0;
  int ancestorKeyCount = 0;
  int secondActivationCount = 0;

  Widget build() {
    routerDelegate.child = Material(
      child: Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent &&
              _remoteDismissKeys.any(
                (keyPair) => keyPair.logical == event.logicalKey,
              )) {
            ancestorKeyCount++;
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              PlayerPanelHoldMenuAnchor(
                acquirePlayerPanelHold: () {
                  acquireCount++;
                  return PlayerPanelHold(onRelease: () => releaseCount++);
                },
                onVisibilityChanged: visibilityChanges.add,
                builder: (context, controller, child) {
                  return TextButton(
                    focusNode: anchorButtonFocus,
                    onPressed: controller.open,
                    child: const Text('Open menu'),
                  );
                },
                menuChildren: <Widget>[
                  MenuItemButton(
                    focusNode: firstItemFocus,
                    onPressed: () {},
                    child: const Text('First item'),
                  ),
                  MenuItemButton(
                    focusNode: secondItemFocus,
                    onPressed: () => secondActivationCount++,
                    child: const Text('Second item'),
                  ),
                ],
              ),
              if (includeClosedSibling)
                PlayerPanelHoldMenuAnchor(
                  acquirePlayerPanelHold: () =>
                      PlayerPanelHold(onRelease: () {}),
                  onVisibilityChanged: (_) {},
                  builder: (context, controller, child) {
                    return TextButton(
                      onPressed: controller.open,
                      child: const Text('Open other menu'),
                    );
                  },
                  menuChildren: <Widget>[
                    MenuItemButton(
                      onPressed: () {},
                      child: const Text('Other item'),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
    return MaterialApp(
      home: Router<Object>(
        routerDelegate: routerDelegate,
        backButtonDispatcher: backDispatcher,
      ),
    );
  }

  Future<void> openMenu(WidgetTester tester) async {
    await tester.tap(find.text('Open menu'));
    await tester.pump();
    expect(find.text('First item'), findsOneWidget);
  }

  void dispose() {
    anchorButtonFocus.dispose();
    firstItemFocus.dispose();
    secondItemFocus.dispose();
    routerDelegate.dispose();
  }
}

const _remoteDismissKeys =
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
  // Unsupported remote keys cannot be synthesized through sendKeyEvent.
  return tester.binding.keyEventManager.keyMessageHandler!(
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

class _TestRouterDelegate extends RouterDelegate<Object> with ChangeNotifier {
  _TestRouterDelegate(this.onPopRoute);

  final VoidCallback onPopRoute;
  Widget child = const SizedBox.shrink();

  @override
  Widget build(BuildContext context) => child;

  @override
  Future<bool> popRoute() {
    onPopRoute();
    return SynchronousFuture<bool>(true);
  }

  @override
  Future<void> setNewRoutePath(Object configuration) {
    return SynchronousFuture<void>(null);
  }
}
