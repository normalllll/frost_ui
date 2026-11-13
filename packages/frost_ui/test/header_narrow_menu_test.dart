import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/controls/_field_frame.dart';
import 'package:material_ui/material_ui.dart';

import 'support.dart';

void main() {
  Future<void> pump(WidgetTester tester, TargetPlatform platform, double width) async {
    tester.view.physicalSize = Size(width, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final controller = TextEditingController();
    final focus = FocusNode();
    final search = FrostPageHeaderSearchController();
    addTearDown(controller.dispose);
    addTearDown(focus.dispose);
    addTearDown(search.dispose);
    await tester.pumpWidget(
      frostTestApp(
        Align(
          alignment: Alignment.topCenter,
          child: FrostPageHeader(
            leading: [
              FrostTitleMenu(title: 'yande', entries: [FrostMenuAction('Danbooru', onSelected: () {})]),
            ],
            middle: FrostSearchInput(controller: controller, focusNode: focus, placeholder: 'Search', onSubmitted: (_) {}),
            searchController: search,
            actions: [
              FrostToolbarItem.action(icon: testIcons.filter, label: 'Filter', onPressed: () {}),
              FrostToolbarItem.action(icon: testIcons.more, label: 'Sort', onPressed: () {}),
            ],
          ),
        ),
        platform: platform,
      ),
    );
    await tester.pumpAndSettle();
  }

  double natural(WidgetTester tester) => tester.renderObject<RenderParagraph>(find.text('yande')).getMaxIntrinsicWidth(double.infinity);

  for (final platform in [TargetPlatform.windows, TargetPlatform.android]) {
    for (final width in [280.0, 320.0]) {
      testWidgets('a menu at $width still names its value and keeps both actions on $platform', (tester) async {
        await pump(tester, platform, width);
        expect(tester.getSize(find.text('yande')).width, greaterThanOrEqualTo(40));
        expect(findFrostTooltip('Filter').hitTestable(), findsOneWidget);
        expect(findFrostTooltip('Sort').hitTestable(), findsOneWidget);
        expect(tester.getSize(find.byType(FrostTextField)).width, greaterThanOrEqualTo(80));
        expect(tester.takeException(), isNull);
      });
    }

    for (final width in [360.0, 390.0, 500.0]) {
      testWidgets('a menu at $width shows its whole value on $platform', (tester) async {
        await pump(tester, platform, width);
        expect(tester.getSize(find.text('yande')).width, moreOrLessEquals(natural(tester), epsilon: .01));
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('the menu plate and the painted field share top and bottom on $platform', (tester) async {
      await pump(tester, platform, 390);
      final field = tester.getRect(find.byType(FrostFieldPaint));
      expect(tester.getCenter(find.text('yande')).dy, closeTo(field.center.dy, .5));
      expect(field.height, FrostControlSize.compact.visualHeight(touch: platform == TargetPlatform.android));
    });
  }

  testWidgets('the field moves continuously to the bleed line and back to rest', (tester) async {
    await pump(tester, TargetPlatform.android, 390);
    final field = find.byType(FrostTextField);
    final rest = tester.getRect(field);
    await tester.tap(field);
    var left = rest.left;
    for (var frame = 0; frame < 40; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
      final next = tester.getRect(field).left;
      expect(next, lessThanOrEqualTo(left + .01));
      expect(left - next, lessThan(rest.left), reason: 'frame $frame');
      left = next;
    }
    await tester.pumpAndSettle();
    expect(tester.getRect(field).left, FrostGap.hitInset);
    await tester.tap(find.text('L.cancel'));
    await tester.pumpAndSettle();
    expect(tester.getRect(field), rest);
  });
}
