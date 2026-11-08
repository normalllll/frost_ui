import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/primitives/_page_outline.dart';

import 'support.dart';

class _Page extends StatefulWidget {
  const _Page({this.stripes = false});
  final bool stripes;
  @override
  State<_Page> createState() => _PageState();
}

class _PageState extends State<_Page> with SingleTickerProviderStateMixin {
  late final _tabs = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FrostPinnedChrome(
    chrome: const FrostPageHeader(title: FrostText('Name')),
    body: NestedScrollView(
      headerSliverBuilder: (context, _) => [
        FrostSliverSectionsHeader(
          lead: const SizedBox(key: ValueKey('lead'), height: 300),
          tabs: FrostTabBar(
            controller: _tabs,
            scrollable: true,
            tabs: const [
              FrostTab(label: 'Posts'),
              FrostTab(label: 'Likes'),
            ],
          ),
        ),
      ],
      body: TabBarView(
        controller: _tabs,
        children: [
          for (final section in ['a', 'b'])
            Builder(
              builder: (context) => CustomScrollView(
                key: PageStorageKey(section),
                primary: true,
                slivers: [
                  SliverOverlapInjector(handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context)),
                  SliverList.builder(
                    itemCount: 100,
                    itemBuilder: (_, i) => SizedBox(
                      height: 50,
                      child: widget.stripes ? ColoredBox(color: i.isEven ? const Color(0xFFFF0040) : const Color(0xFF00FF80)) : Text('$section$i'),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}

Finder get _glass => find.byType(FrostPinnedChromeGlass);
List<FrostPinnedChromeGlass> _glasses(WidgetTester tester) => tester.widgetList<FrostPinnedChromeGlass>(_glass).toList();

Future<void> _drag(WidgetTester tester, double by) async {
  await tester.dragFrom(const Offset(400, 600), Offset(0, -by));
  await tester.pumpAndSettle();
}

void main() {
  void window(WidgetTester tester) {
    tester.view.physicalSize = const Size(1147, 717);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  testWidgets('the lead scrolls away and the tabs stick under the header as one bar', (tester) async {
    window(tester);
    await tester.pumpWidget(frostTestApp(const FrostPageOutline(radius: BorderRadius.all(Radius.circular(12)), child: _Page())));
    await tester.pumpAndSettle();
    final header = tester.getRect(find.byType(FrostPageHeader));
    expect(tester.getTopLeft(find.byKey(const ValueKey('lead'))).dy, header.bottom);
    expect(tester.getTopLeft(find.byType(FrostTabBar)).dy, header.bottom + 300);
    expect(_glasses(tester).map((glass) => glass.corners), containsAll([FrostPinnedChromeCorners.all, FrostPinnedChromeCorners.bottom]));

    await _drag(tester, 500);
    final tabs = tester.getRect(find.byType(FrostTabBar));
    expect(tabs.top, header.bottom);
    expect(tester.getRect(find.byType(FrostPageHeader)), header);
    final corners = _glasses(tester).map((glass) => glass.corners);
    expect(corners, containsAll([FrostPinnedChromeCorners.top, FrostPinnedChromeCorners.bottom]));
    expect(corners, isNot(contains(FrostPinnedChromeCorners.all)));

    final surfaces = tester.widgetList<FrostSurface>(find.descendant(of: _glass, matching: find.byType(FrostSurface))).toList();
    expect(surfaces.where((surface) => surface.borderRadius == BorderRadius.zero), isEmpty, reason: "one band reaching the top corners");

    await tester.drag(find.text('a15'), const Offset(0, 900));
    await tester.pumpAndSettle();
    expect(_glasses(tester).map((glass) => glass.corners), contains(FrostPinnedChromeCorners.all));
    expect(tester.takeException(), isNull);
  });

  testWidgets('each section keeps its own position when the selection changes', (tester) async {
    window(tester);
    await tester.pumpWidget(frostTestApp(const _Page()));
    await tester.pumpAndSettle();
    await _drag(tester, 300 + 400);
    final before = tester.getTopLeft(find.text('a12')).dy;

    await tester.tap(find.text('Likes'));
    await tester.pumpAndSettle();
    await _drag(tester, 250);
    final other = tester.getTopLeft(find.text('b8')).dy;

    await tester.tap(find.text('Posts'));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('a12')).dy, before);

    await tester.tap(find.text('Likes'));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('b8')).dy, other);
    expect(tester.takeException(), isNull);
  });

  testWidgets('saturated content under the stuck bars shows no step at their seam', (tester) async {
    window(tester);
    final key = GlobalKey();
    await tester.pumpWidget(
      frostTestApp(
        brightness: Brightness.dark,
        RepaintBoundary(key: key, child: const _Page(stripes: true)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.dragFrom(const Offset(600, 650), const Offset(0, -520));
    await tester.pumpAndSettle();
    final seam = tester.getRect(find.byType(FrostPageHeader)).bottom.round();
    final bottom = tester.getRect(find.byType(FrostTabBar)).bottom.round();

    final render = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = (await tester.runAsync(() => render.toImage()))!;
    final bytes = (await tester.runAsync(() => image.toByteData(format: ui.ImageByteFormat.rawRgba)))!;
    int step(int x, int y) {
      var largest = 0;
      for (var channel = 0; channel < 3; channel++) {
        final a = bytes.getUint8((y * image.width + x) * 4 + channel), b = bytes.getUint8(((y + 1) * image.width + x) * 4 + channel);
        if ((a - b).abs() > largest) largest = (a - b).abs();
      }
      return largest;
    }

    const x = 900;
    var inside = 0;
    for (var y = seam - 8; y < bottom - 2; y++) {
      if (y == seam - 1) continue;
      if (step(x, y) > inside) inside = step(x, y);
    }
    image.dispose();
    expect(step(x, seam - 1), lessThanOrEqualTo(inside + 2));
    expect(tester.takeException(), isNull);
  });
}
