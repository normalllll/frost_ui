import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/media.dart';

import 'media_test_image.dart';
import 'support.dart';

void main() {
  const mediaKey = ValueKey('pixels');
  Widget stage(double ratio) => FrostMediaStage(
    aspectRatio: ratio,
    child: const SizedBox.expand(key: mediaKey),
  );
  for (final ratio in [2.0, .75, 1080 / 1915, .2]) {
    testWidgets('finite stage fills an axis for $ratio without extra surfaces', (tester) async {
      await tester.pumpWidget(frostTestApp(Center(child: SizedBox(width: 600, height: 400, child: stage(ratio)))));
      final rect = tester.getRect(find.byKey(mediaKey));
      expect(rect.width / rect.height, closeTo(ratio, .00001));
      expect(rect.width == 600 || rect.height == 400, isTrue);
      expect(find.byType(FrostMediaFrame), findsNothing);
      expect(tester.takeException(), isNull);
    });
    testWidgets('unbounded natural stage preserves full height for $ratio', (tester) async {
      await tester.pumpWidget(frostTestApp(SizedBox(width: 390, child: SingleChildScrollView(child: stage(ratio)))));
      final size = tester.getSize(find.byKey(mediaKey));
      expect(size.height, closeTo(size.width / ratio, .00001));
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('one media stroke also owns nested placeholder and skeleton radius forwards', (tester) async {
    const placeholder = FrostMediaFrame(radius: 0, child: FrostMediaFrame(radius: 0, child: SizedBox.expand()));
    await tester.pumpWidget(frostTestApp(const Center(child: SizedBox(width: 200, height: 300, child: placeholder))));
    // Only the outer frame owns a stroke; plain content is not pending.
    expect(innerStrokes(tester, find.byType(FrostMediaFrame).first).map((s) => s.draws), [1]);
    const nested = FrostMediaFrame(
      radius: 0,
      child: FrostMediaFrame(radius: 0, child: FrostMediaImage(child: SizedBox.expand())),
    );
    await tester.pumpWidget(frostTestApp(const Center(child: SizedBox(width: 200, height: 300, child: nested))));
    expect(innerStrokes(tester, find.byType(FrostMediaFrame).first).map((s) => s.draws), [1]);
    final skeleton = FrostMediaFrame.skeleton(aspectRatio: null, radius: 0);
    await tester.pumpWidget(frostTestApp(Center(child: SizedBox(width: 200, height: 300, child: skeleton))));
    final frames = tester.widgetList<FrostMediaFrame>(find.byType(FrostMediaFrame));
    expect(frames.every((frame) => frame.radius == 0), isTrue);
    expect(tester.takeException(), isNull);
  });

  test('invalid aspect ratios assert', () {
    for (final ratio in [0.0, -1.0, double.nan, double.infinity]) {
      expect(() => stage(ratio), throwsAssertionError);
    }
  });
  testWidgets('decoded ratio redirects the standard spring and retains child state', (tester) async {
    Widget app(double ratio, {bool reduced = false}) => frostTestApp(
      MediaQuery(
        data: MediaQueryData(disableAnimations: reduced),
        child: Center(child: SizedBox(width: 400, height: 500, child: stage(ratio))),
      ),
    );
    await tester.pumpWidget(app(2));
    final element = tester.element(find.byKey(mediaKey));
    expect(tester.getSize(find.byKey(mediaKey)), const Size(400, 200));
    await tester.pumpWidget(app(.8));
    await tester.pump(const Duration(milliseconds: 80));
    final intermediate = tester.getSize(find.byKey(mediaKey)).height;
    expect(intermediate, greaterThan(200));
    expect(intermediate, lessThan(500));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byKey(mediaKey)), const Size(400, 500));
    expect(tester.element(find.byKey(mediaKey)), same(element));
    await tester.pumpWidget(app(2, reduced: true));
    expect(tester.getSize(find.byKey(mediaKey)), const Size(400, 200));
  });
  testWidgets('Hero follows stage ratio instead of stale source metadata', (tester) async {
    final tag = FrostMediaHeroTag(image: mediaTestImage, aspectRatio: 2);
    await tester.pumpWidget(
      frostTestApp(
        Center(
          child: SizedBox(
            width: 400,
            height: 500,
            child: FrostMediaStage(
              aspectRatio: .8,
              child: FrostMediaHero(
                tag: tag,
                fit: BoxFit.contain,
                child: const SizedBox.expand(key: mediaKey),
              ),
            ),
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byKey(mediaKey)), const Size(400, 500));
    expect(tag.aspectRatio, 2);
    expect(tester.takeException(), isNull);
  });
}
