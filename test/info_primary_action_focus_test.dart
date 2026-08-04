import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/pages/info/info_page.dart';

void main() {
  testWidgets(
    'directional navigation focuses play without scrolling the overview',
    (tester) async {
      final primaryActionFocus = FocusNode();
      final scrollController = ScrollController();
      addTearDown(primaryActionFocus.dispose);
      addTearDown(scrollController.dispose);
      var activationCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(splashFactory: NoSplash.splashFactory),
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(1280, 720),
              navigationMode: NavigationMode.directional,
            ),
            child: Scaffold(
              body: SingleChildScrollView(
                controller: scrollController,
                child: Column(
                  children: List.generate(
                    40,
                    (index) => TextButton(
                      onPressed: () {},
                      child: Text('概览操作 $index'),
                    ),
                  ),
                ),
              ),
              floatingActionButton: InfoPrimaryActionButton(
                focusNode: primaryActionFocus,
                tooltip: '开始观看',
                label: '开始观看',
                icon: Icons.play_arrow_rounded,
                onPressed: () => activationCount++,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(primaryActionFocus.hasPrimaryFocus, isTrue);
      expect(scrollController.offset, 0);

      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      expect(activationCount, 1);
    },
  );

  testWidgets('traditional navigation does not steal focus from content', (
    tester,
  ) async {
    final contentFocus = FocusNode();
    final primaryActionFocus = FocusNode();
    addTearDown(contentFocus.dispose);
    addTearDown(primaryActionFocus.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(1280, 720),
            navigationMode: NavigationMode.traditional,
          ),
          child: Scaffold(
            body: TextButton(
              focusNode: contentFocus,
              autofocus: true,
              onPressed: () {},
              child: const Text('正文操作'),
            ),
            floatingActionButton: InfoPrimaryActionButton(
              focusNode: primaryActionFocus,
              tooltip: '开始观看',
              label: '开始观看',
              icon: Icons.play_arrow_rounded,
              onPressed: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(contentFocus.hasPrimaryFocus, isTrue);
    expect(primaryActionFocus.hasFocus, isFalse);
  });

  testWidgets('tab action changes without dropping primary focus', (
    tester,
  ) async {
    final primaryActionFocus = FocusNode();
    addTearDown(primaryActionFocus.dispose);
    late StateSetter updateAction;
    var showRatingAction = false;
    var playCount = 0;
    var ratingCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(1280, 720),
            navigationMode: NavigationMode.directional,
          ),
          child: StatefulBuilder(
            builder: (context, setState) {
              updateAction = setState;
              return Scaffold(
                floatingActionButton: InfoPrimaryActionButton(
                  focusNode: primaryActionFocus,
                  tooltip: showRatingAction ? '吐槽' : '开始观看',
                  label: showRatingAction ? '发表吐槽' : '开始观看',
                  icon: showRatingAction
                      ? Icons.rate_review_rounded
                      : Icons.play_arrow_rounded,
                  onPressed: showRatingAction
                      ? () => ratingCount++
                      : () => playCount++,
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pump();
    expect(primaryActionFocus.hasPrimaryFocus, isTrue);

    updateAction(() => showRatingAction = true);
    await tester.pump();

    expect(primaryActionFocus.hasPrimaryFocus, isTrue);
    expect(find.text('发表吐槽'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    expect(playCount, 0);
    expect(ratingCount, 1);
  });

  testWidgets('async rebuild does not steal focus back from overview', (
    tester,
  ) async {
    final overviewFocus = FocusNode();
    final primaryActionFocus = FocusNode();
    addTearDown(overviewFocus.dispose);
    addTearDown(primaryActionFocus.dispose);
    late StateSetter finishLoading;
    var isLoading = true;

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(1280, 720),
            navigationMode: NavigationMode.directional,
          ),
          child: StatefulBuilder(
            builder: (context, setState) {
              finishLoading = setState;
              return Scaffold(
                body: TextButton(
                  focusNode: overviewFocus,
                  onPressed: () {},
                  child: Text(isLoading ? '正在加载' : '简介已加载'),
                ),
                floatingActionButton: InfoPrimaryActionButton(
                  focusNode: primaryActionFocus,
                  tooltip: '开始观看',
                  label: '开始观看',
                  icon: Icons.play_arrow_rounded,
                  onPressed: () {},
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pump();
    expect(primaryActionFocus.hasPrimaryFocus, isTrue);

    overviewFocus.requestFocus();
    await tester.pump();
    expect(overviewFocus.hasPrimaryFocus, isTrue);

    finishLoading(() => isLoading = false);
    await tester.pump();

    expect(find.text('简介已加载'), findsOneWidget);
    expect(overviewFocus.hasPrimaryFocus, isTrue);
    expect(primaryActionFocus.hasFocus, isFalse);
  });

  testWidgets('closing an overlay restores focus to the primary action', (
    tester,
  ) async {
    final primaryActionFocus = FocusNode();
    final overlayFocus = FocusNode();
    addTearDown(primaryActionFocus.dispose);
    addTearDown(overlayFocus.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(1280, 720),
            navigationMode: NavigationMode.directional,
          ),
          child: Scaffold(
            floatingActionButton: Builder(
              builder: (context) {
                return InfoPrimaryActionButton(
                  focusNode: primaryActionFocus,
                  tooltip: '开始观看',
                  label: '开始观看',
                  icon: Icons.play_arrow_rounded,
                  onPressed: () {
                    showModalBottomSheet<void>(
                      context: context,
                      builder: (context) => TextButton(
                        focusNode: overlayFocus,
                        autofocus: true,
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('关闭选源'),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(primaryActionFocus.hasPrimaryFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(overlayFocus.hasPrimaryFocus, isTrue);
    expect(primaryActionFocus.hasPrimaryFocus, isFalse);

    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(find.text('关闭选源'), findsNothing);
    expect(primaryActionFocus.hasPrimaryFocus, isTrue);
  });
}
