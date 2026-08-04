// ignore_for_file: deprecated_member_use

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:kazumi/pages/settings/keyboard_settings.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:kazumi/utils/constants.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory storageDirectory;
  late PathProviderPlatform originalPathProvider;

  setUpAll(() async {
    storageDirectory = await Directory.systemTemp.createTemp(
      'kazumi-keyboard-settings-test-',
    );
    originalPathProvider = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _TestPathProvider(storageDirectory.path);
    final hiveDirectory = Directory('${storageDirectory.path}/hive');
    await hiveDirectory.create(recursive: true);
    Hive.init(hiveDirectory.path);
    await GStorage.init();
  });

  setUp(() async {
    for (final entry in defaultShortcuts.entries) {
      await GStorage.putStringListSettingByName(
        'shortcut_${entry.key}',
        entry.value.toList(),
      );
    }
    // Leave Arrow Right available so the test can prove a D-pad key is
    // captured instead of moving focus during recording.
    await GStorage.putStringListSettingByName('shortcut_forward', ['L']);
  });

  tearDownAll(() async {
    PathProviderPlatform.instance = originalPathProvider;
    await storageDirectory.delete(recursive: true);
  });

  testWidgets(
    'directional remote can edit, cancel, and add shortcut bindings',
    (tester) async {
      // Hive flushes buffered file writes while closing. Widget tests run in
      // a fake-async zone, so perform that real I/O through runAsync.
      addTearDown(
        () => tester.runAsync<void>(() async {
          await Hive.box<dynamic>('setting').close();
          await GStorage.favorites.close();
          await GStorage.collectibles.close();
          await GStorage.histories.close();
          await GStorage.collectChanges.close();
          await GStorage.shieldList.close();
          await GStorage.searchHistory.close();
          await GStorage.downloads.close();
        }),
      );

      var fallbackBackCount = 0;
      final routerDelegate = _TestRouterDelegate(() => fallbackBackCount++);
      final backDispatcher = RootBackButtonDispatcher();
      addTearDown(routerDelegate.dispose);
      routerDelegate.child = const MediaQuery(
        data: MediaQueryData(
          size: Size(1280, 720),
          navigationMode: NavigationMode.directional,
        ),
        child: KeyboardSettingsPage(),
      );
      Future<void> sendPersistingKey(LogicalKeyboardKey key) async {
        await tester.runAsync<void>(() async {
          await tester.sendKeyEvent(key);
          await Hive.box<dynamic>('setting').flush();
        });
        await tester.pump();
      }

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(splashFactory: NoSplash.splashFactory),
          home: Router<Object>(
            routerDelegate: routerDelegate,
            backButtonDispatcher: backDispatcher,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('空格'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pump();
      expect(find.text('按任意键'), findsOneWidget);
      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        'keyboard shortcut capture',
      );

      await sendPersistingKey(LogicalKeyboardKey.arrowRight);
      expect(find.text('→'), findsOneWidget);
      expect(
        GStorage.getStringListSettingByName('shortcut_playorpause'),
        ['Arrow Right'],
      );

      // Focus returns to the edited keycap, so Select can immediately edit it
      // again. Raw Back cancels recording and the paired system back must not
      // pop the settings route.
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pump();
      expect(find.text('按任意键'), findsOneWidget);

      late bool rawBackHandled;
      await tester.runAsync<void>(() async {
        rawBackHandled = _sendRemoteBack(tester);
        await Hive.box<dynamic>('setting').flush();
      });
      expect(rawBackHandled, isTrue);
      final pairedSystemBackHandled = await backDispatcher.invokeCallback(
        SynchronousFuture<bool>(false),
      );
      await tester.pump();
      expect(pairedSystemBackHandled, isTrue);
      expect(fallbackBackCount, 0);
      expect(find.text('操作设置'), findsOneWidget);
      expect(find.text('按任意键'), findsNothing);
      expect(find.text('→'), findsOneWidget);

      // The add button is immediately to the right of the sole keycap.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pump();
      expect(find.text('按任意键'), findsOneWidget);

      await sendPersistingKey(LogicalKeyboardKey.keyQ);
      expect(find.text('Q'), findsOneWidget);
      expect(
        GStorage.getStringListSettingByName('shortcut_playorpause'),
        ['Arrow Right', 'Q'],
      );
    },
  );
}

bool _sendRemoteBack(WidgetTester tester) {
  return tester.binding.keyEventManager.keyMessageHandler!(
    KeyMessage(
      const <KeyEvent>[
        KeyDownEvent(
          physicalKey: PhysicalKeyboardKey.escape,
          logicalKey: LogicalKeyboardKey.goBack,
          timeStamp: Duration.zero,
        ),
      ],
      null,
    ),
  );
}

class _TestPathProvider extends PathProviderPlatform {
  _TestPathProvider(this.rootPath);

  final String rootPath;

  @override
  Future<String?> getApplicationSupportPath() async => rootPath;
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
