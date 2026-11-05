import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';

import 'page_support.dart';
import 'support.dart';

const _count = 400;
final _items = List.generate(_count, (i) => i);

// Uneven heights, so each tile's column depends on every earlier tile.
double _height(int index) => 80 + (index * 37) % 170;
Widget _tile(BuildContext context, int item, int index) => SizedBox(key: ValueKey(index), height: _height(index));
Finder _item(int index) => find.byKey(ValueKey(index));

ScrollPosition _position(WidgetTester tester) =>
    tester.stateList<ScrollableState>(find.byType(Scrollable)).firstWhere((state) => state.position.axis == Axis.vertical).position;

void main() {
  void viewport(WidgetTester tester, Size size) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);
  }

  Widget plain({FrostWaterfallController? controller, double width = 900, double height = 600}) => frostTestApp(
    Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: width,
        height: height,
        child: FrostWaterfallGrid<int>(items: _items, itemBuilder: _tile, controller: controller),
      ),
    ),
  );

  // Where scrolling a viewport at a time places [index]: its left edge and
  // its top in content offsets.
  Future<({double left, double top})> scrolledTo(WidgetTester tester, Widget app, int index) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(app);
    final position = _position(tester);
    while (_item(index).evaluate().isEmpty) {
      position.jumpTo(position.pixels + 300);
      await tester.pump();
    }
    final rect = tester.getRect(_item(index));
    return (left: rect.left, top: rect.top + position.pixels);
  }

  testWidgets('an item beyond the built tiles comes into view at the bottom edge, in its scrolled column', (tester) async {
    viewport(tester, const Size(1000, 800));
    final expected = await scrolledTo(tester, plain(), 250);
    await tester.pumpWidget(const SizedBox());

    final controller = FrostWaterfallController();
    await tester.pumpWidget(plain(controller: controller));
    expect(_item(250), findsNothing);
    controller.reveal(250);
    await tester.pump();
    final rect = tester.getRect(_item(250));
    final position = _position(tester);
    expect(rect.bottom, moreOrLessEquals(600, epsilon: .01));
    expect(rect.left, expected.left);
    expect(rect.top + position.pixels, moreOrLessEquals(expected.top, epsilon: .01));
    expect(tester.takeException(), isNull);

    // Back up the list: the item's top meets the top edge.
    controller.reveal(12);
    await tester.pump();
    final back = tester.getRect(_item(12));
    expect(back.top, moreOrLessEquals(0, epsilon: .01));
    expect(tester.takeException(), isNull);
    expect(back.left, (await scrolledTo(tester, plain(), 12)).left);
  });

  testWidgets('an item far above the built tiles is placed where scrolling placed it', (tester) async {
    viewport(tester, const Size(1000, 800));
    final controller = FrostWaterfallController();
    await tester.pumpWidget(plain(controller: controller));
    final first = tester.getRect(_item(8)).translate(0, _position(tester).pixels);
    controller.reveal(380);
    await tester.pump();
    expect(_item(8), findsNothing);
    controller.reveal(8);
    await tester.pump();
    final rect = tester.getRect(_item(8));
    expect(rect.top, moreOrLessEquals(0, epsilon: .01));
    expect(rect.translate(0, _position(tester).pixels), first);
  });

  testWidgets('a fully visible item does not move', (tester) async {
    viewport(tester, const Size(1000, 800));
    final controller = FrostWaterfallController();
    await tester.pumpWidget(plain(controller: controller));
    final position = _position(tester);
    position.jumpTo(500);
    await tester.pump();
    final visible = [
      for (var i = 0; i < _count; i++)
        if (_item(i).evaluate().isNotEmpty && tester.getRect(_item(i)).top >= 0 && tester.getRect(_item(i)).bottom <= 600) i,
    ];
    expect(visible, isNotEmpty);
    final rect = tester.getRect(_item(visible.last));
    controller.reveal(visible.last);
    await tester.pump();
    expect(position.pixels, 500);
    expect(tester.getRect(_item(visible.last)), rect);
  });

  testWidgets('indexes outside the loaded items are ignored', (tester) async {
    viewport(tester, const Size(1000, 800));
    final controller = FrostWaterfallController();
    await tester.pumpWidget(plain(controller: controller));
    final position = _position(tester);
    position.jumpTo(300);
    await tester.pump();
    for (final index in [-1, _count, _count + 50]) {
      controller.reveal(index);
      await tester.pump();
      expect(position.pixels, 300);
    }
    expect(tester.takeException(), isNull);
    // Unbound calls are harmless too.
    await tester.pumpWidget(const SizedBox());
    controller.reveal(3);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('after a resize changes the column count the next reveal uses the new columns', (tester) async {
    viewport(tester, const Size(1000, 800));
    final expected = await scrolledTo(tester, plain(width: 560), 300);
    await tester.pumpWidget(const SizedBox());

    final controller = FrostWaterfallController();
    var width = 900.0;
    late StateSetter resize;
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          resize = setState;
          return plain(controller: controller, width: width);
        },
      ),
    );
    controller.reveal(150);
    await tester.pump();
    final wide = tester.getRect(_item(150)).width;
    resize(() => width = 560);
    await tester.pump();
    controller.reveal(300);
    await tester.pump();
    final rect = tester.getRect(_item(300));
    expect(rect.width, greaterThan(wide));
    expect(rect.bottom, moreOrLessEquals(600, epsilon: .01));
    expect(rect.left, expected.left);
    expect(rect.top + _position(tester).pixels, moreOrLessEquals(expected.top, epsilon: .01));
    expect(tester.takeException(), isNull);
  });

  for (final (mode, width) in [('one-row', 1147.0), ('two-row', 412.0)]) {
    testWidgets('in a $mode pinned page the header rows never cover the item', (tester) async {
      viewport(tester, Size(width, 800));
      final controller = FrostWaterfallController();
      await tester.pumpWidget(
        frostTestApp(
          DefaultTabController(
            length: 3,
            child: pinnedPage(
              header: FrostPageHeader(
                leading: [
                  FrostTitleMenu(
                    title: 'yande',
                    entries: [FrostMenuAction('konachan', onSelected: () {})],
                  ),
                ],
                actions: [
                  FrostToolbarItem.action(icon: testIcons.filter, label: 'Filter', onPressed: () {}),
                  FrostToolbarItem.action(icon: testIcons.more, label: 'More', onPressed: () {}),
                ],
              ),
              tabs: const FrostTabBar(
                scrollable: true,
                tabs: [
                  FrostTab(label: 'New'),
                  FrostTab(label: 'Hot'),
                  FrostTab(label: 'Random'),
                ],
              ),
              slivers: [FrostSliverWaterfallGrid<int>(items: _items, itemBuilder: _tile, controller: controller)],
            ),
          ),
        ),
      );
      final header = tester.getRect(find.byType(FrostPageHeader)), tabs = tester.getRect(find.byType(FrostTabBar));
      final chrome = mode == 'one-row' ? header.bottom : tabs.bottom;
      if (mode == 'one-row') {
        expect(tabs.center.dy, moreOrLessEquals(header.center.dy, epsilon: .5));
      } else {
        expect(tabs.top, moreOrLessEquals(header.bottom, epsilon: .5));
      }

      controller.reveal(260);
      await tester.pump();
      expect(tester.getRect(_item(260)).bottom, moreOrLessEquals(800, epsilon: .01));

      controller.reveal(180);
      await tester.pump();
      final rect = tester.getRect(_item(180));
      expect(rect.top, moreOrLessEquals(chrome, epsilon: .01));
      expect(rect.top, greaterThanOrEqualTo(tester.getRect(find.byType(FrostTabBar)).bottom - .01));
      await tester.pumpAndSettle();
      expect(tester.getRect(_item(180)), rect);
      expect(tester.takeException(), isNull);
    });
  }
}
