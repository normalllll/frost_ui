import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/controls/_button_control.dart';

import 'support.dart';

Finder _control(String label) => find.byWidgetPredicate((w) => w is FrostButtonControl && w.label == label).hitTestable();

void main() {
  late TextEditingController controller;
  late FocusNode focus;
  setUp(() {
    controller = TextEditingController();
    focus = FocusNode();
  });
  tearDown(() {
    controller.dispose();
    focus.dispose();
  });

  Widget header() => Align(
    alignment: Alignment.topCenter,
    child: FrostPageHeader(
      leading: [
        FrostTitleMenu(
          title: 'S',
          entries: [FrostMenuAction('Other', onSelected: () {})],
        ),
      ],
      middle: FrostSearchInput(controller: controller, focusNode: focus, placeholder: 'Find', leadingIcon: true, onSubmitted: (_) {}),
      actions: [
        FrostToolbarItem.action(icon: testIcons.filter, label: 'Filter', priority: FrostToolbarPriority.high, onPressed: () {}),
        FrostToolbarItem.menu(
          label: 'Options',
          icon: testIcons.more,
          showsLabel: false,
          entries: [FrostMenuAction('Copy', onSelected: () {})],
        ),
      ],
    ),
  );

  void viewport(WidgetTester tester, double width) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, 400);
    addTearDown(tester.view.reset);
  }

  testWidgets('a resting field has no submit button; focus or a query brings it back', (tester) async {
    viewport(tester, 412);
    // Standalone, so focusing does not also cover a narrow header row.
    await tester.pumpWidget(
      frostTestApp(
        Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: 240,
            child: FrostSearchInput(controller: controller, focusNode: focus, placeholder: 'Find', leadingIcon: true, onSubmitted: (_) {}),
          ),
        ),
        platform: TargetPlatform.android,
      ),
    );
    final rest = tester.getRect(find.byType(EditableText));
    expect(_control('L.search'), findsNothing, reason: 'an empty, unfocused field has nothing to submit');

    focus.requestFocus();
    await tester.pumpAndSettle();
    expect(find.byWidgetPredicate((w) => w is FrostButtonControl && w.label == 'L.search'), findsOneWidget);

    focus.unfocus();
    controller.text = 'cat';
    await tester.pumpAndSettle();
    expect(_control('L.search'), findsOneWidget, reason: 'a query can be submitted without focus');

    controller.clear();
    await tester.pumpAndSettle();
    expect(_control('L.search'), findsNothing);
    // The editable text gets the room the button took.
    expect(tester.getRect(find.byType(EditableText)), rest);
    expect(tester.takeException(), isNull);
  });

  for (final width in [360.0, 412.0]) {
    testWidgets('the middle keeps the plain gap to a trailing icon cluster at $width', (tester) async {
      viewport(tester, width);
      await tester.pumpWidget(frostTestApp(header(), platform: TargetPlatform.android));
      final field = tester.getRect(find.byType(FrostSearchInput));
      final menu = tester.getRect(_control('S'));
      final filter = tester.getRect(_control('Filter'));
      expect(field.left - menu.right, FrostGap.related);
      expect(filter.left - field.right, FrostGap.related, reason: 'no keyline shift is left between the field and the cluster');
      final scroll = tester.state<ScrollableState>(find.descendant(of: find.byType(FrostPageHeader), matching: find.byType(Scrollable)).first);
      expect(scroll.position.maxScrollExtent, 0, reason: 'the cluster may use the end room it shifts into');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('a middle at its maximum leaves the spare room before the cluster', (tester) async {
    viewport(tester, 900);
    await tester.pumpWidget(frostTestApp(header(), platform: TargetPlatform.android));
    final field = tester.getRect(find.byType(FrostSearchInput));
    expect(field.width, 360);
    expect(tester.getRect(_control('Filter')).left - field.right, greaterThan(FrostGap.related));
    expect(tester.takeException(), isNull);
  });
}
