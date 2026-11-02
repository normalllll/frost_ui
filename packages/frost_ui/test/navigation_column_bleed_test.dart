import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/display/_disclosure_body.dart';
import 'support.dart';

const _shot = ValueKey('shot');

Widget _app(Widget child, TextDirection direction) => frostTestApp(
  Directionality(
    textDirection: direction,
    child: RepaintBoundary(key: _shot, child: child),
  ),
);

Widget _layout(Widget sliver) => FrostNavigationColumnLayout(
  navigationBuilder: (_) => CustomScrollView(slivers: [FrostSliverContentColumn(sliver: sliver)]),
  content: const SizedBox(),
);

Widget _rows() => Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [
    FrostNavigationColumnRow(title: 'gitbound', selected: true, onPressed: () {}),
    FrostNavigationColumnRow(title: 'frost_ui', onPressed: () {}),
  ],
);

Widget _plain() => _layout(SliverToBoxAdapter(child: _rows()));

Widget _collapsible({bool expanded = true}) => _layout(
  SliverToBoxAdapter(
    child: FrostSectionHeader.collapsible(title: 'Group', expanded: expanded, onExpansionChanged: (_) {}, child: _rows()),
  ),
);

Finder _row(String title) => find.widgetWithText(FrostNavigationColumnRow, title);
Finder _fill(String title) => find.descendant(of: _row(title), matching: find.byType(DecoratedBox)).first;

void main() {
  void viewport(WidgetTester tester, [Size size = const Size(1200, 820)]) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  /// The pixel colour of the painted frame at [point], by 1x device pixel.
  Future<Color> paintedAt(WidgetTester tester, Offset point) async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(_shot));
    final image = (await tester.runAsync(boundary.toImage))!;
    final bytes = (await tester.runAsync(() => image.toByteData(format: ui.ImageByteFormat.rawRgba)))!;
    final offset = (point.dy.floor() * image.width + point.dx.floor()) * 4;
    return Color.fromARGB(bytes.getUint8(offset + 3), bytes.getUint8(offset), bytes.getUint8(offset + 1), bytes.getUint8(offset + 2));
  }

  for (final direction in TextDirection.values) {
    final rtl = direction == TextDirection.rtl;

    // How far the fill reaches past the row text line toward the column edge.
    double bleed(WidgetTester tester, String title) {
      final fill = tester.getRect(_fill(title)), text = tester.getRect(find.text(title));
      return rtl ? fill.right - text.right : text.left - fill.left;
    }

    // Whether the selected row's fill is actually painted at that distance.
    Future<bool> paintsFillAt(WidgetTester tester, double distance) async {
      final fill = tester.getRect(_fill('gitbound')), text = tester.getRect(find.text('gitbound'));
      final y = fill.center.dy;
      final inside = await paintedAt(tester, Offset(rtl ? fill.left + 3 : fill.right - 3, y));
      final probe = await paintedAt(tester, Offset(rtl ? text.right + distance : text.left - distance, y));
      return probe == inside;
    }

    testWidgets('a selected row directly in a sliver content column bleeds 14 points ($direction)', (tester) async {
      viewport(tester);
      await tester.pumpWidget(_app(_plain(), direction));
      await tester.pumpAndSettle();
      expect(bleed(tester, 'gitbound'), 14);
      expect(bleed(tester, 'frost_ui'), 14);
      expect(await paintsFillAt(tester, 7), isTrue);
    });

    testWidgets('rows inside a collapsible section header bleed the same 14 points ($direction)', (tester) async {
      viewport(tester);
      await tester.pumpWidget(_app(_collapsible(), direction));
      await tester.pumpAndSettle();
      expect(bleed(tester, 'gitbound'), 14);
      expect(bleed(tester, 'frost_ui'), 14);
      expect(await paintsFillAt(tester, 7), isTrue, reason: 'the disclosure body must not clip the bleed');
    });
  }

  testWidgets('a collapsing disclosure body is still clipped vertically', (tester) async {
    viewport(tester);
    var expanded = true;
    late StateSetter update;
    await tester.pumpWidget(
      _app(
        _layout(
          SliverToBoxAdapter(
            child: StatefulBuilder(
              builder: (context, setState) {
                update = setState;
                return FrostSectionHeader.collapsible(title: 'Group', expanded: expanded, onExpansionChanged: (_) {}, child: _rows());
              },
            ),
          ),
        ),
        TextDirection.ltr,
      ),
    );
    await tester.pumpAndSettle();
    final full = tester.getSize(find.byType(FrostDisclosureBody)).height;
    update(() => expanded = false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    final mid = tester.getSize(find.byType(FrostDisclosureBody)).height;
    expect(mid, lessThan(full), reason: 'mid-animation the body is shorter than expanded');
    expect(mid, greaterThan(0));
    final clip = tester.renderObject<RenderClipRect>(find.descendant(of: find.byType(FrostDisclosureBody), matching: find.byType(ClipRect)).first);
    final bounds = clip.describeApproximatePaintClip(clip.child!)!;
    expect(bounds.top, 0);
    expect(bounds.bottom, clip.size.height);
    expect(clip.size.height, lessThan(full));
    await tester.pumpAndSettle();
  });
}
