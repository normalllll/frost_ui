import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/primitives/keyline.dart' show FrostBleedBoundary;
import 'package:material_ui/material_ui.dart';

import 'support.dart';

const _margin = 20.0;

Future<void> _frame(WidgetTester tester, Widget child, {bool rtl = false, double width = 500, bool reduceMotion = false}) => tester.pumpWidget(
  frostTestApp(
    MediaQuery(
      data: MediaQueryData(size: const Size(800, 600), disableAnimations: reduceMotion),
      child: Directionality(
        textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
        child: Center(
          child: SizedBox(
            width: width,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: _margin),
              child: FrostKeyline(
                leadingRoom: _margin,
                trailingRoom: _margin,
                edgeDistanceStart: _margin,
                edgeDistanceEnd: _margin,
                insideContainer: false,
                contentStart: 0,
                child: child,
              ),
            ),
          ),
        ),
      ),
    ),
  ),
);

/// A controlled collapsible header with a count, a "more" button and one row.
class _Section extends StatefulWidget {
  const _Section({this.title = 'Workspace', this.pathTitle = false, this.onChanged});
  final bool pathTitle;
  final String title;
  final ValueChanged<bool>? onChanged;
  @override
  State<_Section> createState() => _SectionState();
}

class _SectionState extends State<_Section> {
  bool expanded = true;
  @override
  Widget build(BuildContext context) => FrostSectionHeader.collapsible(
    title: widget.title,
    pathTitle: widget.pathTitle,
    expanded: expanded,
    onExpansionChanged: (value) {
      widget.onChanged?.call(value);
      setState(() => expanded = value);
    },
    trailing: [
      const FrostText('12', role: FrostTextRole.callout, tone: FrostTextTone.tertiary),
      FrostButton.icon(label: 'More', icon: testIcons.more, onPressed: () {}),
    ],
    child: FrostListRow(title: 'gitbound', onPressed: () {}),
  );
}

const _headerTitleLabels = 1;

Widget _maybeBoundary(bool bounded, Widget child) => bounded ? FrostBleedBoundary(child: child) : child;

Finder get _toggle => find.byWidgetPredicate((widget) => widget is Semantics && widget.properties.expanded != null);

void main() {
  for (final rtl in [false, true]) {
    testWidgets('title and row text share the keyline; trailing actions follow the toggle rtl=$rtl', (tester) async {
      await _frame(tester, const _Section(), rtl: rtl);
      await tester.pumpAndSettle();
      final header = tester.getRect(find.byType(FrostSectionHeader));
      final title = tester.getRect(find.text('Workspace'));
      final row = tester.getRect(find.text('gitbound'));
      expect(rtl ? title.right : title.left, rtl ? header.right - FrostGap.panelInset : header.left + FrostGap.panelInset);
      expect(rtl ? row.right : row.left, rtl ? title.right : title.left);
      final card = tester.getRect(find.descendant(of: find.byType(FrostSectionHeader), matching: find.byType(FrostSurface)).first);
      expect(card, header);
      expect(card.contains(tester.getCenter(findFrostTooltip('More'))), isTrue);
      expect(card.contains(row.center), isTrue);
      // The toggle ends before the independent trailing controls.
      final glyph = tester.getRect(find.descendant(of: _toggle, matching: find.byType(FrostIcon)));
      // Order: title and chevron, count, more.
      final count = tester.getRect(find.text('12'));
      final more = tester.getRect(findFrostTooltip('More'));
      if (rtl) {
        expect(count.left, greaterThan(more.right - 1));
        expect(glyph.left, greaterThan(count.right));
      } else {
        expect(count.right, lessThan(more.left + 1));
        expect(glyph.right, lessThan(count.left));
      }
      expect(tester.takeException(), isNull);
    });
  }

  for (final scale in [1.0, 2.0]) {
    testWidgets('narrow panel keeps its internal actions and body usable at text scale $scale', (tester) async {
      var actions = 0;
      await tester.pumpWidget(
        frostTestApp(
          MediaQuery(
            data: MediaQueryData(size: const Size(800, 600), textScaler: TextScaler.linear(scale)),
            child: SingleChildScrollView(
              child: Center(
                child: SizedBox(
                  width: 200,
                  child: FrostSectionHeader.collapsible(
                    title: 'Repository workspace',
                    expanded: true,
                    onExpansionChanged: (_) {},
                    trailing: [FrostButton(label: 'Manage repositories', onPressed: () => actions++)],
                    child: FrostButton(label: 'Open repository', onPressed: () => actions++),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final card = tester.getRect(find.byType(FrostSectionHeader));
      for (final label in ['Manage repositories', 'Open repository']) {
        final button = find.widgetWithText(FrostButton, label);
        final bounds = tester.getRect(button);
        expect(bounds.left, greaterThanOrEqualTo(card.left));
        expect(bounds.right, lessThanOrEqualTo(card.right));
        await tester.ensureVisible(button);
        await tester.tap(button);
      }
      expect(actions, 2);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('toggle reports the next state, exposes expanded and collapses the content with motion', (tester) async {
    final changes = <bool>[];
    final semantics = tester.ensureSemantics();
    await _frame(tester, _Section(onChanged: changes.add));
    await tester.pumpAndSettle();
    expect(
      tester.getSemantics(_toggle),
      matchesSemantics(
        label: 'Workspace',
        isButton: true,
        hasEnabledState: true,
        isEnabled: true,
        hasTapAction: true,
        hasExpandedState: true,
        isExpanded: true,
      ),
    );
    final expandedHeight = tester.getSize(find.byType(FrostSectionHeader)).height;

    await tester.tap(_toggle);
    expect(changes, [false]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    final midway = tester.getSize(find.byType(FrostSectionHeader)).height;
    await tester.pumpAndSettle();
    final collapsedHeight = tester.getSize(find.byType(FrostSectionHeader)).height;
    expect(collapsedHeight, lessThan(expandedHeight));
    expect(collapsedHeight, greaterThanOrEqualTo(52), reason: 'collapsed panels retain a spacious card header');
    expect(midway, inExclusiveRange(collapsedHeight, expandedHeight));
    expect(find.bySemanticsLabel('gitbound'), findsNothing);
    expect(
      tester.getSemantics(_toggle),
      matchesSemantics(label: 'Workspace', isButton: true, hasEnabledState: true, isEnabled: true, hasTapAction: true, hasExpandedState: true),
    );

    await tester.tap(_toggle);
    await tester.pumpAndSettle();
    expect(changes, [false, true]);
    expect(tester.getSize(find.byType(FrostSectionHeader)).height, expandedHeight);
    semantics.dispose();
  });

  group('the title area toggles too', () {
    testWidgets('tapping the title text toggles; tapping a trailing button does not', (tester) async {
      final changes = <bool>[];
      await _frame(tester, _Section(onChanged: changes.add));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Workspace'));
      await tester.pumpAndSettle();
      expect(changes, [false]);
      await tester.tap(find.text('Workspace'));
      await tester.pumpAndSettle();
      expect(changes, [false, true]);
      await tester.tap(find.byWidgetPredicate((widget) => widget is FrostButton && widget.label == 'More'));
      await tester.tap(find.text('12'));
      await tester.pumpAndSettle();
      expect(changes, [false, true], reason: 'trailing controls keep their own presses');
    });

    testWidgets('a path title toggles on a tap too', (tester) async {
      final changes = <bool>[];
      await _frame(tester, _Section(title: r'D:workgitbound', pathTitle: true, onChanged: changes.add));
      await tester.pumpAndSettle();
      await tester.tap(find.text(r'D:workgitbound'));
      expect(changes, [false]);
    });

    testWidgets('a null callback leaves the title inert', (tester) async {
      await _frame(tester, FrostSectionHeader.collapsible(title: 'Workspace', expanded: true, onExpansionChanged: null, child: const Text('Body')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Workspace'));
      await tester.pumpAndSettle();
      expect(find.text('Body'), findsOneWidget);
    });

    testWidgets('hover and press tint the title area', (tester) async {
      await _frame(tester, const _Section());
      await tester.pumpAndSettle();
      final title = find.text('Workspace');
      Color? fill() => switch (tester.widgetList<DecoratedBox>(find.ancestor(of: title, matching: find.byType(DecoratedBox))).first.decoration) {
        ShapeDecoration(:final color) || BoxDecoration(:final color) => color,
        _ => null,
      };
      expect(fill()?.a ?? 0, 0);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(tester.getCenter(title));
      await tester.pumpAndSettle();
      final hovered = fill()!;
      expect(hovered.a, greaterThan(0));
      await mouse.down(tester.getCenter(title));
      await tester.pumpAndSettle();
      expect(fill()!.a, greaterThan(hovered.a));
      await mouse.up();
      await mouse.moveTo(tester.getCenter(find.byType(FrostListRow)));
      await tester.pumpAndSettle();
      expect(fill()?.a ?? 0, 0);
    });

    for (final rtl in [false, true]) {
      for (final bounded in [true, false]) {
        testWidgets('the tint and the hit area are the same box (boundary=$bounded rtl=$rtl)', (tester) async {
          final changes = <bool>[];
          final section = _Section(onChanged: changes.add);
          await tester.pumpWidget(
            frostTestApp(
              Directionality(
                textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: SizedBox(
                    width: 500,
                    child: _maybeBoundary(
                      bounded,
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: _margin),
                        child: FrostKeyline(
                          leadingRoom: _margin,
                          trailingRoom: _margin,
                          edgeDistanceStart: _margin,
                          edgeDistanceEnd: _margin,
                          insideContainer: false,
                          contentStart: 0,
                          child: section,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final header = tester.getRect(find.byType(FrostSectionHeader));
          final title = tester.getRect(find.text('Workspace'));
          final tint = tester.getRect(find.ancestor(of: find.text('Workspace'), matching: find.byType(DecoratedBox)).first);
          // The panel owns its inset, independent of an outer bleed boundary.
          expect(rtl ? title.right : title.left, rtl ? header.right - FrostGap.panelInset : header.left + FrostGap.panelInset);
          final reach = rtl ? tint.right - header.right : header.left - tint.left;
          expect(reach, 0);
          // Every tinted pixel toggles; the pixel beside the tint does not.
          var expected = 0;
          for (final point in [
            tint.centerLeft + const Offset(1, 0),
            tint.centerRight - const Offset(1, 0),
            tint.topCenter + const Offset(0, 1),
            tint.bottomCenter - const Offset(0, 1),
            tint.center,
          ]) {
            await tester.tapAt(point);
            await tester.pumpAndSettle();
            expect(changes.length, ++expected, reason: '$point');
          }
          final outside = rtl ? tint.right + 2 : tint.left - 2;
          await tester.tapAt(Offset(outside, tint.center.dy));
          await tester.pumpAndSettle();
          expect(changes.length, expected, reason: 'beside the tint');
          expect(tester.takeException(), isNull);
        });
      }
    }

    testWidgets('one title toggle precedes trailing actions in focus and semantics', (tester) async {
      final semantics = tester.ensureSemantics();
      await _frame(tester, const _Section());
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Workspace'), findsNWidgets(_headerTitleLabels));
      final targets = [find.byWidgetPredicate((widget) => widget is FrostButton && widget.label == 'More'), _toggle, find.byType(FrostListRow)];
      final order = <int>[];
      for (var index = 0; index < 3; index++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        final focused = FocusManager.instance.primaryFocus?.context;
        order.add(
          targets.indexWhere(
            (finder) =>
                focused != null && find.descendant(of: finder, matching: find.byElementPredicate((element) => element == focused)).evaluate().isNotEmpty,
          ),
        );
      }
      expect(order, [1, 0, 2], reason: 'one title toggle, the trailing button, then the content');
      semantics.dispose();
    });
  });

  testWidgets('reduced motion snaps the content', (tester) async {
    await _frame(tester, const _Section(), reduceMotion: true);
    await tester.pumpAndSettle();
    final expandedHeight = tester.getSize(find.byType(FrostSectionHeader)).height;
    await tester.tap(_toggle);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    expect(tester.getSize(find.byType(FrostSectionHeader)).height, lessThan(expandedHeight));
  });

  testWidgets('keyboard focuses and toggles; collapsed content takes no focus', (tester) async {
    final changes = <bool>[];
    await _frame(
      tester,
      Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Section(onChanged: changes.add),
          FrostButton(label: 'After', onPressed: () {}),
        ],
      ),
    );
    await tester.pumpAndSettle();
    bool focusIn(Finder finder) {
      final focused = FocusManager.instance.primaryFocus?.context;
      return focused != null && find.descendant(of: finder, matching: find.byElementPredicate((element) => element == focused)).evaluate().isNotEmpty;
    }

    // The title toggle, then More, then the row.
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(focusIn(_toggle), isTrue);
    // Expanded, Tab passes the independent trailing action to reach the row.
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(focusIn(find.byType(FrostListRow)), isTrue);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
    await tester.pump();
    expect(focusIn(_toggle), isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(changes, [false]);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(changes, [false, true]);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(changes, [false, true, false]);
    expect(focusIn(_toggle), isTrue);
    // Collapsed, Tab passes More and skips the hidden row.
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(focusIn(find.widgetWithText(FrostButton, 'After')), isTrue);
  });

  testWidgets('a path title header reports intrinsic sizes', (tester) async {
    await _frame(
      tester,
      const IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [Expanded(child: FrostSectionHeader(title: r'D:\work\clients\organisation\repositories', pathTitle: true))],
        ),
      ),
      width: 260,
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.textContaining('…'), findsOneWidget);
    await _frame(tester, const IntrinsicWidth(child: FrostSectionHeader(title: r'D:\work', pathTitle: true)));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text(r'D:\work'), findsOneWidget);
  });

  testWidgets('a null callback disables the toggle', (tester) async {
    await _frame(tester, FrostSectionHeader.collapsible(title: 'Workspace', expanded: true, onExpansionChanged: null, child: const SizedBox(height: 20)));
    final semantics = tester.ensureSemantics();
    expect(tester.getSemantics(_toggle), matchesSemantics(label: 'Workspace', isButton: true, hasEnabledState: true, hasExpandedState: true, isExpanded: true));
    semantics.dispose();
  });

  group('path title', () {
    const path = r'D:\work\clients\very-long-organisation-name\repositories\gitbound';
    testWidgets('fits: shown whole on one line with tabular figures', (tester) async {
      await _frame(tester, const FrostSectionHeader(title: r'D:\work', pathTitle: true), width: 500);
      final paragraph = _paragraph(tester, r'D:\work');
      expect(paragraph.maxLines, 1);
      expect(paragraph.text.style!.fontFeatures, contains(const FontFeature.tabularFigures()));
      expect(paragraph.text.style!.fontSize, 15);
      expect(findFrostTooltip(r'D:\work'), findsOneWidget);
    });

    testWidgets('too long: shortened in the middle, full path in tooltip and semantics', (tester) async {
      final semantics = tester.ensureSemantics();
      await _frame(tester, const _Section(title: path, pathTitle: true), width: 320);
      await tester.pumpAndSettle();
      final paragraph = tester.widgetList<Text>(find.byType(Text)).firstWhere((text) => text.semanticsLabel == path);
      final shown = paragraph.data!;
      expect(shown, isNot(path));
      expect(shown, contains('…'));
      expect(path.startsWith(shown.split('…').first), isTrue);
      expect(path.endsWith(shown.split('…').last), isTrue);
      expect(shown.split('…').last, isNotEmpty);
      expect(_paragraph(tester, shown).didExceedMaxLines, isFalse);
      expect(findFrostTooltip(path), findsOneWidget);
      // The single title toggle reads the full path once.
      expect(find.bySemanticsLabel(path), findsOneWidget);
      // The title never runs into the trailing controls.
      expect(tester.getRect(find.text(shown)).right, lessThanOrEqualTo(tester.getRect(find.text('12')).left));
      semantics.dispose();
    });

    testWidgets('plain titles keep two lines with an end ellipsis', (tester) async {
      await _frame(tester, const FrostSectionHeader(title: path), width: 240);
      expect(_paragraph(tester, path).maxLines, 2);
    });
  });
}

RenderParagraph _paragraph(WidgetTester tester, String text) =>
    tester.renderObject<RenderParagraph>(find.descendant(of: find.text(text), matching: find.byType(RichText)).first);
