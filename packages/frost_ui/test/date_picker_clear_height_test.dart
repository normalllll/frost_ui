import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:material_ui/material_ui.dart';

import 'support.dart';

final _date = DateTime(2003, 12, 18);

Finder get _menu => find.byType(FrostPicker<int>);
Finder get _dateField => find.byType(FrostDatePicker);

class _Form extends StatelessWidget {
  const _Form({required this.value, required this.onChanged});
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;

  @override
  Widget build(BuildContext context) => Center(
    child: SizedBox(
      width: 360,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FrostPicker<int>.menu(
            label: 'Menu',
            value: 1,
            options: const [FrostPickerOption(value: 1, label: 'One')],
            onChanged: (_) {},
          ),
          FrostDatePicker(label: 'Date', value: value, showsYear: true, clearable: true, onChanged: onChanged),
        ],
      ),
    ),
  );
}

void main() {
  for (final density in [FrostDensity.comfortable, FrostDensity.compact]) {
    for (final platform in [TargetPlatform.windows, TargetPlatform.android]) {
      testWidgets('a clearable date field matches a menu field on $platform at ${density.name}', (tester) async {
        await tester.pumpWidget(
          frostTestApp(
            _Form(value: _date, onChanged: (_) {}),
            density: density,
            platform: platform,
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.getSize(_dateField).height, tester.getSize(_menu).height);
      });
    }
  }

  testWidgets('the field keeps its height when the value clears, and the clear button stays large enough', (tester) async {
    DateTime? value = _date;
    late StateSetter update;
    await tester.pumpWidget(
      frostTestApp(
        StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return _Form(value: value, onChanged: (next) => setState(() => value = next));
          },
        ),
        density: FrostDensity.comfortable,
        platform: TargetPlatform.android,
      ),
    );
    await tester.pumpAndSettle();
    final height = tester.getSize(_dateField).height;
    final clear = findFrostTooltip('L.clear');
    final target = tester.getSize(clear);
    expect(target.height, greaterThanOrEqualTo(44));
    expect(target.width, greaterThanOrEqualTo(32));

    await tester.tap(clear);
    await tester.pumpAndSettle();
    expect(value, isNull);
    expect(tester.getSize(_dateField).height, height);

    update(() => value = _date);
    await tester.pumpAndSettle();
    expect(tester.getSize(_dateField).height, height);
  });

  testWidgets('tapping the field beside the clear button still opens the calendar', (tester) async {
    DateTime? value = _date;
    await tester.pumpWidget(
      frostTestApp(
        _Form(value: value, onChanged: (next) => value = next),
        platform: TargetPlatform.android,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('2003'));
    await tester.pumpAndSettle();
    expect(find.text('December 2003'), findsOneWidget);
    expect(value, _date);
  });
}
