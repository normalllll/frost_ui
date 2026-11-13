import 'package:flutter_test/flutter_test.dart';
import 'package:frost_data/frost_data.dart';
import 'package:material_ui/material_ui.dart';

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

  testWidgets('paged sliver remains lazy and loads next data', (tester) async {
    size(tester, const Size(900, 800));
    final source = _Pages();
    final controller = ScrollController();
    var builds = 0;
    final paged = FrostSliverDataList<int>(
      source: source,
      firstLoadSkeleton: const SizedBox(height: 120),
      itemExtent: 60,
      itemBuilder: (_, item, index) {
        builds++;
        return Text('Item ');
      },
    );
    await tester.pumpWidget(app(CustomScrollView(controller: controller, slivers: [paged])));
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
