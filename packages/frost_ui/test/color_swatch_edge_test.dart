import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/foundation/color_math.dart' show colorContrast;
import 'package:material_ui/material_ui.dart';

import 'support.dart';

const _white = Color(0xFFFFFFFF), _night = Color(0xFF1C1F24), _black = Color(0xFF000000), _accent = Color(0xFFE5484D);

Widget _palette(int value, {required bool solid}) {
  final panel = FrostSurface(
    role: FrostSurfaceRole.overlay,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: FrostPicker<int>.palette(
        label: 'Theme',
        value: value,
        onChanged: (_) {},
        options: const [
          FrostPickerOption(value: 0, label: 'White', color: _white),
          FrostPickerOption(value: 1, label: 'Night', color: _night),
          FrostPickerOption(value: 2, label: 'Black', color: _black),
          FrostPickerOption(value: 3, label: 'Red', color: _accent),
        ],
      ),
    ),
  );
  return Center(child: solid ? FrostSolidMaterial(child: panel) : panel);
}

BoxDecoration _disc(WidgetTester tester, String label) => tester
    .widgetList<DecoratedBox>(find.descendant(of: find.bySemanticsLabel(label), matching: find.byType(DecoratedBox)))
    .map((box) => box.decoration)
    .whereType<BoxDecoration>()
    .firstWhere((decoration) => decoration.shape == BoxShape.circle);

Color _ground(WidgetTester tester, String label) => FrostSurfaceScope.maybeOf(tester.element(find.bySemanticsLabel(label)))!.background;

/// The colour that sets the swatch apart from the surface: its edge if it has
/// one, its fill otherwise.
Color _boundary(WidgetTester tester, String label) {
  final disc = _disc(tester, label);
  return (disc.border as Border?)?.top.color ?? disc.color!;
}

void main() {
  for (final brightness in Brightness.values) {
    for (final solid in [true, false]) {
      testWidgets('every swatch stands out from the panel it lies on, $brightness, solid $solid', (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(frostTestApp(_palette(3, solid: solid), brightness: brightness, platform: TargetPlatform.android));
        await tester.pumpAndSettle();
        for (final label in ['White', 'Night', 'Black', 'Red']) {
          final ground = _ground(tester, label);
          expect(colorContrast(_boundary(tester, label), ground), greaterThanOrEqualTo(3), reason: '$label on $ground');
        }
        expect(_disc(tester, 'Red').border, isNull, reason: 'a colour that already contrasts keeps its plain disc');
      });
    }
  }

  testWidgets('a selected swatch close to the surface keeps its edge and shows its ring', (tester) async {
    await tester.pumpWidget(frostTestApp(_palette(1, solid: true), brightness: Brightness.dark));
    await tester.pumpAndSettle();
    expect(colorContrast(_boundary(tester, 'Night'), _ground(tester, 'Night')), greaterThanOrEqualTo(3));
    double ring(String label) => tester
        .widgetList<AnimatedOpacity>(find.descendant(of: find.bySemanticsLabel(label), matching: find.byType(AnimatedOpacity)))
        .last
        .opacity;
    expect(ring('Night'), 1);
    expect(ring('Black'), 0);
  });
}
