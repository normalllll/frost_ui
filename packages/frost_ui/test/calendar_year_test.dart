import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/controls/_calendar.dart' show FrostCalendar, FrostDateClock;
import 'package:frost_ui/src/controls/_calendar_years.dart' show FrostCalendarYears;

import 'support.dart';

final _today = DateTime(2026, 11, 9);
final _birthday = DateTime(1997, 12, 18);

Widget _clocked(Widget child) => FrostDateClock(today: _today, child: child);

const _title = 'November 2026';
String _text(int year) => '$year';

Future<void> _open(WidgetTester tester, Widget picker, {Size size = const Size(1280, 800)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(frostTestApp(Center(child: SizedBox(width: 320, child: _clocked(picker)))));
  await tester.tap(find.byWidget(picker));
  await tester.pumpAndSettle();
}

Future<void> _showYears(WidgetTester tester, [String title = _title]) async {
  await tester.tap(find.text(title));
  await tester.pumpAndSettle();
}

Future<void> _key(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await tester.pumpAndSettle();
}

Finder _year(int year) => find.text(_text(year));

bool _dayHasFocus(WidgetTester tester, DateTime day) {
  final focused = FocusManager.instance.primaryFocus?.context;
  return focused != null &&
      find.descendant(of: find.byKey(ValueKey(day)), matching: find.byWidgetPredicate((w) => identical(w, focused.widget))).evaluate().isNotEmpty;
}

void main() {
  group('field text', () {
    for (final locale in const [
      Locale('en', 'US'),
      Locale('zh', 'CN'),
      Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant', countryCode: 'TW'),
      Locale('ja', 'JP'),
    ]) {
      testWidgets('showsYear includes the year in $locale', (tester) async {
        await tester.pumpWidget(
          frostTestApp(
            Localizations(
              locale: locale,
              delegates: GlobalMaterialLocalizations.delegates,
              child: FrostDatePicker(label: 'Birthday', value: _birthday, showsYear: true, onChanged: (_) {}),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.textContaining('1997'), findsOneWidget);
      });
    }

    testWidgets('the default keeps the medium date', (tester) async {
      await tester.pumpWidget(frostTestApp(FrostDatePicker(label: 'Birthday', value: _birthday, onChanged: (_) {})));
      await tester.pumpAndSettle();
      expect(find.text(const DefaultMaterialLocalizations().formatMediumDate(_birthday)), findsOneWidget);
      expect(find.textContaining('1997'), findsNothing);
    });

    testWidgets('a range with showsYear includes both years', (tester) async {
      await tester.pumpWidget(
        frostTestApp(
          FrostDateRangePicker(
            label: 'Period',
            value: (start: DateTime(1997, 12, 18), end: DateTime(1998, 1, 3)),
            showsYear: true,
            onChanged: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining(RegExp('1997.*1998')), findsOneWidget);
    });
  });

  group('year list', () {
    Widget picker(ValueChanged<DateTime?> changed, {DateTime? value, DateTime? firstDate, DateTime? lastDate}) => FrostDatePicker(
      label: 'Birthday',
      value: value,
      onChanged: changed,
      firstDate: firstDate ?? DateTime(1950),
      lastDate: lastDate ?? DateTime(2030, 12, 31),
    );

    testWidgets('reaching a distant year takes the same steps as a near one', (tester) async {
      final changes = <DateTime?>[];
      await _open(tester, picker(changes.add));
      await _showYears(tester);
      await tester.scrollUntilVisible(_year(1997), -200, scrollable: find.byType(Scrollable).last);
      await tester.pumpAndSettle();
      await tester.tap(_year(1997));
      await tester.pumpAndSettle();
      expect(find.text('November 1997'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(findFrostTooltip('L.next').last);
      await tester.pumpAndSettle();
      expect(find.text('December 1997'), findsOneWidget);
      await tester.tap(find.text('18'));
      await tester.pumpAndSettle();
      expect(changes.single, _birthday);
    });

    testWidgets('lists only the years inside the bounds', (tester) async {
      await _open(tester, picker((_) {}, firstDate: DateTime(2024, 6, 15), lastDate: DateTime(2027, 2, 10)));
      await _showYears(tester);
      for (final year in [2024, 2025, 2026, 2027]) {
        expect(_year(year), findsOneWidget);
      }
      expect(_year(2023), findsNothing);
      expect(_year(2028), findsNothing);
    });

    testWidgets('a year whose month is out of bounds shows the nearest allowed month', (tester) async {
      await _open(tester, picker((_) {}, firstDate: DateTime(2024, 12, 5), lastDate: DateTime(2027, 2, 10)));
      await _showYears(tester);
      await tester.tap(_year(2024));
      await tester.pumpAndSettle();
      expect(find.text('December 2024'), findsOneWidget);
    });

    testWidgets('the panel keeps its size and the month arrows wait for the year', (tester) async {
      await _open(tester, picker((_) {}));
      final before = tester.getSize(find.byType(FrostPopover).last).height;
      await _showYears(tester);
      expect(tester.getSize(find.byType(FrostPopover).last).height, before);
      final next = tester.widget<FrostButton>(find.ancestor(of: findFrostTooltip('L.next').last, matching: find.byType(FrostButton)).first);
      expect(next.onPressed, isNull);
      await _showYears(tester);
      expect(find.text('18'), findsOneWidget);
    });

    testWidgets('keyboard moves, selects and returns', (tester) async {
      await _open(tester, picker((_) {}));
      await _showYears(tester);
      await tester.pumpAndSettle();
      await _key(tester, LogicalKeyboardKey.arrowUp);
      await _key(tester, LogicalKeyboardKey.enter);
      expect(find.text('November 2023'), findsOneWidget);
      await _showYears(tester, 'November 2023');
      await _key(tester, LogicalKeyboardKey.escape);
      expect(find.text('November 2023'), findsOneWidget);
      expect(_year(2022), findsNothing);
      expect(find.text('18'), findsOneWidget);
    });

    testWidgets('scrolling the focused year away keeps the keyboard on a visible year', (tester) async {
      await _open(tester, picker((_) {}));
      await _showYears(tester);
      await tester.pumpAndSettle();
      tester.state<ScrollableState>(find.byType(Scrollable).last).position.jumpTo(0);
      await tester.pumpAndSettle();
      expect(_year(2026), findsNothing);
      expect(FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<FrostCalendarYears>(), isNotNull);
      await _key(tester, LogicalKeyboardKey.arrowDown);
      await _key(tester, LogicalKeyboardKey.enter);
      // Still in the column of 2026, on a row that was on screen.
      final title = tester.widget<Text>(find.textContaining('November ').first);
      final year = int.parse(title.data!.split(' ').last);
      expect(year, lessThan(1980));
      expect((year - 1950) % 3, (2026 - 1950) % 3);
    });

    testWidgets('scrolling does not take focus when the list does not hold it', (tester) async {
      await _open(tester, picker((_) {}));
      await _showYears(tester);
      await tester.pumpAndSettle();
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      final before = FocusManager.instance.primaryFocus;
      tester.state<ScrollableState>(find.byType(Scrollable).last).position.jumpTo(0);
      await tester.pumpAndSettle();
      expect(FocusManager.instance.primaryFocus, same(before));
    });

    testWidgets('keyboard can reach a year that had not been built', (tester) async {
      await _open(tester, picker((_) {}));
      await _showYears(tester);
      await tester.pumpAndSettle();
      for (var i = 0; i < 12; i++) {
        await _key(tester, LogicalKeyboardKey.pageUp);
      }
      await _key(tester, LogicalKeyboardKey.enter);
      expect(find.text('November 1950'), findsOneWidget);
    });

    testWidgets('focus returns to a day after a pick and after Escape', (tester) async {
      await _open(tester, picker((_) {}, value: DateTime(2026, 11, 18)));
      await _showYears(tester);
      await tester.pumpAndSettle();
      await _key(tester, LogicalKeyboardKey.escape);
      expect(_dayHasFocus(tester, DateTime(2026, 11, 18)), isTrue);
      await _showYears(tester);
      await tester.pumpAndSettle();
      await _key(tester, LogicalKeyboardKey.arrowUp);
      await _key(tester, LogicalKeyboardKey.enter);
      expect(_dayHasFocus(tester, DateTime(2023, 11, 18)), isTrue);
    });

    testWidgets('arrow keys mirror in RTL', (tester) async {
      DateTime? picked;
      await tester.pumpWidget(
        frostTestApp(
          Directionality(
            textDirection: TextDirection.rtl,
            child: Center(
              child: SizedBox(
                width: 320,
                child: FrostCalendar(firstDate: DateTime(2000), lastDate: DateTime(2030, 12, 31), today: _today, onSelected: (day) => picked = day),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _showYears(tester);
      await tester.pumpAndSettle();
      await _key(tester, LogicalKeyboardKey.arrowLeft);
      await _key(tester, LogicalKeyboardKey.enter);
      expect(find.text('November 2027'), findsOneWidget);
      expect(picked, isNull);
    });

    testWidgets('fits at twice the text size', (tester) async {
      tester.view.physicalSize = const Size(390, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        frostTestApp(MediaQuery.withClampedTextScaling(minScaleFactor: 2, maxScaleFactor: 2, child: Center(child: _clocked(picker((_) {}))))),
      );
      await tester.tap(find.byType(FrostDatePicker));
      await tester.pumpAndSettle();
      await _showYears(tester);
      expect(_year(2026), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('narrowing to one month while the second title is open keeps the list', (tester) async {
      final width = ValueNotifier(800.0);
      addTearDown(width.dispose);
      await tester.pumpWidget(
        frostTestApp(
          Center(
            child: ValueListenableBuilder(
              valueListenable: width,
              builder: (context, value, _) => SizedBox(
                width: value,
                child: FrostCalendar(
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2030, 12, 31),
                  today: _today,
                  range: true,
                  dualMonth: true,
                  onSelected: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _showYears(tester, 'December 2026');
      width.value = 300;
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(_year(2026), findsOneWidget);
    });

    testWidgets('switching between the two month titles shows the tapped month year', (tester) async {
      await _open(
        tester,
        FrostDateRangePicker(
          label: 'Period',
          value: (start: DateTime(2010, 12, 30), end: DateTime(2011, 1, 2)),
          onChanged: (_) {},
          firstDate: DateTime(1950),
          lastDate: DateTime(2030, 12, 31),
        ),
      );
      await _showYears(tester, 'January 2011');
      await _showYears(tester, 'December 2010');
      await tester.tap(_year(2010));
      await tester.pumpAndSettle();
      expect(find.text('December 2010'), findsOneWidget);
      expect(find.text('January 2011'), findsOneWidget);
    });

    testWidgets('works in the compact sheet', (tester) async {
      await _open(tester, picker((_) {}), size: const Size(390, 800));
      await _showYears(tester);
      await tester.tap(_year(2025));
      await tester.pumpAndSettle();
      expect(find.text('November 2025'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a year picked from the second month keeps that month', (tester) async {
      await _open(tester, FrostDateRangePicker(label: 'Period', value: null, onChanged: (_) {}, firstDate: DateTime(2000), lastDate: DateTime(2030, 12, 31)));
      await _showYears(tester, 'December 2026');
      await tester.scrollUntilVisible(_year(2010), 200, scrollable: find.byType(Scrollable).last);
      await tester.pumpAndSettle();
      await tester.tap(_year(2010));
      await tester.pumpAndSettle();
      expect(find.text('December 2010'), findsOneWidget);
      expect(find.text('November 2010'), findsOneWidget);
    });

    testWidgets('a year jump lands without sliding through the months', (tester) async {
      await _open(tester, picker((_) {}));
      await _showYears(tester);
      await tester.tap(_year(2025));
      await tester.pump();
      final slide = tester.widget<Transform>(find.byKey(const ValueKey('calendar-month-slide')));
      expect(slide.transform.getTranslation().x, 0);
      await tester.pumpAndSettle();
    });

    testWidgets('announces the title as a control for choosing the year', (tester) async {
      final handle = tester.ensureSemantics();
      await _open(tester, picker((_) {}));
      expect(find.bySemanticsLabel(_title), findsOneWidget);
      final node = tester.getSemantics(find.bySemanticsLabel(_title));
      expect(node.hint, const DefaultMaterialLocalizations().selectYearSemanticsLabel);
      handle.dispose();
    });
  });
}
