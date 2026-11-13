import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:material_ui/material_ui.dart';

import 'support.dart';

Finder get _save => find.byKey(const ValueKey('save'));
Finder get _field => find.byType(FrostTextField);

Widget _page(String label, {bool plated = true, TextDirection direction = TextDirection.ltr, List<FrostToolbarItem> before = const []}) => Directionality(
  textDirection: direction,
  child: FrostPinnedChrome(
    chrome: FrostContentColumn(
      maxWidth: FrostMetrics.readingMaxWidth,
      child: FrostPageHeader(
        leadingIcons: [FrostButton.icon(icon: testIcons.add, label: 'Back', onPressed: () {})],
        title: const FrostText('Edit'),
        actions: [
          ...before,
          FrostToolbarItem.custom(
            minWidth: 72,
            plated: plated,
            overflowEntry: FrostMenuAction(label, onSelected: () {}),
            builder: (context) => FrostButton.prominent(key: const ValueKey('save'), label: label, onPressed: () {}),
          ),
        ],
      ),
    ),
    body: CustomScrollView(
      slivers: [
        const FrostChromeSpacer(),
        FrostSliverContentColumn(
          maxWidth: FrostMetrics.readingMaxWidth,
          sliver: SliverToBoxAdapter(
            child: FrostTextField(label: 'Name', controller: TextEditingController()),
          ),
        ),
      ],
    ),
  ),
);

Future<void> _pump(WidgetTester tester, Widget page, double width) async {
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(frostTestApp(page));
  await tester.pumpAndSettle();
}

void main() {
  for (final width in [1280.0, 390.0]) {
    for (final label in ['Save', '保存', 'Save changes']) {
      testWidgets('a plated action ends on the column edge at width $width with "$label"', (tester) async {
        await _pump(tester, _page(label), width);
        expect(tester.getTopRight(_save).dx, tester.getTopRight(_field).dx);
      });
    }

    testWidgets('a plated action starts on the column edge in RTL at width $width', (tester) async {
      await _pump(tester, _page('Save', direction: TextDirection.rtl), width);
      expect(tester.getTopLeft(_save).dx, tester.getTopLeft(_field).dx);
    });
  }

  testWidgets('without plated the custom slot keeps its position', (tester) async {
    await _pump(tester, _page('Save', plated: false), 1280);
    final slotEnd = tester.getTopRight(find.ancestor(of: _save, matching: find.byType(SizedBox)).first).dx;
    expect(slotEnd, tester.getTopRight(_field).dx + FrostGap.of(tester.element(_save)).hitInset);
  });

  testWidgets('the action before a plated one keeps one gap to the slot', (tester) async {
    await _pump(
      tester,
      _page(
        'Save',
        before: [FrostToolbarItem.action(icon: testIcons.delete, label: 'Discard', onPressed: () {})],
      ),
      1280,
    );
    final slot = tester.getTopLeft(find.ancestor(of: _save, matching: find.byType(SizedBox)).first).dx;
    expect(tester.getTopRight(_save).dx, tester.getTopRight(_field).dx);
    expect(tester.getTopRight(findFrostTooltip('Discard').last).dx, lessThanOrEqualTo(slot));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a plated action that moves to More leaves the row without overflow', (tester) async {
    await _pump(
      tester,
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(
            width: 40,
            child: FrostToolbar(
              title: const Text('A title that does not fit'),
              trailing: [
                FrostToolbarItem.custom(
                  minWidth: 72,
                  plated: true,
                  overflowEntry: FrostMenuAction('Save', onSelected: () {}),
                  builder: (context) => FrostButton.prominent(key: const ValueKey('save'), label: 'Save', onPressed: () {}),
                ),
              ],
            ),
          ),
        ),
      ),
      1280,
    );
    expect(_save, findsNothing);
    expect(findFrostTooltip('L.more').last, findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
