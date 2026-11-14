import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/primitives/_click_feedback.dart' show FrostInteractionDecoration;
import 'package:frost_ui/src/surface/_window_background.dart';
import 'package:material_ui/material_ui.dart';

import 'support.dart';

class _Counted extends StatelessWidget {
  const _Counted(this.onBuild);
  final VoidCallback onBuild;
  @override
  Widget build(BuildContext context) {
    onBuild();
    return const Text('Label');
  }
}

void main() {
  testWidgets('a fading window background recolours a button without building its content again', (tester) async {
    final fade = ValueNotifier<({Color background, double weight})?>((background: const Color(0xFFF0F0F0), weight: 0));
    addTearDown(fade.dispose);
    var builds = 0;
    await tester.pumpWidget(
      frostTestApp(
        FrostWindowBackgroundScope(
          hasAmbient: true,
          fade: fade,
          child: Center(
            child: FrostButton(label: 'Label', labelWidget: _Counted(() => builds++), onPressed: () {}),
          ),
        ),
        brightness: Brightness.dark,
      ),
    );
    await tester.pumpAndSettle();
    final built = builds;
    Color fill() => (tester.widget<FrostInteractionDecoration>(find.byType(FrostInteractionDecoration).first).decoration as ShapeDecoration).color!;
    final before = fill();
    for (final weight in [.25, .5, .75, 1.0]) {
      fade.value = (background: const Color(0xFFF0F0F0), weight: weight);
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(fill(), isNot(before), reason: 'the fill follows the window background');
    expect(builds, built, reason: 'only the fill was built again');
    expect(tester.takeException(), isNull);
  });

  testWidgets('covering and uncovering a page does not build its resting controls again', (tester) async {
    var builds = 0, enabled = true;
    late StateSetter update;
    final button = FrostButton(label: 'Label', labelWidget: _Counted(() => builds++), onPressed: () {});
    await tester.pumpWidget(
      frostTestApp(
        StatefulBuilder(
          builder: (context, set) {
            update = set;
            return TickerMode(
              enabled: enabled,
              child: Center(child: button),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    final built = builds;
    for (final next in [false, true, false, true]) {
      update(() => enabled = next);
      await tester.pump();
      await tester.pump();
    }
    expect(builds, built);
    expect(tester.takeException(), isNull);
  });
}
