import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/controls/_calendar.dart' show FrostDateClock, frostCalendarCell;

import 'support.dart';

Finder get _sheet => find.byWidgetPredicate((w) => w is FrostSurface && w.role == FrostSurfaceRole.sheet);
Finder get _grid => find.byKey(const ValueKey('calendar-month-slide'));

Future<void> _openIn(WidgetTester tester, Widget picker, double width) async {
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    frostTestApp(
      FrostDateClock(today: DateTime(2026, 11, 10), child: Center(child: picker)),
    ),
  );
  await tester.tap(find.byWidget(picker));
  await tester.pumpAndSettle();
}

void _expectCentered(WidgetTester tester) {
  final sheet = tester.getRect(_sheet);
  final previous = tester.getRect(findFrostTooltip('L.previous').last);
  final next = tester.getRect(findFrostTooltip('L.next').last);
  final grid = tester.getRect(_grid);
  expect(previous.left - sheet.left, moreOrLessEquals(sheet.right - next.right));
  expect(grid.center.dx, moreOrLessEquals(sheet.center.dx));
}

void main() {
  for (final width in [411.0, 390.0, 560.0]) {
    testWidgets('a date calendar sits in the middle of a $width wide sheet', (tester) async {
      await _openIn(tester, FrostDatePicker(label: 'Birthday', value: DateTime(1997, 4, 12), onChanged: (_) {}), width);
      _expectCentered(tester);
    });

    testWidgets('a range calendar sits in the middle of a $width wide sheet', (tester) async {
      await _openIn(tester, FrostDateRangePicker(label: 'Period', value: null, onChanged: (_) {}), width);
      _expectCentered(tester);
    });
  }

  testWidgets('the sheet keeps the calendar size', (tester) async {
    await _openIn(tester, FrostDatePicker(label: 'Birthday', value: DateTime(1997, 4, 12), onChanged: (_) {}), 411);
    final context = tester.element(_grid);
    expect(tester.getSize(_grid).width, moreOrLessEquals(frostCalendarCell(context) * 7));
  });
}
