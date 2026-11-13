import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/layout/_column_split.dart';
import 'package:frost_ui/src/layout/_content_padding.dart';
import 'package:frost_ui/src/layout/navigation_column_row.dart' show FrostNavigationColumnFocus, frostNavigationRowTextStart;
import 'package:frost_ui/src/navigation/_navigation_tile.dart';
import 'package:material_ui/material_ui.dart';

import 'support.dart';

const _labels = ['Alpha', 'Bravo', 'Charlie'];

/// The navigation column of a split page, as an app composes it from the
/// column panes and the column focus.
Widget _column(List<Widget> children) => LayoutBuilder(
  builder: (context, constraints) => FrostColumnPanes(
    wide: frostColumnSplitIsWide(context, constraints.maxWidth),
    width: constraints.maxWidth,
    navigation: FrostNavigationColumnFocus(
      child: FrostContentPadding(
        padding: const EdgeInsetsDirectional.only(start: FrostGap.related + frostNavigationRowTextStart, end: FrostGap.related),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            FrostContentColumn(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
            ),
          ],
        ),
      ),
    ),
    content: const Text('Detail'),
  ),
);

Finder _fill(Finder of) => find.descendant(of: of, matching: find.byType(DecoratedBox)).first;
Finder _row(String title) => find.widgetWithText(FrostNavigationColumnRow, title);
FocusNode? get _focused => FocusManager.instance.primaryFocus;
bool _focusIsIn(WidgetTester tester, Finder finder) {
  final context = _focused?.context;
  return context != null && find.descendant(of: finder, matching: find.byElementPredicate((element) => element == context)).evaluate().isNotEmpty;
}

void main() {
  void viewport(WidgetTester tester, [Size size = const Size(1200, 820)]) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  for (final density in [FrostDensity.compact, FrostDensity.comfortable]) {
    testWidgets('row height, selected fill and text line match the settings section list ($density)', (tester) async {
      viewport(tester);
      await tester.pumpWidget(
        frostTestApp(
          FrostSettingsSections(labels: _labels, selectedIndex: 1, onSelected: (_) {}, sectionBuilder: (_, _) => const Text('Section')),
          density: density,
        ),
      );
      await tester.pumpAndSettle();
      Rect tile(String label) => tester.getRect(_fill(find.widgetWithText(FrostNavigationTile, label)));
      final settings = [for (final label in _labels) tile(label)];
      final settingsText = tester.getRect(find.text('Bravo'));
      final settingsInk = tester.widget<Text>(find.text('Bravo')).style!.color;

      await tester.pumpWidget(
        frostTestApp(
          _column([for (final (index, label) in _labels.indexed) FrostNavigationColumnRow(title: label, selected: index == 1, onPressed: () {})]),
          density: density,
        ),
      );
      await tester.pumpAndSettle();
      final rows = [for (final label in _labels) tester.getRect(_fill(_row(label)))];
      expect(rows, settings);
      expect(tester.getRect(find.text('Bravo')).left, settingsText.left);
      expect(tester.getRect(find.text('Bravo')).center.dy, moreOrLessEquals(settingsText.center.dy, epsilon: .5));
      expect(tester.widget<Text>(find.text('Bravo')).style!.color, settingsInk);
      expect(
        (tester.widget<DecoratedBox>(_fill(_row('Bravo'))).decoration as BoxDecoration).color,
        FrostThemeTokens.of(tester.element(_row('Bravo'))).selectionFill,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('a section header in the column starts on the row text line', (tester) async {
    viewport(tester);
    await tester.pumpWidget(
      frostTestApp(_column([const FrostSectionHeader(title: r'D:\work', pathTitle: true), FrostNavigationColumnRow(title: 'gitbound', onPressed: () {})])),
    );
    await tester.pumpAndSettle();
    expect(tester.getRect(find.text(r'D:\work')).left, tester.getRect(find.text('gitbound')).left);
  });

  testWidgets('title and subtitle stay on one line; a tooltip carries the full text only when shortened', (tester) async {
    viewport(tester);
    const longName = 'a-repository-name-that-is-far-too-long-for-the-column';
    const longBranch = 'feature/a-branch-name-that-is-also-far-too-long-to-fit';
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      frostTestApp(
        _column([
          FrostNavigationColumnRow(
            title: longName,
            subtitle: const FrostRowSubtitle.status(longBranch, FrostStatusTone.caution),
            selected: true,
            onPressed: () {},
          ),
          FrostNavigationColumnRow(title: 'short', subtitle: const FrostRowSubtitle('main'), onPressed: () {}),
        ]),
      ),
    );
    await tester.pumpAndSettle();
    for (final text in [longName, longBranch, 'short', 'main']) {
      final widget = tester.widget<Text>(find.text(text));
      expect(widget.maxLines, 1, reason: text);
      expect(widget.overflow, TextOverflow.ellipsis, reason: text);
    }
    expect(findFrostTooltip(longName), findsOneWidget);
    expect(findFrostTooltip(longBranch), findsOneWidget);
    expect(findFrostTooltip('short'), findsNothing);
    expect(findFrostTooltip('main'), findsNothing);
    expect(find.byType(FrostStatusDot), findsOneWidget);
    // Long rows keep the one-line-with-subtitle height.
    expect(tester.getSize(_row(longName)).height, tester.getSize(_row('short')).height);
    expect(
      tester.getSemantics(find.descendant(of: _row(longName), matching: find.byType(Semantics)).first),
      matchesSemantics(
        label: longName,
        value: longBranch,
        isButton: true,
        hasEnabledState: true,
        isEnabled: true,
        hasSelectedState: true,
        isSelected: true,
        hasTapAction: true,
      ),
    );
    semantics.dispose();
  });

  testWidgets('tap selects, the context menu opens on a secondary click, trailing stays at the end', (tester) async {
    viewport(tester);
    var taps = 0, opened = 0;
    await tester.pumpWidget(
      frostTestApp(
        _column([
          FrostNavigationColumnRow(
            title: 'archive.git',
            trailing: const FrostTag(label: 'bare'),
            onPressed: () => taps++,
            contextMenu: [FrostMenuAction('Open folder', onSelected: () => opened++)],
          ),
        ]),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('archive.git'));
    expect(taps, 1);
    expect(tester.getRect(find.text('bare')).right, lessThanOrEqualTo(tester.getRect(_fill(_row('archive.git'))).right));
    expect(tester.getRect(find.text('bare')).left, greaterThan(tester.getRect(find.text('archive.git')).right));
    await tester.tapAt(tester.getCenter(find.text('archive.git')), kind: PointerDeviceKind.mouse, buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open folder'));
    await tester.pumpAndSettle();
    expect(opened, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a leading slot follows FrostRowLeadingExtent', (tester) async {
    viewport(tester);
    await tester.pumpWidget(
      frostTestApp(
        _column([
          FrostRowLeadingExtent(
            extent: 32,
            child: FrostNavigationColumnRow(
              title: 'zhang',
              subtitle: const FrostRowSubtitle('GitHub'),
              leading: const FrostLeading.custom(SizedBox.square(key: ValueKey('avatar'), dimension: 32)),
              onPressed: () {},
            ),
          ),
        ]),
      ),
    );
    await tester.pumpAndSettle();
    final fill = tester.getRect(_fill(_row('zhang')));
    expect(tester.getRect(find.byKey(const ValueKey('avatar'))).left, fill.left + 14);
    expect(tester.getRect(find.text('zhang')).left, fill.left + 14 + 32 + 12);
    expect(tester.getRect(find.text('GitHub')).left, tester.getRect(find.text('zhang')).left);
  });

  for (final (size, dimension) in [(FrostAvatarSize.regular, 32.0), (FrostAvatarSize.large, 40.0)]) {
    testWidgets('an avatar leading keeps its full $size size and sets the title edge without FrostRowLeadingExtent', (tester) async {
      viewport(tester);
      await tester.pumpWidget(
        frostTestApp(
          _column([
            for (final name in ['zhang', 'li'])
              FrostNavigationColumnRow(
                title: name,
                subtitle: const FrostRowSubtitle('GitHub'),
                leading: FrostLeading.custom(FrostAvatar.person(name: name, size: size)),
                onPressed: () {},
              ),
          ]),
        ),
      );
      await tester.pumpAndSettle();
      for (final name in ['zhang', 'li']) {
        final avatar = tester.getRect(find.descendant(of: _row(name), matching: find.byType(FrostAvatar)));
        expect(avatar.size, Size.square(dimension), reason: name);
        expect(avatar.left, tester.getRect(_fill(_row(name))).left + 14);
      }
      expect(tester.getRect(find.text('zhang')).left, tester.getRect(find.text('li')).left);
      expect(tester.getRect(find.text('zhang')).left, tester.getRect(_fill(_row('zhang'))).left + 14 + dimension + 12);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('arrow keys move focus within the column, skip collapsed rows and stop at the ends', (tester) async {
    viewport(tester);
    var expanded = true;
    late StateSetter update;
    await tester.pumpWidget(
      frostTestApp(
        StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return _column([
              FrostNavigationColumnRow(title: 'one', onPressed: () {}),
              FrostSectionHeader.collapsible(
                title: 'Folded',
                expanded: expanded,
                onExpansionChanged: (value) => setState(() => expanded = value),
                child: FrostNavigationColumnRow(title: 'hidden', onPressed: () {}),
              ),
              FrostNavigationColumnRow(title: 'two', onPressed: () {}),
            ]);
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(_focusIsIn(tester, _row('one')), isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(_focusIsIn(tester, _row('hidden')), isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(_focusIsIn(tester, _row('one')), isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(_focusIsIn(tester, _row('one')), isTrue, reason: 'clamped at the first row');

    update(() => expanded = false);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(_focusIsIn(tester, _row('two')), isTrue, reason: 'the collapsed row is skipped');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(_focusIsIn(tester, _row('two')), isTrue, reason: 'clamped at the last row');
    expect(tester.takeException(), isNull);
  });

  testWidgets('arrow keys scroll the focused row into view', (tester) async {
    viewport(tester, const Size(1200, 400));
    await tester.pumpWidget(frostTestApp(_column([for (var index = 0; index < 30; index++) FrostNavigationColumnRow(title: 'Row $index', onPressed: () {})])));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    for (var index = 0; index < 20; index++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    }
    await tester.pumpAndSettle();
    expect(_focusIsIn(tester, _row('Row 20')), isTrue);
    final row = tester.getRect(_row('Row 20'));
    expect(row.bottom, lessThanOrEqualTo(400));
    expect(row.top, greaterThanOrEqualTo(0));
  });

  testWidgets('a path subtitle is shortened in the middle, with the full path in a tooltip', (tester) async {
    viewport(tester);
    const path = r'D:\work\clients\very-long-organisation-name\repositories\gitbound';
    await tester.pumpWidget(
      frostTestApp(_column([FrostNavigationColumnRow(title: 'gitbound', subtitle: const FrostRowSubtitle.path(path), onPressed: () {})])),
    );
    await tester.pumpAndSettle();
    final shown = tester
        .widgetList<Text>(find.descendant(of: _row('gitbound'), matching: find.byType(Text)))
        .map((text) => text.data!)
        .firstWhere((data) => data != 'gitbound');
    expect(shown, isNot(path));
    final [head, tail] = shown.split('…');
    expect(path.startsWith(head), isTrue);
    expect(path.endsWith(tail), isTrue);
    expect(head, isNotEmpty);
    expect(tail, isNotEmpty);
    expect(findFrostTooltip(path), findsOneWidget);
    expect(tester.getRect(find.text(shown)).right, lessThanOrEqualTo(tester.getRect(_fill(_row('gitbound'))).right));
    // A short path is shown whole, without a tooltip.
    await tester.pumpWidget(
      frostTestApp(_column([FrostNavigationColumnRow(title: 'gitbound', subtitle: const FrostRowSubtitle.path(r'D:\work'), onPressed: () {})])),
    );
    await tester.pumpAndSettle();
    expect(find.text(r'D:\work'), findsOneWidget);
    expect(findFrostTooltip(r'D:\work'), findsNothing);
  });

  testWidgets('a row reports intrinsic sizes', (tester) async {
    viewport(tester);
    await tester.pumpWidget(
      frostTestApp(
        Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 220,
            child: IntrinsicHeight(
              child: FrostNavigationColumnRow(
                title: 'a-repository-name-that-is-far-too-long',
                subtitle: const FrostRowSubtitle.status('feature/a-long-branch-name', FrostStatusTone.positive),
                onPressed: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(findFrostTooltip('a-repository-name-that-is-far-too-long'), findsOneWidget);
    await tester.pumpWidget(
      frostTestApp(
        Align(
          alignment: Alignment.topLeft,
          child: IntrinsicWidth(
            child: FrostNavigationColumnRow(title: 'short', subtitle: const FrostRowSubtitle.path(r'D:\work'), onPressed: () {}),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(findFrostTooltip('short'), findsNothing, reason: 'its intrinsic width fits the whole title');
  });
}
