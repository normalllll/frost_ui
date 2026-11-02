import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'support.dart';

void main() {
  // A toolbar's middle stops at 360; only a header in search mode reaches 640.
  for (final direction in TextDirection.values) {
    testWidgets('middle grows continuously after leading without squeezing actions direction=$direction', (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final width = ValueNotifier(744.0);
      addTearDown(width.dispose);
      final controller = TextEditingController(text: 'retained query');
      final focus = FocusNode();
      addTearDown(controller.dispose);
      addTearDown(focus.dispose);
      final search = FrostPageHeaderSearchController();
      addTearDown(search.dispose);
      final source = GlobalKey(), middle = GlobalKey();
      final actions = [GlobalKey(), GlobalKey()];
      Widget row() {
        final leading = [SizedBox(key: source, width: 140, height: 32)];
        final field = SizedBox(
          key: middle,
          child: FrostSearchInput(controller: controller, focusNode: focus, placeholder: 'Search', onSubmitted: (_) {}),
        );
        final trailing = [
          for (final key in actions)
            FrostToolbarItem.custom(
              minWidth: 80,
              priority: FrostToolbarPriority.high,
              builder: (_) => SizedBox(key: key, width: 80, height: 32),
              overflowEntry: FrostMenuAction('Action', onSelected: () {}),
            ),
        ];
        return FrostPageHeader(leading: leading, middle: field, searchController: search, actions: trailing);
      }

      tester.view.physicalSize = const Size(1024, 900);
      await tester.pumpWidget(
        frostTestApp(
          Directionality(
            textDirection: direction,
            child: Center(
              child: ValueListenableBuilder(
                valueListenable: width,
                builder: (_, value, _) => SizedBox(width: value, child: row()),
              ),
            ),
          ),
          density: FrostDensity.compact,
        ),
      );
      final initialState = tester.state(find.byType(EditableText));
      // A header row narrower than the expanded search width covers itself
      // with a focused field; its resting middle slot is measured unfocused.
      await tester.pump();
      controller.selection = const TextSelection.collapsed(offset: 5);
      await tester.pump();
      double? previous;
      for (final viewport in [1024.0, 1025.0, 1440.0, 1920.0, 1024.0]) {
        tester.view.physicalSize = Size(viewport, 900);
        width.value = viewport - 280;
        await tester.pump();
        final sourceRect = tester.getRect(find.byKey(source));
        final middleRect = tester.getRect(find.byKey(middle));
        expect(middleRect.width, inInclusiveRange(360, 640));
        if (viewport >= 1440) expect(middleRect.width, 640);
        if (viewport == 1025) expect(middleRect.width, closeTo(previous! + 1, .001));
        final gap = direction == TextDirection.ltr ? middleRect.left - sourceRect.right : sourceRect.left - middleRect.right;
        expect(gap, FrostGap.related);
        for (final action in actions) {
          final rect = tester.getRect(find.byKey(action));
          expect(rect.width, 80);
          expect(direction == TextDirection.ltr ? rect.left >= middleRect.right : rect.right <= middleRect.left, isTrue);
        }
        expect(tester.state(find.byType(EditableText)), same(initialState));
        expect(controller.text, 'retained query');
        expect(controller.selection.extentOffset, 5);
        expect(focus.hasFocus, isFalse);
        expect(tester.takeException(), isNull);
        previous = middleRect.width;
      }
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets('the middle stops at 360 unless the header is in search mode', (tester) async {
    final key = GlobalKey();
    final search = FrostPageHeaderSearchController();
    addTearDown(search.dispose);
    for (final (width, build) in <(double, Widget Function())>[
      (360, () => FrostToolbar(middle: SizedBox(key: key, height: 32))),
      (360, () => FrostPageHeader(middle: SizedBox(key: key, height: 32))),
      (
        640,
        () => FrostPageHeader(
          searchController: search,
          middle: SizedBox(key: key, height: 32),
        ),
      ),
    ]) {
      await tester.pumpWidget(frostTestApp(Center(child: SizedBox(width: 700, child: build()))));
      expect(tester.getSize(find.byKey(key)).width, width);
    }
  });
}
