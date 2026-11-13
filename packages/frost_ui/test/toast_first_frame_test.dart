import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/controls/_toast_viewport.dart';
import 'package:material_ui/material_ui.dart';

import 'support.dart';

void main() {
  testWidgets('a notice that arrives before the host first lays out shows afterwards', (tester) async {
    final viewport = GlobalKey();
    await tester.pumpWidget(
      frostTestApp(
        TestOverlayRegion(
          child: FrostToastViewport(key: viewport, child: const SizedBox.expand()),
        ),
      ),
      phase: EnginePhase.build,
    );
    FrostToast.error('Failed');
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(find.text('Failed'), findsOneWidget);
    final rect = tester.getRect(find.text('Failed'));
    expect(rect.left, greaterThan(0));
    expect(rect.right, lessThanOrEqualTo(tester.getSize(find.byKey(viewport)).width));
  });

  testWidgets('a notice before the first layout without a viewport shows too', (tester) async {
    await tester.pumpWidget(frostTestApp(const SizedBox.expand()), phase: EnginePhase.build);
    FrostToast.error('Failed');
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(find.text('Failed'), findsOneWidget);
  });
}
