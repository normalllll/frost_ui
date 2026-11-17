import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/media.dart';

import 'support.dart';

Color _painted(WidgetTester tester) =>
    tester.widget<ColoredBox>(find.descendant(of: find.byType(FrostMediaBlackStage), matching: find.byType(ColoredBox))).color;

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('paints opaque black in ${brightness.name}', (tester) async {
      await tester.pumpWidget(frostTestApp(const FrostMediaBlackStage(), brightness: brightness));
      expect(_painted(tester), const Color(0xFF000000));
      expect(tester.getSize(find.byType(FrostMediaBlackStage)), tester.view.physicalSize / tester.view.devicePixelRatio);
    });
  }

  testWidgets('paints opaque black in high contrast', (tester) async {
    await tester.pumpWidget(
      frostTestApp(
        Builder(
          builder: (context) => MediaQuery(data: MediaQuery.of(context).copyWith(highContrast: true), child: const FrostMediaBlackStage()),
        ),
      ),
    );
    expect(_painted(tester), const Color(0xFF000000));
  });

  testWidgets('fills a media viewport background', (tester) async {
    await tester.pumpWidget(
      frostTestApp(
        const Center(
          child: SizedBox(
            width: 300,
            height: 200,
            child: FrostMediaViewport(background: FrostMediaBlackStage(), child: SizedBox(width: 50, height: 50)),
          ),
        ),
      ),
    );
    expect(_painted(tester), const Color(0xFF000000));
    expect(tester.getSize(find.byType(FrostMediaBlackStage)), const Size(300, 200));
  });
}
