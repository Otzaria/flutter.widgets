import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

const screenHeight = 400.0;
const screenWidth = 400.0;
const itemHeight = screenHeight / 10.0;
const itemCount = 500;

void main() {
  Future<void> pumpList(
    WidgetTester tester, {
    ItemScrollController? itemScrollController,
    ItemPositionsListener? itemPositionsListener,
    int initialIndex = 0,
    double cacheExtentScreens = 2,
    double? minCacheExtent,
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(screenWidth, screenHeight);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: ScrollablePositionedList.builder(
          itemCount: itemCount,
          itemScrollController: itemScrollController,
          itemPositionsListener: itemPositionsListener,
          initialScrollIndex: initialIndex,
          cacheExtentScreens: cacheExtentScreens,
          minCacheExtent: minCacheExtent,
          itemBuilder: (context, index) => SizedBox(
            height: itemHeight,
            child: Text('Item $index'),
          ),
        ),
      ),
    );
  }

  bool isBuilt(int index) =>
      find.text('Item $index', skipOffstage: false).evaluate().isNotEmpty;

  group('cacheExtentScreens', () {
    testWidgets('defaults to two screens on each side',
        (WidgetTester tester) async {
      await pumpList(tester, initialIndex: 100);

      expect(isBuilt(85), isTrue);
      expect(isBuilt(125), isTrue);
    });

    testWidgets('limits the items laid out around the target',
        (WidgetTester tester) async {
      await pumpList(tester, initialIndex: 100, cacheExtentScreens: 1);

      expect(isBuilt(95), isTrue);
      expect(isBuilt(115), isTrue);
      expect(isBuilt(85), isFalse);
      expect(isBuilt(125), isFalse);
    });

    testWidgets('applies to jumps', (WidgetTester tester) async {
      final itemScrollController = ItemScrollController();
      await pumpList(
        tester,
        itemScrollController: itemScrollController,
        cacheExtentScreens: 1,
      );

      itemScrollController.jumpTo(index: 300);
      await tester.pump();

      expect(find.text('Item 300'), findsOneWidget);
      expect(isBuilt(315), isTrue);
      expect(isBuilt(325), isFalse);
    });

    testWidgets('minCacheExtent is still a lower bound',
        (WidgetTester tester) async {
      await pumpList(
        tester,
        initialIndex: 100,
        cacheExtentScreens: 0,
        minCacheExtent: 5 * itemHeight,
      );

      expect(isBuilt(113), isTrue);
      expect(isBuilt(118), isFalse);
    });
  });

  group('item positions', () {
    testWidgets('a scroll that moves no position does not notify',
        (WidgetTester tester) async {
      final itemPositionsListener = ItemPositionsListener.create();
      await pumpList(tester, itemPositionsListener: itemPositionsListener);
      var notifications = 0;
      itemPositionsListener.itemPositions.addListener(() => notifications++);
      final position =
          tester.state<ScrollableState>(find.byType(Scrollable)).position;

      position.jumpTo(position.pixels + 10);
      await tester.pump();
      expect(notifications, 1);
      final moved = itemPositionsListener.itemPositions.value;

      position.jumpTo(position.pixels + 0.2);
      await tester.pump();
      expect(notifications, 1);
      expect(itemPositionsListener.itemPositions.value, moved);
    });

    testWidgets('a rebuild notifies even when positions are unchanged',
        (WidgetTester tester) async {
      final itemPositionsListener = ItemPositionsListener.create();
      await pumpList(tester, itemPositionsListener: itemPositionsListener);
      final before = itemPositionsListener.itemPositions.value.toList();
      var notifications = 0;
      itemPositionsListener.itemPositions.addListener(() => notifications++);

      await pumpList(tester, itemPositionsListener: itemPositionsListener);

      expect(notifications, 1);
      expect(itemPositionsListener.itemPositions.value, before);
    });

    testWidgets('only items intersecting the viewport are reported',
        (WidgetTester tester) async {
      final itemPositionsListener = ItemPositionsListener.create();
      await pumpList(
        tester,
        itemPositionsListener: itemPositionsListener,
        initialIndex: 100,
      );

      final indices =
          itemPositionsListener.itemPositions.value.map((p) => p.index);
      expect(indices.toSet(), {for (var i = 100; i < 110; i++) i});
    });
  });
}
