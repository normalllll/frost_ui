import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:material_ui/material_ui.dart';

import 'support.dart';

typedef _Sliver = Widget Function(Widget Function(int index) tile);

void main() {
  final slivers = <String, _Sliver>{
    'waterfall': (tile) => FrostSliverWaterfallGrid<int>(items: List.generate(200, (i) => i), itemBuilder: (_, _, index) => tile(index)),
    'card waterfall': (tile) =>
        FrostSliverWaterfallGrid<int>(items: List.generate(200, (i) => i), minTileWidth: 260, itemBuilder: (_, _, index) => tile(index)),
    'grid': (tile) => FrostSliverGrid(minItemWidth: 160, aspectRatio: 1, itemCount: 200, itemBuilder: (_, index) => tile(index)),
    'list in columns': (tile) => FrostSliverList.columns(itemCount: 200, minColumnWidth: 280, itemBuilder: (_, index) => tile(index)),
  };

  for (final MapEntry(key: name, value: sliver) in slivers.entries) {
    testWidgets('scrolling a $name builds only the tiles that come into view; a new width builds them again', (tester) async {
      final builds = <int, int>{};
      final controller = ScrollController();
      addTearDown(controller.dispose);
      var width = 900.0;
      late StateSetter resize;
      Widget tile(int index) {
        builds.update(index, (count) => count + 1, ifAbsent: () => 1);
        return SizedBox(height: 120.0 + (index % 5) * 40, child: Text('$index'));
      }

      await tester.pumpWidget(
        frostTestApp(
          Material(
            child: StatefulBuilder(
              builder: (context, set) {
                resize = set;
                return Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: width,
                    child: CustomScrollView(controller: controller, slivers: [sliver(tile)]),
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(builds, isNotEmpty);

      for (final offset in [1.0, 2.0, 3.0, 4.0]) {
        final before = Map.of(builds);
        controller.jumpTo(offset);
        await tester.pump();
        final again = [
          for (final MapEntry(:key, :value) in builds.entries)
            if (before.containsKey(key) && value > before[key]!) key,
        ];
        expect(again, isEmpty, reason: 'scrolled to $offset px');
      }

      final before = Map.of(builds);
      resize(() => width = 600);
      await tester.pump();
      final rebuilt = [
        for (final MapEntry(:key, :value) in builds.entries)
          if (before.containsKey(key) && value > before[key]!) key,
      ];
      expect(rebuilt, isNotEmpty, reason: 'a new width lays the tiles out in new columns');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('a minimum tile width gives cards one column on a phone and more on wider windows', (tester) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    Future<int> columns(double width, {double? minTileWidth, int? maxColumns}) async {
      await tester.pumpWidget(
        frostTestApp(
          Material(
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: width,
                child: CustomScrollView(
                  slivers: [
                    FrostSliverWaterfallGrid<int>(
                      items: List.generate(12, (i) => i),
                      minTileWidth: minTileWidth,
                      maxColumns: maxColumns,
                      itemBuilder: (_, item, _) => SizedBox(key: ValueKey(item), height: 80),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      return {for (var item = 0; item < 4; item++) tester.getTopLeft(find.byKey(ValueKey(item))).dx}.length;
    }

    expect(await columns(390, minTileWidth: 280), 1);
    expect(await columns(390), 2, reason: 'media keeps two columns on a phone');
    expect(await columns(1400, minTileWidth: 280), greaterThan(2));
    expect(await columns(1400, minTileWidth: 280, maxColumns: 2), 2);
  });
}
