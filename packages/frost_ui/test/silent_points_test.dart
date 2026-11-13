import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:material_ui/material_ui.dart';

import 'support.dart';

void main() {
  testWidgets('a toast with no host reports through FlutterError', (tester) async {
    await tester.pumpWidget(const SizedBox());
    FrostToast.success('Saved');
    expect(tester.takeException(), isA<FlutterError>());
  });

  testWidgets('a plain Theme inside a Frost page is reported, not painted with other tokens', (tester) async {
    await tester.pumpWidget(frostTestApp(Theme(data: ThemeData.dark(), child: const FrostText('Hello'))));
    expect(tester.takeException(), isA<FlutterError>());
  });

  testWidgets('a plain MaterialApp without a Frost theme reports for a surface', (tester) async {
    await tester.pumpWidget(MaterialApp(theme: ThemeData.dark(), home: const FrostDivider()));
    expect(tester.takeException(), isA<FlutterError>());
  });

  for (final (name, value, percent) in [('0/0', 0.0 / 0.0, '0%'), ('half', .5, '50%'), ('over', 1.5, '100%')]) {
    testWidgets('progress of $name announces $percent', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        frostTestApp(
          Center(
            child: SizedBox(
              width: 200,
              child: FrostProgressBar(value: value, semanticLabel: 'Load'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.getSemantics(find.byType(FrostProgressBar)).value, percent);
      handle.dispose();
    });
  }

  testWidgets('a failed refresh is reported', (tester) async {
    await tester.pumpWidget(
      frostTestApp(
        FrostRefreshView(
          onRefresh: () async => throw StateError('offline'),
          builder: (_, physics, locators) => CustomScrollView(
            physics: physics,
            slivers: [
              ?locators.sliverHeader,
              const SliverToBoxAdapter(child: SizedBox(height: 2000, width: 300)),
            ],
          ),
        ),
        platform: TargetPlatform.android,
      ),
    );
    await tester.fling(find.byType(CustomScrollView), const Offset(0, 500), 2000);
    await tester.pump();
    await tester.pumpAndSettle(const Duration(milliseconds: 50));
    expect(tester.takeException(), isStateError);
  });
}
