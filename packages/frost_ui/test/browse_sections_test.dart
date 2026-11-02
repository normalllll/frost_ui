import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/media.dart';

import 'support.dart';

Finder get _header => find.byType(FrostPageHeader);
Finder get _glass => find.byType(FrostPinnedChromeGlass);
Finder _row(int section, int index) => find.text('S$section row $index', skipOffstage: false);
// Rows start on the page keyline of a 412-wide window.
const _inset = 16.0;
const _labels = ['New', 'Hot', 'Random', 'Top'];

void main() {
  late Set<int> built;
  late List<int> refreshed;
  setUp(() {
    built = {};
    refreshed = [];
  });

  void viewport(WidgetTester tester, double width) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, 800);
    addTearDown(tester.view.reset);
  }

  Widget page({TargetPlatform platform = TargetPlatform.android, bool reduceMotion = false, bool refresh = false, Widget? lead}) => frostTestApp(
    Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
        child: DefaultTabController(
          length: _labels.length,
          child: FrostBrowseLayout.sectioned(
            header: FrostPageHeader(
              leading: [
                FrostTitleMenu(
                  title: 'yande',
                  entries: [FrostMenuAction('konachan', onSelected: () {})],
                ),
              ],
              actions: [
                FrostToolbarItem.action(icon: testIcons.filter, label: 'Filter', onPressed: () {}),
                FrostToolbarItem.action(icon: testIcons.download, label: 'Batch', onPressed: () {}),
                FrostToolbarItem.action(icon: testIcons.more, label: 'More', onPressed: () {}),
              ],
            ),
            sections: FrostHeaderSections(
              tabs: FrostTabBar(scrollable: true, tabs: [for (final label in _labels) FrostTab(label: label)]),
            ),
            sectionBuilder: (context, section) {
              built.add(section);
              return FrostBrowseSection(
                onRefresh: refresh
                    ? () async {
                        refreshed.add(section);
                        return true;
                      }
                    : null,
                slivers: [
                  if (section == 0 && lead != null) SliverToBoxAdapter(child: lead),
                  SliverList.builder(itemCount: 80, itemBuilder: (_, i) => SizedBox(height: 40, child: Text('S$section row $i'))),
                ],
              );
            },
          ),
        ),
      ),
    ),
    platform: platform,
  );

  TabController tabs(WidgetTester tester) => DefaultTabController.of(tester.element(find.byType(FrostTabBar)));
  ScrollPosition section(WidgetTester tester, int index) => Scrollable.of(tester.element(_row(index, 0))).position;
  double indicator(WidgetTester tester) {
    final paint = tester.widget<CustomPaint>(find.descendant(of: find.byType(FrostTabBar), matching: find.byType(CustomPaint)).first);
    return ((paint.foregroundPainter! as dynamic).progress as Animation<double>).value;
  }

  double opacity(WidgetTester tester) => tester.widget<FrostPinnedChromeGlass>(_glass).opacity;

  testWidgets('a touch swipe pages to the next section with the tab indicator following the finger', (tester) async {
    viewport(tester, 412);
    await tester.pumpWidget(page());
    expect(built, {0});
    final controller = tabs(tester);
    final gesture = await tester.startGesture(const Offset(300, 500));
    for (var i = 0; i < 8; i++) {
      await gesture.moveBy(const Offset(-25, 0));
      await tester.pump();
    }
    // Part way: the next section is built beside this one and the indicator
    // sits between the two tabs.
    expect(controller.index, 0);
    expect(controller.animation!.value, inExclusiveRange(.2, .6));
    expect(indicator(tester), controller.animation!.value);
    expect(tester.getTopLeft(_row(1, 0)).dx, inExclusiveRange(_inset, 412));
    // Past half way it settles on the next section.
    for (var i = 0; i < 4; i++) {
      await gesture.moveBy(const Offset(-25, 0));
      await tester.pump();
    }
    await gesture.up();
    await tester.pumpAndSettle();
    expect(controller.index, 1);
    expect(indicator(tester), 1);
    expect(tester.getTopLeft(_row(1, 0)).dx, _inset);
    expect(built, {0, 1});

    // And back.
    await tester.fling(find.text('S1 row 3'), const Offset(300, 0), 1000);
    await tester.pumpAndSettle();
    expect(controller.index, 0);
    expect(tester.getTopLeft(_row(0, 0)).dx, _inset);
    expect(tester.takeException(), isNull);
  });

  testWidgets('each section keeps its scroll position and a far tab builds only its own section', (tester) async {
    viewport(tester, 412);
    await tester.pumpWidget(page());
    section(tester, 0).jumpTo(600);
    await tester.pump();

    await tester.tap(find.text('Hot'));
    await tester.pumpAndSettle();
    expect(tabs(tester).index, 1);
    expect(section(tester, 1).pixels, 0);
    section(tester, 1).jumpTo(300);
    await tester.pump();

    await tester.tap(find.text('New'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    expect(built, {0, 1});
    await tester.pumpAndSettle();
    expect(tabs(tester).index, 0);
    expect(section(tester, 0).pixels, 600);
    expect(tester.getTopLeft(find.text('S0 row 16')).dx, _inset);

    // Three tabs away: the slide passes no other section.
    await tester.tap(find.text('Top'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    expect(tester.getTopLeft(_row(0, 0)).dx, lessThan(_inset));
    expect(built, {0, 1, 3});
    await tester.pumpAndSettle();
    expect(built, {0, 1, 3});
    expect(tester.getTopLeft(_row(3, 0)).dx, _inset);

    // Back to the first section by a swipe from its neighbour.
    await tester.tap(find.text('Hot'));
    await tester.pumpAndSettle();
    expect(built, {0, 1, 3});
    expect(section(tester, 1).pixels, 300);
    await tester.fling(find.text('S1 row 10'), const Offset(300, 0), 1000);
    await tester.pumpAndSettle();
    expect(tabs(tester).index, 0);
    expect(section(tester, 0).pixels, 600);
    expect(section(tester, 1).pixels, 300);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the sliding header row and the glass follow the section on screen', (tester) async {
    viewport(tester, 412);
    await tester.pumpWidget(page());
    final header = tester.getRect(_header);
    expect(opacity(tester), 0);

    await tester.dragFrom(const Offset(200, 600), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(tester.getRect(_header).bottom, moreOrLessEquals(0, epsilon: .5));
    expect(opacity(tester), 1);

    // A section at its top cannot fill the row's place: the row comes back
    // and the glass clears.
    await tester.tap(find.text('Hot'));
    await tester.pumpAndSettle();
    expect(tester.getRect(_header).top, 0);
    expect(opacity(tester), 0);
    // Scrolling this section moves the bar; the scrolled one is off screen.
    section(tester, 1).jumpTo(12);
    await tester.pump();
    expect(opacity(tester), moreOrLessEquals(.5, epsilon: .01));

    // Back on the scrolled section the row keeps its place until scrolling
    // asks again, and the glass returns.
    await tester.tap(find.text('New'));
    await tester.pumpAndSettle();
    expect(tester.getRect(_header).top, 0);
    expect(opacity(tester), 1);
    await tester.dragFrom(const Offset(200, 600), const Offset(0, -100));
    await tester.pumpAndSettle();
    expect(tester.getRect(_header).top, -header.height);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an inner horizontal scroller takes the drag before the sections', (tester) async {
    viewport(tester, 412);
    final strip = ScrollController();
    addTearDown(strip.dispose);
    await tester.pumpWidget(
      page(
        lead: SizedBox(
          height: 120,
          child: ListView.builder(
            key: const ValueKey('strip'),
            controller: strip,
            scrollDirection: Axis.horizontal,
            itemCount: 20,
            itemBuilder: (_, i) => SizedBox(width: 100, child: Text('thumb $i')),
          ),
        ),
      ),
    );
    await tester.drag(find.byKey(const ValueKey('strip')), const Offset(-200, 0));
    await tester.pumpAndSettle();
    expect(strip.offset, greaterThan(100));
    expect(tabs(tester).index, 0);
    expect(tester.getTopLeft(_row(0, 0)).dx, _inset);
    // Below the strip the drag pages.
    await tester.drag(find.text('S0 row 6'), const Offset(-300, 0));
    await tester.pumpAndSettle();
    expect(tabs(tester).index, 1);
  });

  testWidgets('zoomed media in a section stops the sections paging', (tester) async {
    viewport(tester, 412);
    await tester.pumpWidget(
      page(
        lead: const SizedBox(
          height: 300,
          child: FrostMediaViewport(child: ColoredBox(color: Color(0xFF336699))),
        ),
      ),
    );
    final media = find.byType(FrostMediaViewport);
    await tester.fling(media, const Offset(-300, 0), 1500);
    await tester.pumpAndSettle();
    expect(tabs(tester).index, 1);
    await tester.fling(find.text('S1 row 3'), const Offset(300, 0), 1500);
    await tester.pumpAndSettle();
    expect(tabs(tester).index, 0);

    final center = tester.getCenter(media);
    await tester.tapAt(center);
    await tester.pump(const Duration(milliseconds: 60));
    await tester.tapAt(center);
    await tester.pumpAndSettle();
    final transform = tester.widget<InteractiveViewer>(find.byType(InteractiveViewer)).transformationController!;
    expect(transform.value.getMaxScaleOnAxis(), greaterThan(1));
    await tester.fling(media, const Offset(-300, 0), 1500);
    await tester.pumpAndSettle();
    expect(tabs(tester).index, 0);
    expect(tester.getTopLeft(_row(0, 0)).dx, _inset);
  });

  testWidgets('a mouse or a sideways wheel does not page; the tabs and their keys do', (tester) async {
    viewport(tester, 412);
    await tester.pumpWidget(page(platform: TargetPlatform.windows));
    await tester.dragFrom(const Offset(300, 500), const Offset(-300, 0), kind: PointerDeviceKind.mouse);
    await tester.pumpAndSettle();
    expect(tabs(tester).index, 0);
    expect(tester.getTopLeft(_row(0, 0)).dx, _inset);

    final pointer = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(pointer.hover(const Offset(200, 500)));
    await tester.sendEventToBinding(pointer.scroll(const Offset(200, 0)));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(_row(0, 0)).dx, _inset);

    await tester.tap(find.text('Hot'));
    await tester.pumpAndSettle();
    expect(tabs(tester).index, 1);
    expect(tester.getTopLeft(_row(1, 0)).dx, _inset);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(tabs(tester).index, 2);
    expect(tester.getTopLeft(_row(2, 0)).dx, _inset);
  });

  testWidgets('reduced motion jumps between sections', (tester) async {
    viewport(tester, 412);
    await tester.pumpWidget(page(reduceMotion: true));
    await tester.tap(find.text('Random'));
    await tester.pump();
    expect(tabs(tester).index, 2);
    expect(tester.getTopLeft(_row(2, 0)).dx, _inset);
    expect(built, {0, 2});
  });

  testWidgets('each section pulls to refresh on its own below both rows', (tester) async {
    viewport(tester, 412);
    await tester.pumpWidget(page(refresh: true));
    final tabRow = tester.getRect(find.byType(FrostTabBar));
    expect(tester.getTopLeft(_row(0, 0)).dy, tabRow.bottom);
    Future<void> pull() async {
      final gesture = await tester.startGesture(const Offset(200, 300));
      for (var i = 0; i < 10; i++) {
        await gesture.moveBy(const Offset(0, 20));
        await tester.pump();
      }
      await gesture.up();
      await tester.pumpAndSettle();
    }

    await pull();
    expect(refreshed, [0]);
    await tester.tap(find.text('Hot'));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(_row(1, 0)).dy, tabRow.bottom);
    await pull();
    expect(refreshed, [0, 1]);
    expect(tester.getTopLeft(_row(1, 0)).dy, tabRow.bottom);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the waterfall reveal controller works inside a section', (tester) async {
    viewport(tester, 412);
    final controller = FrostWaterfallController();
    final items = List.generate(300, (i) => i);
    await tester.pumpWidget(
      frostTestApp(
        DefaultTabController(
          length: 2,
          child: FrostBrowseLayout.sectioned(
            header: FrostPageHeader(
              leading: [
                FrostTitleMenu(
                  title: 'yande',
                  entries: [FrostMenuAction('konachan', onSelected: () {})],
                ),
              ],
            ),
            sections: const FrostHeaderSections(
              tabs: FrostTabBar(
                scrollable: true,
                tabs: [
                  FrostTab(label: 'New'),
                  FrostTab(label: 'Hot'),
                ],
              ),
            ),
            sectionBuilder: (context, section) => FrostBrowseSection(
              slivers: [
                FrostSliverWaterfallGrid<int>(
                  items: items,
                  controller: section == 1 ? controller : null,
                  itemBuilder: (context, item, index) => SizedBox(key: ValueKey('$section/$index'), height: 80 + (index * 37) % 170),
                ),
              ],
            ),
          ),
        ),
        platform: TargetPlatform.android,
      ),
    );
    await tester.tap(find.text('Hot'));
    await tester.pumpAndSettle();
    final chrome = tester.getRect(find.byType(FrostTabBar)).bottom;
    controller.reveal(200);
    await tester.pump();
    final rect = tester.getRect(find.byKey(const ValueKey('1/200')));
    expect(rect.bottom, moreOrLessEquals(800, epsilon: .01));
    controller.reveal(150);
    await tester.pump();
    expect(tester.getRect(find.byKey(const ValueKey('1/150'))).top, greaterThanOrEqualTo(chrome - .01));
    expect(tester.takeException(), isNull);
  });
}
