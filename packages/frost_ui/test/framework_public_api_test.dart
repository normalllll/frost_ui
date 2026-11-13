import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart' as frost;

// The prefix prevents flutter_test or another import from masking a missing
// barrel export. This fixture imports no Material/Cupertino library or helper.
void main() {
  test('appearance modes are Frost types', () {
    const appearance = frost.FrostAppearance(mode: frost.FrostThemeMode.dark, lightAccent: Color(0xff007aff), darkAccent: Color(0xff0a84ff));
    expect(appearance.mode, frost.FrostThemeMode.dark);
    expect(appearance.copyWith(mode: frost.FrostThemeMode.light).mode, frost.FrostThemeMode.light);
    expect(appearance.copyWith(mode: frost.FrostThemeMode.system).mode, frost.FrostThemeMode.system);
    expect(frost.FrostThemeMode.values.map((mode) => mode.name), ['system', 'light', 'dark']);
  });

  test('appearance records keep their stored mode names', () {
    final palettes = frost.FrostPalettes.pink;
    const appearance = frost.FrostAppearance(mode: frost.FrostThemeMode.dark, lightAccent: Color(0xff007aff), darkAccent: Color(0xff0a84ff));
    expect(appearance.toRecord()['mode'], 'dark');
    final restored = frost.FrostAppearance.fromRecord({...appearance.toRecord(), 'mode': 'light'}, palettes);
    expect(restored.mode, frost.FrostThemeMode.light);
    expect(frost.FrostAppearance.fromRecord(null, palettes, fallbackMode: frost.FrostThemeMode.dark).mode, frost.FrostThemeMode.dark);
  });


  test('editable input and key signatures need no Material import', () {
    const field = frost.FrostTextField(textInputAction: frost.TextInputAction.search);
    const shortcut = frost.FrostShortcut(frost.LogicalKeyboardKey.keyC, primary: true);
    expect(field.textInputAction, frost.TextInputAction.search);
    expect(shortcut, isNotNull);
  });

  test('time and date range values are records', () {
    const frost.FrostTimeOfDay time = (hour: 14, minute: 15);
    final frost.FrostDateRange range = (start: DateTime(2026, 10, 1), end: DateTime(2026, 10, 17));
    expect(time, (hour: 14, minute: 15));
    expect(range.end.difference(range.start).inDays, 16);
    final widgets = <Widget>[
      frost.FrostTimePicker(value: time, onChanged: (_) {}, label: 'Time'),
      frost.FrostDateRangePicker(value: range, onChanged: (_) {}, label: 'Range'),
    ];
    expect(widgets, hasLength(2));
  });

  testWidgets('tabs are driven by Frost controllers', (tester) async {
    final tabs = frost.FrostTabController(length: 2, vsync: const TestVSync());
    addTearDown(tabs.dispose);
    expect(tabs.index, 0);
    tabs.index = 1;
    expect(tabs.index, 1);
    late frost.FrostTabController inherited;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: frost.FrostDefaultTabController(
          length: 3,
          initialIndex: 2,
          child: Builder(
            builder: (context) {
              inherited = frost.FrostDefaultTabController.of(context);
              return const frost.FrostTabView(children: [SizedBox(), SizedBox(), SizedBox()]);
            },
          ),
        ),
      ),
    );
    expect(inherited.length, 3);
    expect(inherited.index, 2);
    late BuildContext outside;
    await tester.pumpWidget(
      Builder(
        builder: (context) {
          outside = context;
          return const SizedBox();
        },
      ),
    );
    expect(frost.FrostDefaultTabController.maybeOf(outside), isNull);
  });

  test('the barrel exports no Material library', () {
    final source = File('lib/frost_ui.dart').readAsStringSync();
    expect(source, isNot(contains('package:material_ui/')));
    expect(source, isNot(contains('package:cupertino_ui/')));
    expect(source, isNot(contains(RegExp(r'package:flutter/(material|cupertino)\.dart'))));
    expect(source, contains('package:flutter/services.dart'));
  });
}
