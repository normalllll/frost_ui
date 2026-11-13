import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/controls/_choice_mark.dart';
import 'package:material_ui/material_ui.dart';

import 'support.dart';

Finder get _mark => find.byType(FrostChoiceMark);
Finder get _rowFill => find.descendant(of: find.byType(FrostCheckboxRow), matching: find.byType(AnimatedContainer)).first;

Future<void> _openDialog(WidgetTester tester, WidgetBuilder content) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(900, 700);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    frostTestApp(
      Builder(
        builder: (context) => Center(
          child: FrostButton(
            label: 'Open',
            onPressed: () => showFrostDialog<void>(
              context: context,
              builder: (context) => FrostDialog(title: 'Push', content: content(context)),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

class _Push extends StatefulWidget {
  const _Push();
  @override
  State<_Push> createState() => _PushState();
}

class _PushState extends State<_Push> {
  var upstream = true;
  @override
  Widget build(BuildContext context) => FrostFormSection(
    children: [
      const FrostTextField(label: 'Remote'),
      FrostCheckboxRow(title: 'Set as upstream after pushing', value: upstream, onChanged: (value) => setState(() => upstream = value!)),
      const FrostTextField(label: 'Target branch'),
    ],
  );
}

void main() {
  testWidgets('in a form column the mark sits on the field edge and the text follows it', (tester) async {
    await _openDialog(tester, (_) => const _Push());
    final field = tester.getRect(find.byType(FrostTextField).first);
    final below = tester.getRect(find.byType(FrostTextField).last);
    final mark = tester.getRect(_mark);
    final text = tester.getRect(find.text('Set as upstream after pushing'));
    expect(mark.left, field.left);
    expect(below.left, field.left);
    // The text keeps its place after the 28-point icon column and the row gap.
    expect(text.left, mark.left + 28 + FrostGap.related);
    // The hover and press fill reaches outside the field edges into the dialog padding.
    final fill = tester.getRect(_rowFill);
    expect(fill.left, lessThan(field.left));
    expect(fill.right, greaterThan(field.right));
    // The row still toggles as a whole.
    await tester.tap(find.text('Set as upstream after pushing'));
    await tester.pump();
    expect(tester.widget<FrostCheckboxRow>(find.byType(FrostCheckboxRow)).value, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('right-to-left forms mirror the edge', (tester) async {
    await _openDialog(tester, (_) => const Directionality(textDirection: TextDirection.rtl, child: _Push()));
    expect(tester.getRect(_mark).right, tester.getRect(find.byType(FrostTextField).first).right);
  });

  testWidgets('outside a form a dialog column keeps the list-row inset', (tester) async {
    await _openDialog(
      tester,
      (_) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const FrostTextField(label: 'Remote'),
          FrostCheckboxRow(title: 'Choice', value: true, onChanged: (_) {}),
        ],
      ),
    );
    final mark = tester.getRect(_mark);
    expect(mark.left, tester.getRect(find.byType(FrostTextField)).left + FrostGap.rowInset + (28 - mark.width) / 2);
  });

  testWidgets('a grouped section keeps its row inset', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(900, 700);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      frostTestApp(
        FrostFormSection(
          children: [
            FrostGroupedSection(children: [FrostCheckboxRow(title: 'General', value: true, onChanged: (_) {})]),
          ],
        ),
      ),
    );
    final section = tester.getRect(find.byType(FrostGroupedSection));
    expect(tester.getRect(_mark).left, greaterThanOrEqualTo(section.left + FrostGap.rowInset - 4));
  });

  testWidgets('semantics stay one checked node', (tester) async {
    final semantics = tester.ensureSemantics();
    await _openDialog(tester, (_) => const _Push());
    expect(
      tester.getSemantics(find.byType(FrostCheckboxRow)),
      matchesSemantics(label: 'Set as upstream after pushing', hasCheckedState: true, isChecked: true, hasEnabledState: true, isEnabled: true, hasTapAction: true),
    );
    semantics.dispose();
  });
}
