import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_data/frost_data.dart';
import 'package:frost_ui/frost_ui.dart';

import '../../frost_ui/test/support.dart';

class _Source extends FrostListSource<int> {
  _Source(this.count);
  final int count;
  @override
  Future<List<int>> initList() => Future.value(List.generate(count, (i) => i));
  @override
  Future<List<int>> nextList() => Future.value([]);
}

const _count = 400;

// Uneven heights, so each tile's column depends on every earlier tile.
double _height(int index) => 80 + (index * 37) % 170;
Widget _tile(BuildContext context, int item, int index) => SizedBox(key: ValueKey(index), height: _height(index));
Finder _item(int index) => find.byKey(ValueKey(index));

void main() {
  void viewport(WidgetTester tester, Size size) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);
  }

  testWidgets('the paged waterfall reveals a loaded item', (tester) async {
    viewport(tester, const Size(1000, 800));
    final source = _Source(_count);
    addTearDown(source.dispose);
    await source.refresh(true);
    final controller = FrostWaterfallController();
    await tester.pumpWidget(
      frostTestApp(
        Scaffold(
          body: FrostLoadingScrollView(
            slivers: [FrostSliverDataWaterfallGrid<int>(source: source, itemBuilder: _tile, firstLoadSkeleton: const SizedBox(), controller: controller)],
          ),
        ),
      ),
    );
    await tester.pump();
    controller.reveal(200);
    await tester.pump();
    final rect = tester.getRect(_item(200));
    expect(rect.bottom, moreOrLessEquals(800, epsilon: .01));
    controller.reveal(_count);
    await tester.pump();
    expect(tester.getRect(_item(200)), rect);
    expect(tester.takeException(), isNull);
  });
}
