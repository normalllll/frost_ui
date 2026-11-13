import 'package:flutter_test/flutter_test.dart';
import 'package:frost_data/frost_data.dart';
import 'package:material_ui/material_ui.dart';

import '../../frost_ui/test/support.dart';

class _Source extends FrostListSource<int> {
  @override
  Future<List<int>> initList() => Future.value(List.generate(120, (i) => i));
  @override
  Future<List<int>> nextList() => Future.value([]);
}

void main() {
  final slivers = <String, Widget Function(_Source source, Widget Function(int index) tile)>{
    'data waterfall': (source, tile) =>
        FrostSliverDataWaterfallGrid<int>(source: source, firstLoadSkeleton: const SizedBox(), itemBuilder: (_, _, index) => tile(index)),
    'data grid': (source, tile) => FrostSliverDataGrid<int>(
      source: source,
      firstLoadSkeleton: const SizedBox(),
      minTileWidth: 200,
      tileHeight: (_, width) => width * .75,
      itemBuilder: (_, _, index) => tile(index),
    ),
  };

  for (final MapEntry(key: name, value: sliver) in slivers.entries) {
    testWidgets('scrolling a $name builds only the tiles that come into view; a new width builds them again', (tester) async {
      final source = _Source();
      addTearDown(source.dispose);
      await source.refresh(true);
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
                    child: CustomScrollView(controller: controller, slivers: [sliver(source, tile)]),
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(builds, isNotEmpty);

      List<int> builtAgain(Map<int, int> before) => [
        for (final MapEntry(:key, :value) in builds.entries)
          if (before.containsKey(key) && value > before[key]!) key,
      ];
      for (final offset in [1.0, 2.0, 3.0, 4.0]) {
        final before = Map.of(builds);
        controller.jumpTo(offset);
        await tester.pump();
        expect(builtAgain(before), isEmpty, reason: 'scrolled to $offset px');
      }

      final before = Map.of(builds);
      resize(() => width = 600);
      await tester.pump();
      expect(builtAgain(before), isNotEmpty, reason: 'a new width lays the tiles out in new columns');
      expect(tester.takeException(), isNull);
    });
  }
}
