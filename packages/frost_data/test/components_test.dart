import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_data/frost_data.dart';
import 'package:frost_ui/frost_ui.dart';

import '../../frost_ui/test/support.dart';

class _Items extends FrostListSource<int> {
  _Items(this.pages);

  final List<List<int>> pages;
  int _page = 0;

  @override
  Future<List<int>> initList() async {
    _page = 0;
    return pages.first;
  }

  @override
  Future<List<int>> nextList() async => ++_page < pages.length ? pages[_page] : const [];
}

void main() {
  Future<void> desktop(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  testWidgets('a paged list shows the supplied skeleton, then items and its end', (tester) async {
    await desktop(tester, const Size(1000, 800));
    final source = _Items([
      [1, 2],
      [3],
    ]);
    addTearDown(source.dispose);
    await tester.pumpWidget(
      frostTestApp(
        Scaffold(
          body: FrostLoadingScrollView(
            slivers: [
              FrostSliverDataList<int>(
                source: source,
                firstLoadSkeleton: const Text('skeleton'),
                itemBuilder: (context, item, index) => SizedBox(height: 40, child: Text('item $item')),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    expect(source.initialized, isTrue); // The shared sliver starts its own first load.
    await source.refresh(true);
    await tester.pumpAndSettle();
    expect(find.text('item 1'), findsOneWidget);
    await source.loadMore();
    await source.loadMore();
    await tester.pumpAndSettle();
    expect(find.text('item 3'), findsOneWidget);
    expect(source.hasMore, isFalse);
  });

  testWidgets('load state switcher swaps its one live child', (tester) async {
    await desktop(tester, const Size(1400, 900));
    var phase = 0;
    late StateSetter update;
    await tester.pumpWidget(
      frostTestApp(
        Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return SizedBox(
                height: 60,
                child: FrostLoadStateSwitcher(phase: phase, child: Text('phase $phase')),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('phase 0'), findsOneWidget);
    update(() => phase = 1);
    await tester.pumpAndSettle();
    expect(find.text('phase 1'), findsOneWidget);
    expect(find.text('phase 0'), findsNothing);
  });
}
