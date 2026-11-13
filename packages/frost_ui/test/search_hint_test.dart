import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:material_ui/material_ui.dart';

import 'support.dart';

void main() {
  const shortcut = FrostShortcut(LogicalKeyboardKey.keyK, primary: true);
  final submit = find.byWidgetPredicate((w) => w is FrostButton && w.label == 'L.search');
  final clear = find.byWidgetPredicate((w) => w is FrostButton && w.label == 'L.clearText');
  final action = find.byWidgetPredicate((w) => w is FrostButton && w.label == 'Filter');

  Future<(TextEditingController, FocusNode)> pump(
    WidgetTester tester, {
    String? hint,
    String text = '',
    double width = 400,
    bool caption = true,
    TargetPlatform platform = TargetPlatform.windows,
    TextDirection direction = TextDirection.ltr,
    List<Widget> actions = const [],
  }) async {
    final controller = TextEditingController(text: text);
    final focus = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focus.dispose);
    await tester.pumpWidget(
      frostTestApp(
        Directionality(
          textDirection: direction,
          child: Center(
            child: SizedBox(
              width: width,
              child: caption
                  ? FrostCaptionSearch(controller: controller, focusNode: focus, placeholder: 'Search', onSubmitted: (_) {}, hint: hint)
                  : FrostSearchInput(controller: controller, focusNode: focus, placeholder: 'Search', onSubmitted: (_) {}, hint: hint, actions: actions),
            ),
          ),
        ),
        platform: platform,
      ),
    );
    await tester.pumpAndSettle();
    return (controller, focus);
  }

  testWidgets('no hint shows by default and submit keeps its rule', (tester) async {
    final (controller, focus) = await pump(tester, text: 'muryo');
    expect(find.text('Ctrl K'), findsNothing);
    expect(submit, findsNothing, reason: 'a caption field at rest has no submit');
    focus.requestFocus();
    await tester.pumpAndSettle();
    expect(submit, findsOneWidget);
    controller.clear();
    focus.unfocus();
    await tester.pumpAndSettle();
    expect(find.text('Ctrl K'), findsNothing);
  });

  for (final label in ['Ctrl K', 'Press /']) {
    testWidgets('the hint $label shows only without focus', (tester) async {
      final (_, focus) = await pump(tester, hint: label);
      expect(find.text(label), findsOneWidget);
      focus.requestFocus();
      await tester.pumpAndSettle();
      expect(find.text(label), findsNothing);
      focus.unfocus();
      await tester.pumpAndSettle();
      expect(find.text(label), findsOneWidget);
    });
  }

  for (final (platform, label) in [(TargetPlatform.windows, 'Ctrl K'), (TargetPlatform.macOS, '\u2318K')]) {
    testWidgets('a shortcut reads $label as a hint on $platform', (tester) async {
      await tester.pumpWidget(frostTestApp(Builder(builder: (context) => Text(shortcut.hintLabel(context))), platform: platform));
      expect(find.text(label), findsOneWidget);
    });
  }

  testWidgets('a plain search input shows the hint too', (tester) async {
    await pump(tester, hint: 'Ctrl K', caption: false);
    expect(find.text('Ctrl K'), findsOneWidget);
  });

  for (final direction in TextDirection.values) {
    testWidgets('the hint comes before clear, the actions and submit in $direction', (tester) async {
      await pump(
        tester,
        hint: 'Ctrl K',
        text: 'muryo',
        caption: false,
        direction: direction,
        actions: [
          Builder(
            builder: (context) => FrostButton.icon(icon: FrostIconSet.of(context).search, label: 'Filter', size: FrostControlSize.compact, onPressed: () {}),
          ),
        ],
      );
      final order = [find.text('Ctrl K'), clear, action, submit].map((finder) => tester.getCenter(finder).dx).toList();
      expect(order, direction == TextDirection.ltr ? orderedEquals(order.toList()..sort()) : orderedEquals(order.toList()..sort((a, b) => b.compareTo(a))));
    });
  }

  testWidgets('narrowing drops the hint first and keeps the buttons', (tester) async {
    await pump(tester, hint: 'A rather long hint for this field', text: 'muryo', caption: false, width: 400);
    expect(tester.getSize(find.text('A rather long hint for this field')).width, greaterThan(0));
    await pump(tester, hint: 'A rather long hint for this field', text: 'muryo', caption: false, width: 200);
    await tester.pumpAndSettle();
    expect(find.text('A rather long hint for this field').hitTestable(), findsNothing);
    expect(clear.hitTestable(), findsOneWidget);
    expect(submit.hitTestable(), findsOneWidget);
  });
}
