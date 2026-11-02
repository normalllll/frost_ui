import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'support.dart';

/// A column that counts how often its State is created and keeps its own
/// scroll controller.
class _Column extends StatefulWidget {
  const _Column({required this.created, required this.controller});
  final List<State> created;
  final ScrollController controller;
  @override
  State<_Column> createState() => _ColumnState();
}

class _ColumnState extends State<_Column> {
  @override
  void initState() {
    super.initState();
    widget.created.add(this);
  }

  @override
  Widget build(BuildContext context) => ListView.builder(
    controller: widget.controller,
    itemCount: 80,
    itemBuilder: (_, index) => SizedBox(height: 40, child: Text('Repository $index')),
  );
}

void main() {
  splitStateTests();
  late ScrollController controller;
  setUp(() => controller = ScrollController());
  tearDown(() => controller.dispose());

  for (final open in [false, true]) {
    testWidgets('the column keeps its State and scroll offset across wide, narrow and wide (open page=$open)', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final created = <State>[];
      await tester.pumpWidget(
        frostTestApp(
          FrostNavigationColumnLayout(
            header: const FrostPageHeader(title: Text('Repositories')),
            navigationBuilder: (_) => _Column(created: created, controller: controller),
            content: const Text('Wide detail'),
            compactPage: open ? FrostNavigationColumnPage(onClose: () {}, child: const Text('Detail page')) : null,
          ),
        ),
      );
      await tester.pumpAndSettle();
      controller.jumpTo(600);
      await tester.pump();
      expect(created, hasLength(1));

      tester.view.physicalSize = const Size(560, 800);
      await tester.pumpAndSettle();
      expect(find.text('Detail page'), open ? findsOneWidget : findsNothing);
      expect(created, hasLength(1), reason: 'narrowing keeps the column');

      tester.view.physicalSize = const Size(1280, 800);
      await tester.pumpAndSettle();
      expect(find.text('Detail page'), findsNothing);
      expect(created, hasLength(1), reason: 'widening keeps the column');
      expect(identical(tester.state(find.byType(_Column)), created.single), isTrue);
      expect(controller.offset, 600);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('while the narrow page shows, the hidden column takes no focus or semantics', (tester) async {
    tester.view.physicalSize = const Size(560, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      frostTestApp(
        FrostNavigationColumnLayout(
          navigationBuilder: (_) => ListView(
            children: [FrostNavigationColumnRow(title: 'gitbound', onPressed: () {})],
          ),
          content: const Text('Wide detail'),
          compactPage: FrostNavigationColumnPage(onClose: () {}, child: const Text('Detail page')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Detail page'), findsOneWidget);
    expect(find.bySemanticsLabel('gitbound'), findsNothing);
    expect(find.text('gitbound', skipOffstage: false), findsOneWidget);
    expect(find.text('gitbound'), findsNothing, reason: 'offstage');
    semantics.dispose();
  });
}

class _SplitColumn extends StatelessWidget {
  const _SplitColumn({required this.controller, required this.seen});
  final ScrollController controller;
  final List<bool> seen;
  @override
  Widget build(BuildContext context) {
    final wide = FrostNavigationColumnLayout.isWideOf(context);
    seen.add(wide);
    return ListView.builder(
      controller: controller,
      itemCount: 80,
      itemBuilder: (_, index) => SizedBox(height: 40, child: Text(wide ? 'Wide $index' : 'Narrow $index')),
    );
  }
}

void splitStateTests() {
  late ScrollController controller;
  setUp(() => controller = ScrollController());
  tearDown(() => controller.dispose());

  Widget layout(List<bool> seen) => frostTestApp(
    FrostNavigationColumnLayout(
      header: const FrostPageHeader(title: Text('Repositories')),
      navigationBuilder: (_) => _SplitColumn(controller: controller, seen: seen),
      content: Builder(builder: (context) => Text(FrostNavigationColumnLayout.isWideOf(context) ? 'Content wide' : 'Content narrow')),
    ),
  );

  testWidgets('the same navigationBuilder reads wide at 1200 and narrow at 560', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    for (final (width, wide) in [(1200.0, true), (560.0, false)]) {
      tester.view.physicalSize = Size(width, 800);
      final seen = <bool>[];
      await tester.pumpWidget(layout(seen));
      await tester.pumpAndSettle();
      expect(seen.last, wide, reason: '$width');
      expect(find.text(wide ? 'Wide 0' : 'Narrow 0'), findsOneWidget);
      expect(find.text(wide ? 'Content wide' : 'Content narrow', skipOffstage: false), wide ? findsOneWidget : findsNothing);
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('crossing the threshold flips the value for the column and the content, and the scroll offset survives', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final seen = <bool>[];
    await tester.pumpWidget(layout(seen));
    await tester.pumpAndSettle();
    expect(find.text('Wide 0'), findsOneWidget);
    expect(find.text('Content wide'), findsOneWidget);
    controller.jumpTo(600);
    await tester.pump();

    tester.view.physicalSize = const Size(560, 800);
    await tester.pumpAndSettle();
    expect(seen.last, isFalse);
    expect(find.text('Narrow 15'), findsOneWidget);
    expect(find.text('Content narrow', skipOffstage: false), findsOneWidget);
    expect(controller.offset, 600);

    tester.view.physicalSize = const Size(1200, 800);
    await tester.pumpAndSettle();
    expect(seen.last, isTrue);
    expect(find.text('Wide 15'), findsOneWidget);
    expect(find.text('Content wide'), findsOneWidget);
    expect(controller.offset, 600);
    expect(tester.takeException(), isNull);
  });

  testWidgets('isWideOf asserts with no layout above', (tester) async {
    await tester.pumpWidget(Builder(builder: (context) => Text('${FrostNavigationColumnLayout.isWideOf(context)}', textDirection: TextDirection.ltr)));
    expect(tester.takeException(), isAssertionError);
  });
}
