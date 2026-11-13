import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:material_ui/material_ui.dart';

import 'support.dart';

final _date = DateTime(2003, 12, 18);
String get _text => const DefaultMaterialLocalizations().formatMediumDate(_date);

Finder get _clear => find.bySemanticsLabel('L.clear');

void main() {
  testWidgets('the clear button is announced and acts on its own', (tester) async {
    final handle = tester.ensureSemantics();
    final changes = <DateTime?>[];
    await tester.pumpWidget(frostTestApp(FrostDatePicker(label: 'Date', value: _date, clearable: true, onChanged: changes.add)));
    await tester.pumpAndSettle();

    expect(_clear, findsOneWidget);
    final clear = tester.getSemantics(_clear);
    expect(clear.getSemanticsData().flagsCollection.isButton, isTrue);
    clear.owner!.performAction(clear.id, SemanticsAction.tap);
    await tester.pump();
    expect(changes, [null]);
    handle.dispose();
  });

  testWidgets('the field still reads as one button with its value and opens the calendar', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(frostTestApp(FrostDatePicker(label: 'Date', value: _date, clearable: true, onChanged: (_) {})));
    await tester.pumpAndSettle();

    final field = tester.getSemantics(find.bySemanticsLabel(_text));
    expect(field.getSemanticsData().flagsCollection.isButton, isTrue);
    field.owner!.performAction(field.id, SemanticsAction.tap);
    await tester.pumpAndSettle();
    expect(find.text('December 2003'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('no clear button is announced without a value or when disabled', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(frostTestApp(FrostDatePicker(label: 'Date', value: null, clearable: true, onChanged: (_) {})));
    await tester.pumpAndSettle();
    expect(_clear, findsNothing);
    await tester.pumpWidget(frostTestApp(FrostDatePicker(label: 'Date', value: _date, clearable: true, onChanged: null)));
    await tester.pumpAndSettle();
    expect(_clear, findsNothing);
    handle.dispose();
  });

  testWidgets('a menu field keeps a single node for its value', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      frostTestApp(
        FrostPicker<int>.menu(
          label: 'Menu',
          value: 1,
          options: const [FrostPickerOption(value: 1, label: 'One')],
          onChanged: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel(RegExp('One')), findsOneWidget);
    handle.dispose();
  });
}
