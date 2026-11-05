import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';

import 'page_support.dart';
import 'support.dart';

void _window(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  group('tab bar', () {
    Widget bar(double width, {bool scrollable = false, List<FrostTab>? tabs}) => frostTestApp(
      Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: width,
          child: DefaultTabController(
            length: tabs?.length ?? 3,
            child: FrostTabBar(
              scrollable: scrollable,
              tabs: tabs ?? const [FrostTab(label: 'A'), FrostTab(label: 'Bbbb'), FrostTab(label: 'Mid')],
            ),
          ),
        ),
      ),
    );
    final labels = find.byWidgetPredicate((w) => w.runtimeType.toString() == '_TabLabel');
    List<double> widths(WidgetTester tester) => [for (final element in labels.evaluate()) tester.getSize(find.byWidget(element.widget)).width];

    for (final width in [300.0, 600.0]) {
      testWidgets('shares its own width $width in a wide window', (tester) async {
        _window(tester, const Size(1100, 800));
        await tester.pumpWidget(bar(width));
        expect(widths(tester), everyElement(width / 3));
      });
    }

    testWidgets('scrollable takes natural widths in the same window', (tester) async {
      _window(tester, const Size(1100, 800));
      await tester.pumpWidget(bar(600, scrollable: true));
      final natural = widths(tester);
      expect(natural.first, lessThan(natural[1]));
      expect(natural.fold(0.0, (a, b) => a + b), lessThan(600));
    });

    testWidgets('falls back to natural widths and scrolls when a tab does not fit its share', (tester) async {
      _window(tester, const Size(1100, 800));
      await tester.pumpWidget(
        bar(
          200,
          tabs: const [
            FrostTab(label: 'A'),
            FrostTab(label: 'A rather long tab label'),
            FrostTab(label: 'B'),
          ],
        ),
      );
      expect(widths(tester).fold(0.0, (a, b) => a + b), greaterThan(200));
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('a table in a narrow panel of a wide window is a list', (tester) async {
    _window(tester, const Size(1400, 900));
    Widget table(double width) => frostTestApp(
      Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: width,
          height: 400,
          child: FrostTable<int>(
            columns: [
              FrostTableColumn<int>(label: 'Name', primary: true, text: (i) => 'Row $i', cell: (_, i) => Text('Row $i')),
              FrostTableColumn<int>(label: 'Size', text: (i) => '${i * 2}', cell: (_, i) => Text('${i * 2}')),
            ],
            rows: const [1, 2],
          ),
        ),
      ),
    );
    await tester.pumpWidget(table(300));
    expect(find.text('Size'), findsNothing);
    await tester.pumpWidget(table(800));
    expect(find.text('Size'), findsOneWidget);
  });

  group('split view', () {
    const primary = ValueKey('primary'), secondary = ValueKey('secondary');
    Widget split(double width, {double initial = 320}) => frostTestApp(
      Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: width,
          height: 500,
          child: FrostSplitView(
            initialPrimaryWidth: initial,
            primary: const SizedBox.expand(key: primary),
            secondary: const SizedBox.expand(key: secondary),
            onCloseSecondary: () {},
          ),
        ),
      ),
    );

    testWidgets('a narrow panel in a wide window shows one page', (tester) async {
      _window(tester, const Size(1400, 900));
      await tester.pumpWidget(split(320));
      await tester.pump();
      expect(find.byKey(primary), findsNothing, reason: 'detail covers the primary page');
      expect(tester.getSize(find.byKey(secondary)).width, 320);
      await tester.pumpWidget(split(800));
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byKey(primary)).width, 320);
    });

    testWidgets('one keyboard step moves the visible width when the request is larger', (tester) async {
      _window(tester, const Size(1400, 900));
      await tester.pumpWidget(split(600, initial: 480));
      await tester.pump();
      final visible = tester.getSize(find.byKey(primary)).width;
      expect(visible, lessThan(480));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byKey(primary)).width, visible - 16);
    });
  });

  testWidgets('confirm, sheet and adaptive dialog pick the same presentation in a narrow region', (tester) async {
    _window(tester, const Size(1200, 800));
    late BuildContext source;
    await tester.pumpWidget(
      frostTestApp(
        Row(
          children: [
            const SizedBox(width: 780),
            SizedBox(
              width: 420,
              child: TestOverlayRegion(
                child: Builder(
                  builder: (context) {
                    source = context;
                    return const SizedBox.expand();
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
    await tester.pump();
    showFrostConfirm(context: source, title: 'Sure?', confirmLabel: 'Yes');
    await tester.pumpAndSettle();
    expect(find.byType(FrostAlert), findsNothing);
    expect(find.text('Sure?'), findsOneWidget);
  });

  group('content width by page type', () {
    const header = ValueKey('header'), body = ValueKey('body');
    testWidgets('a pinned page fills a very wide window', (tester) async {
      _window(tester, const Size(2560, 900));
      await tester.pumpWidget(
        frostTestApp(
          pinnedPage(
            header: const SizedBox(key: header, height: 40, width: double.infinity),
            slivers: const [SliverToBoxAdapter(child: SizedBox(key: body, height: 40))],
          ),
        ),
      );
      expect(tester.getRect(find.byKey(header)), const Rect.fromLTWH(24, 0, 2512, 40));
      expect(tester.getSize(find.byKey(body)).width, 2512);
    });

    testWidgets('a form column is width-limited and centred', (tester) async {
      _window(tester, const Size(2560, 900));
      await tester.pumpWidget(
        frostTestApp(
          const FrostContentColumn(
            child: SizedBox(key: body, height: 40, width: double.infinity),
          ),
        ),
      );
      final rect = tester.getRect(find.byKey(body));
      expect(rect.width, FrostMetrics.contentMaxWidth - 48);
      expect(rect.center.dx, 1280);
    });

    testWidgets('settings panes are width-limited and centred', (tester) async {
      _window(tester, const Size(2560, 900));
      await tester.pumpWidget(
        frostTestApp(
          FrostSettingsSections(
            labels: const ['Appearance'],
            selectedIndex: 0,
            onSelected: (_) {},
            sectionBuilder: (_, _) => const SizedBox(key: body),
          ),
        ),
      );
      final divider = tester.getRect(find.byType(FrostDivider));
      expect(divider.left, greaterThan((2560 - FrostMetrics.settingsMaxWidth) / 2));
      expect(tester.getTopLeft(find.bySubtype<ListView>().first).dx, (2560 - FrostMetrics.settingsMaxWidth) / 2);
    });

    testWidgets('a reading page uses the reading width', (tester) async {
      _window(tester, const Size(1400, 900));
      await tester.pumpWidget(
        frostTestApp(
          const FrostContentColumn(
            maxWidth: FrostMetrics.readingMaxWidth,
            child: SizedBox(key: body, height: 40, width: double.infinity),
          ),
        ),
      );
      final rect = tester.getRect(find.byKey(body));
      expect(rect.width, FrostMetrics.readingMaxWidth - 48);
      expect(rect.center.dx, 700);
    });
  });

  testWidgets('gaps inside a narrow region use the narrow scale', (tester) async {
    _window(tester, const Size(1400, 900));
    late double section;
    await tester.pumpWidget(
      frostTestApp(
        Builder(
          builder: (context) => FrostLayoutScope(
            child: MediaQuery(
              data: MediaQuery.of(context).copyWith(size: const Size(320, 900)),
              child: Builder(
                builder: (context) {
                  section = FrostGap.of(context).section;
                  return const SizedBox();
                },
              ),
            ),
          ),
        ),
      ),
    );
    expect(section, FrostGap.section);
  });
}
