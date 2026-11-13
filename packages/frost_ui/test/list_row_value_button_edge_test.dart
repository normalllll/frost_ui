import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/controls/_button_control.dart' show frostButtonTextInset;
import 'package:frost_ui/src/lists/_row_scope.dart';
import 'package:material_ui/material_ui.dart';

import 'support.dart';

Widget _group({FrostButtonEdgeAlignment? alignment, VoidCallback? onPressed, bool quiet = true}) => FrostGroupedSection(
  children: [
    const FrostListRow(title: 'Effective identity', value: 'Source: Repository'),
    FrostListRow(
      title: 'No commit identity yet',
      trailing: quiet
          ? FrostButton.quiet(label: 'Go to accounts', edgeAlignment: alignment, onPressed: onPressed ?? () {})
          : FrostButton.plain(label: 'Go to accounts', edgeAlignment: alignment, onPressed: onPressed ?? () {}),
    ),
  ],
);

void main() {
  for (final direction in TextDirection.values) {
    final rtl = direction == TextDirection.rtl;
    Future<void> pump(WidgetTester tester, Widget child) async {
      tester.view.physicalSize = const Size(640, 480);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        frostTestApp(
          Directionality(
            textDirection: direction,
            child: Center(child: SizedBox(width: 600, child: child)),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    // The distance of a text's outer edge from the group's outer edge.
    double endEdge(WidgetTester tester, String text) {
      final group = tester.getRect(find.byType(FrostGroupedSection)), box = tester.getRect(find.text(text));
      return rtl ? box.left - group.left : group.right - box.right;
    }

    for (final quiet in [true, false]) {
      testWidgets('an end-aligned text button ends where the other rows\' values end (quiet=$quiet, $direction)', (tester) async {
        await pump(tester, _group(alignment: FrostButtonEdgeAlignment.end, quiet: quiet));
        expect(endEdge(tester, 'Go to accounts'), moreOrLessEquals(endEdge(tester, 'Source: Repository'), epsilon: .01));
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('without an alignment the button keeps its padding inside the value edge ($direction)', (tester) async {
      await pump(tester, _group());
      expect(endEdge(tester, 'Go to accounts') - endEdge(tester, 'Source: Repository'), frostButtonTextInset(FrostControlSize.compact));
    });

    testWidgets('the hit area and hover fill reach into the row padding ($direction)', (tester) async {
      var presses = 0;
      await pump(tester, _group(alignment: FrostButtonEdgeAlignment.end, onPressed: () => presses++));
      final text = tester.getRect(find.text('Go to accounts'));
      // Just past the text, inside the button's end padding that lies in the row's.
      await tester.tapAt(Offset(rtl ? text.left - 6 : text.right + 6, text.center.dy));
      expect(presses, 1);
    });
  }

  group('the button keeps its State and focus when the row gains an end element', () {
    Future<(State, FocusNode?)> focusButton(WidgetTester tester) async {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      return (tester.state(find.byType(FrostButton)), FocusManager.instance.primaryFocus);
    }

    testWidgets('a list item scope check appears (null to false)', (tester) async {
      tester.view.physicalSize = const Size(640, 480);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final handle = FrostListItemHandle();
      bool? checked;
      late StateSetter update;
      await tester.pumpWidget(
        frostTestApp(
          StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return FrostGroupedSection(
                children: [
                  FrostListItemScope(
                    selected: checked,
                    highlighted: false,
                    onSelected: null,
                    handle: handle,
                    viewportInset: EdgeInsets.zero,
                    child: FrostListRow(
                      title: 'No commit identity yet',
                      trailing: FrostButton.quiet(label: 'Go to accounts', edgeAlignment: FrostButtonEdgeAlignment.end, onPressed: () {}),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      final (state, focus) = await focusButton(tester);
      expect(focus, isNotNull);
      update(() => checked = false);
      await tester.pumpAndSettle();
      expect(identical(tester.state(find.byType(FrostButton)), state), isTrue);
      expect(FocusManager.instance.primaryFocus, same(focus));
      expect(tester.takeException(), isNull);
    });

    testWidgets('an accessory appears', (tester) async {
      tester.view.physicalSize = const Size(640, 480);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      var accessory = FrostRowAccessory.none;
      late StateSetter update;
      await tester.pumpWidget(
        frostTestApp(
          StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return FrostGroupedSection(
                children: [
                  FrostListRow(
                    title: 'No commit identity yet',
                    accessory: accessory,
                    trailing: FrostButton.quiet(label: 'Go to accounts', edgeAlignment: FrostButtonEdgeAlignment.end, onPressed: () {}),
                  ),
                ],
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      final (state, focus) = await focusButton(tester);
      update(() => accessory = FrostRowAccessory.chevron);
      await tester.pumpAndSettle();
      expect(identical(tester.state(find.byType(FrostButton)), state), isTrue);
      expect(FocusManager.instance.primaryFocus, same(focus));
    });
  });
}
