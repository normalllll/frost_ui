import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_data/frost_data.dart';
import 'package:frost_ui/frost_ui.dart';

import '../../frost_ui/test/support.dart';

class _Pages extends FrostListSource<int> {
  int initialCalls = 0, nextCalls = 0;
  @override
  Future<List<int>> initList() async {
    initialCalls++;
    return List.generate(60, (index) => index);
  }

  @override
  Future<List<int>> nextList() async {
    nextCalls++;
    return nextCalls == 1 ? List.generate(10, (index) => index + 60) : [];
  }
}

void main() {
  void size(WidgetTester tester, Size value) {
    tester.view.physicalSize = value;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Widget app(Widget child) => frostTestApp(Scaffold(body: child));

  for (final beside in [true, false]) {
    for (final auxiliary in [true, false]) {
      testWidgets('paged sliver remains lazy and loads next data: beside=$beside auxiliary=$auxiliary', (tester) async {
        size(tester, beside ? const Size(1600, 900) : const Size(900, 800));
        final source = _Pages();
        final controller = ScrollController();
        var builds = 0;
        final paged = FrostSliverDataList<int>(
          source: source,
          firstLoadSkeleton: const SizedBox(height: 120),
          itemExtent: 60,
          itemBuilder: (_, item, index) {
            builds++;
            return Text('Item $item');
          },
        );
        const other = SliverToBoxAdapter(child: SizedBox(height: 200));
        await tester.pumpWidget(
          app(FrostContentLayout(controller: controller, slivers: [auxiliary ? other : paged], auxiliarySlivers: [auxiliary ? paged : other])),
        );
        await tester.pumpAndSettle();
        expect(source.initialCalls, 1);
        expect(source.nextCalls, 0);
        expect(builds, lessThan(60));
        controller.jumpTo(controller.position.maxScrollExtent);
        await tester.pumpAndSettle();
        expect(source.nextCalls, greaterThanOrEqualTo(1));
        expect(source.items, contains(69));
        expect(source.lastError, isNull);
        expect(find.byType(Scrollable), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        source.dispose();
        controller.dispose();
      });
    }
  }
}
