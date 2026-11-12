import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/media.dart';

import 'support.dart';

void _window(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Widget _shelf({int count = 12}) => FrostShelf(title: 'Shelf', itemCount: count, itemExtent: 100, height: 80, itemBuilder: (_, i) => Text('item $i'));

Finder _labelled(String label) => find.byWidgetPredicate((w) => w is FrostButton && w.label == label);

void main() {
  for (final key in [LogicalKeyboardKey.home, LogicalKeyboardKey.end, LogicalKeyboardKey.arrowDown]) {
    testWidgets('$key brings the focus ring back after a click', (tester) async {
      await tester.pumpWidget(
        frostTestApp(
          FrostInputFeedback(
            child: Center(
              child: FrostButton(label: 'Go', onPressed: () {}),
            ),
          ),
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(frostFocusRings(), findsOneWidget);
      await tester.tap(find.byType(FrostButton), kind: PointerDeviceKind.mouse);
      await tester.pump();
      expect(frostFocusRings(), findsNothing);
      await tester.sendKeyEvent(key);
      await tester.pump();
      expect(frostFocusRings(), findsOneWidget);
    });
  }

  Color? ringColor(WidgetTester tester, Finder within) {
    final tokens = FrostThemeTokens.of(tester.element(within));
    for (final element in find.descendant(of: within, matching: find.byWidgetPredicate((w) => w is DecoratedBox || w is AnimatedContainer)).evaluate()) {
      final widget = element.widget;
      final decoration = widget is DecoratedBox ? widget.decoration : (widget as AnimatedContainer).foregroundDecoration;
      if (decoration is BoxDecoration && decoration.border is Border) {
        final color = (decoration.border! as Border).top.color;
        if (color == tokens.focus) return color;
      }
    }
    return null;
  }

  Future<void> tabThenClick(WidgetTester tester, Finder target, Offset click) async {
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump(const Duration(milliseconds: 300));
    expect(ringColor(tester, target), isNotNull, reason: 'Tab shows the ring');
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: click);
    await mouse.moveTo(click);
    await tester.pump(const Duration(milliseconds: 300));
    expect(ringColor(tester, target), isNotNull, reason: 'moving the mouse keeps the ring');
    await mouse.down(click);
    await mouse.up();
    // The pager's ring fades, so let that animation start and then finish.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(ringColor(tester, target), isNull, reason: 'a click hides the ring');
    await mouse.removePointer();
  }

  testWidgets('a click hides the pager focus ring', (tester) async {
    _window(tester, const Size(800, 600));
    await tester.pumpWidget(frostTestApp(FrostInputFeedback(child: FrostPager(itemCount: 3, itemBuilder: (context, index) => Text('page $index')))));
    await tester.pump();
    await tabThenClick(tester, find.byType(FrostPager), tester.getCenter(find.byType(FrostPager)));
  });

  testWidgets('a click hides the split view handle focus ring', (tester) async {
    _window(tester, const Size(1200, 800));
    await tester.pumpWidget(
      frostTestApp(
        FrostInputFeedback(
          child: FrostSplitView(primary: const Text('primary'), secondary: const Text('secondary'), onCloseSecondary: () {}, resizable: true),
        ),
      ),
    );
    await tester.pump();
    await tabThenClick(tester, find.byType(FrostSplitView), tester.getCenter(find.text('secondary')));
  });

  testWidgets('an app InkWell keeps its focus highlight after a click', (tester) async {
    final previous = FocusManager.instance.highlightStrategy;
    await tester.pumpWidget(
      frostTestApp(
        FrostInputFeedback(
          child: Center(
            child: Material(
              child: InkWell(onTap: () {}, child: const SizedBox(width: 80, height: 40)),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(InkWell), kind: PointerDeviceKind.mouse);
    await tester.pump();
    expect(FocusManager.instance.highlightStrategy, previous);
    await tester.sendKeyEvent(LogicalKeyboardKey.home);
    await tester.pump();
    expect(FocusManager.instance.highlightMode, FocusHighlightMode.traditional);
  });

  testWidgets('a touch platform shows shelf buttons once a mouse is used', (tester) async {
    await tester.pumpWidget(
      frostTestApp(
        Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: 300, child: _shelf()),
        ),
        platform: TargetPlatform.android,
      ),
    );
    expect(_labelled('L.next'), findsNothing);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(100, 100));
    await mouse.moveTo(const Offset(120, 100));
    await tester.pump();
    expect(_labelled('L.next'), findsOneWidget);
    await mouse.removePointer();
  });

  testWidgets('a late mouse on a touch platform moves nothing in the shelf', (tester) async {
    const key = ValueKey('action');
    await tester.pumpWidget(
      frostTestApp(
        Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 400,
            child: FrostShelf(
              title: 'Shelf',
              action: FrostButton(key: key, label: 'All', onPressed: () {}),
              itemCount: 12,
              itemExtent: 100,
              height: 80,
              itemBuilder: (_, i) => Text('item \$i'),
            ),
          ),
        ),
        platform: TargetPlatform.android,
      ),
    );
    await tester.pump();
    final action = tester.getRect(find.byKey(key)), shelf = tester.getSize(find.byType(FrostShelf));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(300, 500));
    await mouse.moveTo(const Offset(310, 500));
    await tester.pumpAndSettle();
    expect(_labelled('L.next'), findsOneWidget);
    expect(tester.getRect(find.byKey(key)), action);
    expect(tester.getSize(find.byType(FrostShelf)), shelf);
    await tester.tap(_labelled('L.next'), kind: PointerDeviceKind.mouse);
    await tester.pumpAndSettle();
    expect(tester.stateList<ScrollableState>(find.byType(Scrollable)).singleWhere((s) => s.position.axis == Axis.horizontal).position.pixels, greaterThan(0));
    await mouse.removePointer();
  });

  ScrollPosition shelfPosition(WidgetTester tester) =>
      tester.stateList<ScrollableState>(find.byType(Scrollable)).singleWhere((s) => s.position.axis == Axis.horizontal).position;

  Future<void> wheel(WidgetTester tester, Offset at) async {
    final pointer = TestPointer(77, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(pointer.hover(at));
    await tester.sendEventToBinding(pointer.scroll(const Offset(0, 120)));
    await tester.pump(const Duration(milliseconds: 300));
  }

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS, TargetPlatform.windows]) {
    testWidgets('a vertical wheel moves a shelf with no page to scroll on $platform', (tester) async {
      await tester.pumpWidget(
        frostTestApp(
          Align(
            alignment: Alignment.topLeft,
            child: SizedBox(width: 300, child: _shelf()),
          ),
          platform: platform,
        ),
      );
      await tester.pump();
      await wheel(tester, tester.getCenter(find.text('item 0')));
      expect(shelfPosition(tester).pixels, 120);
    });
  }

  testWidgets('a vertical wheel over a shelf keeps scrolling the page', (tester) async {
    final page = ScrollController();
    addTearDown(page.dispose);
    await tester.pumpWidget(
      frostTestApp(
        SingleChildScrollView(
          controller: page,
          child: Column(
            children: [
              SizedBox(width: 300, child: _shelf()),
              const SizedBox(height: 2000),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    await wheel(tester, tester.getCenter(find.text('item 0')));
    expect(shelfPosition(tester).pixels, 0);
    expect(page.position.pixels, 120);
  });

  testWidgets('a touch platform shows pager arrows while a mouse hovers, and hides them after a finger', (tester) async {
    await tester.pumpWidget(
      frostTestApp(
        Center(
          child: SizedBox(width: 400, height: 300, child: FrostPager(itemCount: 3, itemBuilder: (_, i) => Text('page $i'))),
        ),
        platform: TargetPlatform.android,
      ),
    );
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.byType(PageView)));
    await tester.pumpAndSettle();
    expect(_labelled('L.next'), findsOneWidget);
    await tester.tapAt(tester.getCenter(find.byType(PageView)));
    await tester.pumpAndSettle();
    expect(_labelled('L.next'), findsNothing);
    await mouse.removePointer();
  });

  testWidgets('after a touch a pointer-sized button takes taps in a 44 target without moving', (tester) async {
    _window(tester, const Size(800, 600));
    var taps = 0;
    final button = find.byType(FrostButton);
    await tester.pumpWidget(
      frostTestApp(
        FrostInputFeedback(
          child: Center(
            child: FrostButton.icon(icon: testIcons.add, label: 'Add', size: FrostControlSize.small, onPressed: () => taps++),
          ),
        ),
      ),
    );
    final rect = tester.getRect(button);
    expect(rect.height, lessThan(44));
    final justOutside = rect.topCenter - Offset(0, (44 - rect.height) / 2 - 1);
    await tester.tapAt(justOutside, kind: PointerDeviceKind.mouse);
    await tester.pump(const Duration(milliseconds: 300));
    expect(taps, 0, reason: 'a mouse uses the visual size');
    await tester.tapAt(rect.center);
    await tester.pump(const Duration(milliseconds: 300));
    expect(taps, 1);
    await tester.tapAt(justOutside);
    await tester.pump(const Duration(milliseconds: 300));
    expect(taps, 2, reason: 'a later touch gets the touch target');
    expect(tester.getRect(button), rect);
    final far = rect.topCenter - Offset(0, (44 - rect.height) / 2 + 2);
    await tester.tapAt(far);
    await tester.pump(const Duration(milliseconds: 300));
    expect(taps, 2);
  });

  testWidgets('a date range popover grid is one Tab stop and arrow keys move inside it', (tester) async {
    _window(tester, const Size(1100, 850));
    await tester.pumpWidget(
      frostTestApp(
        Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 400,
            child: FrostDateRangePicker(
              value: (start: DateTime(2026, 10, 12), end: DateTime(2026, 10, 14)),
              onChanged: (_) {},
              label: 'Range',
              placeholder: 'Pick',
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(FrostDateRangePicker));
    await tester.pumpAndSettle();
    bool onApply() {
      var found = false;
      FocusManager.instance.primaryFocus?.context?.visitAncestorElements((element) {
        final widget = element.widget;
        found = widget is Semantics && widget.properties.label == 'L.apply';
        return !found;
      });
      return found;
    }

    final start = FocusManager.instance.primaryFocus;
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(FocusManager.instance.primaryFocus, isNot(same(start)), reason: 'an arrow key moves inside the grid');
    var presses = 0;
    while (!onApply() && presses < 40) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      presses++;
    }
    expect(onApply(), isTrue);
    expect(presses, lessThanOrEqualTo(4));
  });

  testWidgets('a segmented picker is one Tab stop', (tester) async {
    final after = FocusNode();
    addTearDown(after.dispose);
    await tester.pumpWidget(
      frostTestApp(
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FrostPicker<int>.segmented(
                label: 'Group',
                value: 0,
                options: const [
                  FrostPickerOption(value: 0, label: 'A'),
                  FrostPickerOption(value: 1, label: 'B'),
                  FrostPickerOption(value: 2, label: 'C'),
                ],
                onChanged: (_) {},
              ),
              TextButton(focusNode: after, onPressed: () {}, child: const Text('after')),
            ],
          ),
        ),
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(after.hasPrimaryFocus, isTrue);
  });
}
