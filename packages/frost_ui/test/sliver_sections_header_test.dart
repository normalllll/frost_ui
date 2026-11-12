import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/primitives/_page_outline.dart';

import 'support.dart';

class _Page extends StatefulWidget {
  const _Page({this.stripes = false, this.solidLead = false});
  final bool stripes, solidLead;
  @override
  State<_Page> createState() => _PageState();
}

class _PageState extends State<_Page> with SingleTickerProviderStateMixin {
  late final _tabs = FrostTabController(length: 2, vsync: this);

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
          lead: SizedBox(key: const ValueKey('lead'), height: 300, child: widget.solidLead ? const ColoredBox(color: Color(0xFFFF0040)) : null),
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
      body: FrostTabView(
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

    await _drag(tester, 500);
    final tabs = tester.getRect(find.byType(FrostTabBar));
    expect(tabs.top, header.bottom - 12);
    expect(tester.getRect(find.byType(FrostPageHeader)), header);

    final surfaces = tester.widgetList<FrostSurface>(find.descendant(of: _glass, matching: find.byType(FrostSurface))).toList();
    expect(surfaces.where((surface) => surface.borderRadius == BorderRadius.zero), isEmpty, reason: "one band reaching the top corners");

    expect(tester.takeException(), isNull);
  });

  Future<void> outer(WidgetTester tester, double offset) async {
    tester.state<NestedScrollViewState>(find.byType(NestedScrollView)).outerController.jumpTo(offset);
    await tester.pump();
    await tester.pump();
  }

  Future<void> page(WidgetTester tester, {double scale = 1}) async {
    window(tester);
    await tester.pumpWidget(
      frostTestApp(
        Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
            child: const _Page(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  // Under a 300 lead the tabs stick at 312: the lead, then the 12 they tuck.
  testWidgets('no glass shows until the tabs near the header, then one glass fades in behind both', (tester) async {
    await page(tester);
    final (sections, chrome) = (0, 1);
    for (final offset in [0.0, 60.0, 288.0]) {
      await outer(tester, offset);
      expect(_glasses(tester)[sections].opacity, 0, reason: 'at $offset');
      expect(_glasses(tester)[chrome].opacity, 0, reason: 'at $offset');
    }
    await outer(tester, 300);
    expect(_glasses(tester)[sections].opacity, closeTo(.5, .001));
    expect(_glasses(tester)[chrome].opacity, 0);
    expect(tester.getRect(_glass.first).top, 0);
    expect(tester.getRect(_glass.first).bottom, tester.getRect(find.byType(FrostTabBar)).bottom);

    await outer(tester, 312);
    expect(_glasses(tester)[sections].opacity, 1);
    expect(tester.getRect(_glass.first).top, 0);
    expect(tester.getRect(_glass.first).bottom, tester.getRect(find.byType(FrostTabBar)).bottom);

    await outer(tester, 200);
    expect(_glasses(tester)[sections].opacity, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the lead fades under the header only once it has moved', (tester) async {
    await page(tester);
    expect(tester.layers.whereType<ShaderMaskLayer>(), isEmpty);
    await outer(tester, 60);
    expect(tester.layers.whereType<ShaderMaskLayer>(), hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the lead is solid below the header and gone 32 above its bottom edge', (tester) async {
    window(tester);
    final key = GlobalKey();
    await tester.pumpWidget(
      frostTestApp(
        brightness: Brightness.dark,
        RepaintBoundary(key: key, child: const _Page(solidLead: true)),
      ),
    );
    await tester.pumpAndSettle();
    await outer(tester, 60);
    final edge = tester.getRect(find.byType(FrostPageHeader)).bottom.round();
    final render = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = (await tester.runAsync(() => render.toImage()))!;
    final bytes = (await tester.runAsync(() => image.toByteData(format: ui.ImageByteFormat.rawRgba)))!;
    int red(int y) => bytes.getUint8((y * image.width + 900) * 4);
    final width = image.width;
    expect(width, 1147);
    image.dispose();
    expect(red(edge + 4), 255);
    expect(red(edge - 2), greaterThan(red(edge - 16)));
    expect(red(edge - 16), greaterThan(red(edge - 30)));
    expect((red(edge - 34) - red(edge - 46)).abs(), lessThanOrEqualTo(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the stuck bar is shorter than its two rows and the body follows it', (tester) async {
    await page(tester);
    final header = tester.getRect(find.byType(FrostPageHeader));
    final tabs = tester.getRect(find.byType(FrostTabBar));
    expect(tabs.top, header.bottom + 300);

    var last = tabs.top;
    await outer(tester, 290);
    last = tester.getTopLeft(find.byType(FrostTabBar)).dy;
    for (var offset = 291.0; offset <= 320; offset++) {
      await outer(tester, offset);
      final top = tester.getTopLeft(find.byType(FrostTabBar)).dy;
      expect((top - last).abs(), lessThanOrEqualTo(1 + 1e-6), reason: 'at $offset');
      last = top;
    }

    await outer(tester, 312);
    final stuck = tester.getRect(find.byType(FrostTabBar));
    expect(stuck.bottom - header.top, header.height + tabs.height - 12);
    expect(tester.getTopLeft(find.text('a0')).dy, stuck.bottom);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a stuck tab still takes taps', (tester) async {
    await page(tester);
    await outer(tester, 312);
    await tester.tap(find.text('Likes'));
    await tester.pumpAndSettle();
    expect(find.text('b0'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('large text keeps both rows whole', (tester) async {
    await page(tester, scale: 2);
    final header = tester.getRect(find.byType(FrostPageHeader));
    await outer(tester, 300);
    expect(tester.getTopLeft(find.byType(FrostTabBar)).dy, header.bottom);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a plain pinned chrome keeps its 24 reveal', (tester) async {
    window(tester);
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    await tester.pumpWidget(
      frostTestApp(
        FrostPinnedChrome(
          chrome: const FrostPageHeader(title: FrostText('Name')),
          body: ListView.builder(controller: scroll, itemCount: 100, itemBuilder: (_, i) => SizedBox(height: 50, child: Text('$i'))),
        ),
      ),
    );
    await tester.pumpAndSettle();
    scroll.jumpTo(12);
    await tester.pump();
    expect(_glasses(tester).single.opacity, .5);
    scroll.jumpTo(24);
    await tester.pump();
    expect(_glasses(tester).single.opacity, 1);
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
