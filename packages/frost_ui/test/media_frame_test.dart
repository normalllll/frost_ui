import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/media.dart';
import 'support.dart';

class ControlledImage extends ImageProvider<ControlledImage> {
  final completer = ControlledCompleter();
  @override
  Future<ControlledImage> obtainKey(ImageConfiguration configuration) => SynchronousFuture(this);
  @override
  ImageStreamCompleter loadImage(ControlledImage key, ImageDecoderCallback decode) => completer;
}

class ControlledCompleter extends ImageStreamCompleter {
  void chunk(int loaded, int? total) => reportImageChunkEvent(ImageChunkEvent(cumulativeBytesLoaded: loaded, expectedTotalBytes: total));
  void fail(Object error) => reportError(exception: error, silent: true);
  void complete(ImageInfo image) => setImage(image);
}

void main() {
  testWidgets('media child has configurable clip, aspect, physical inner stroke and semantics', (tester) async {
    final semantics = tester.ensureSemantics();
    for (final continuous in [true, false]) {
      await tester.pumpWidget(
        frostTestApp(
          FrostScope(
            config: testConfig.copyWith(continuousCorners: continuous),
            child: const Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 200,
                child: FrostMediaFrame(aspectRatio: 2, child: FrostMediaImage(child: Text('decorative child'))),
              ),
            ),
          ),
        ),
      );
      final frame = find.byType(FrostMediaFrame);
      expect(tester.getSize(frame), const Size(200, 100));
      expect(find.descendant(of: frame, matching: find.byType(continuous ? ClipRSuperellipse : ClipRRect)), findsOneWidget);
      final stroke = innerStrokes(tester, frame).single;
      expect(stroke.draws, 1);
      expect(stroke.color!.toARGB32(), FrostThemeTokens.of(tester.element(frame)).mediaInnerStroke.toARGB32());
      expect(stroke.width, closeTo(1 / tester.view.devicePixelRatio, 1e-6));
      expect(stroke.clipped, isFalse);
      expect(find.bySemanticsLabel('decorative child'), findsOneWidget);
      expect(find.descendant(of: frame, matching: find.byType(TweenAnimationBuilder<double>)), findsNothing);
    }
    await tester.pumpWidget(frostTestApp(const FrostMediaFrame(semanticLabel: 'Artwork', child: Text('ignored inner label'))));
    expect(find.bySemanticsLabel('Artwork'), findsOneWidget);
    expect(find.bySemanticsLabel('ignored inner label'), findsNothing);
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });

  testWidgets('image mode renders progress, default errors, then fades in actual pixels', (tester) async {
    final image = ControlledImage();
    double? lastProgress;
    await tester.pumpWidget(
      frostTestApp(
        SizedBox(
          width: 100,
          height: 80,
          child: FrostMediaFrame(
            image: image,
            placeholderBuilder: (context, progress) {
              lastProgress = progress;
              return const Text('loading');
            },
          ),
        ),
      ),
    );
    expect(find.text('loading'), findsOneWidget);
    expect(lastProgress, isNull);
    image.completer.chunk(1, 4);
    await tester.pump();
    expect(lastProgress, .25);
    image.completer.chunk(2, null);
    await tester.pump();
    expect(lastProgress, isNull);
    image.completer.complete(ImageInfo(image: (await tester.runAsync(() => createTestImage(width: 2, height: 2)))!));
    await tester.pump();
    // The placeholder stays under the fading image and leaves with the fade.
    expect(find.text('loading'), findsOneWidget);
    final fade = find.descendant(of: find.byType(FrostMediaFrame), matching: find.byType(Opacity));
    expect(tester.renderObject<RenderOpacity>(fade).opacity, 0);
    await tester.pump(FrostMotion.imageFade ~/ 2);
    expect(find.text('loading'), findsOneWidget);
    expect(tester.renderObject<RenderOpacity>(fade).opacity, allOf(greaterThan(0), lessThan(1)));
    await tester.pump(FrostMotion.imageFade);
    expect(tester.renderObject<RenderOpacity>(fade).opacity, 1);
    expect(find.text('loading'), findsNothing);
    final error = ControlledImage();
    await tester.pumpWidget(frostTestApp(SizedBox(width: 100, height: 80, child: FrostMediaFrame(image: error))));
    error.completer.fail(StateError('test image failure'));
    await tester.pump();
    expect(find.byType(FrostIcon), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion shows loaded image without a fade and custom error receives object', (tester) async {
    final image = ControlledImage();
    await tester.pumpWidget(
      frostTestApp(
        Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: SizedBox(width: 100, height: 80, child: FrostMediaFrame(image: image)),
          ),
        ),
      ),
    );
    image.completer.complete(ImageInfo(image: (await tester.runAsync(() => createTestImage(width: 2, height: 2)))!));
    await tester.pump();
    expect(find.descendant(of: find.byType(FrostMediaFrame), matching: find.byType(Opacity)), findsNothing);
    expect(find.descendant(of: find.byType(FrostMediaFrame), matching: find.byType(RawImage)), findsOneWidget);
    final error = ControlledImage();
    final failure = StateError('failure');
    Object? received;
    await tester.pumpWidget(
      frostTestApp(
        SizedBox(
          width: 100,
          height: 80,
          child: FrostMediaFrame(
            image: error,
            errorBuilder: (context, value) {
              received = value;
              return const Text('custom error');
            },
          ),
        ),
      ),
    );
    error.completer.fail(failure);
    await tester.pump();
    expect(received, same(failure));
    expect(find.text('custom error'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('warm cached frames are opaque immediately after remount', (tester) async {
    final image = ControlledImage();
    image.completer.complete(ImageInfo(image: (await tester.runAsync(() => createTestImage(width: 2, height: 2)))!));
    Future<void> mount() => tester.pumpWidget(frostTestApp(SizedBox(width: 100, height: 80, child: FrostMediaFrame(image: image))));
    await mount();
    expect(find.descendant(of: find.byType(FrostMediaFrame), matching: find.byType(Opacity)), findsNothing);
    await tester.pumpWidget(const SizedBox());
    expect(PaintingBinding.instance.imageCache.statusForKey(image).keepAlive, isTrue);
    await mount();
    expect(find.descendant(of: find.byType(FrostMediaFrame), matching: find.byType(Opacity)), findsNothing);
    final pixels = tester.widget<RawImage>(find.byType(RawImage));
    expect(pixels.image, isNotNull);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    PaintingBinding.instance.imageCache.clear();
  });

  test('media modes enforce exclusive sources and child-owned state', () {
    expect(() => FrostMediaFrame(), throwsAssertionError);
    expect(() => FrostMediaFrame(image: ControlledImage(), child: const SizedBox()), throwsAssertionError);
    expect(() => FrostMediaFrame(placeholderBuilder: (_, _) => const SizedBox(), child: const SizedBox()), throwsAssertionError);
    expect(() => FrostMediaFrame(errorBuilder: (_, _) => const SizedBox(), child: const SizedBox()), throwsAssertionError);
  });

  testWidgets('inner stroke is drawn once, unclipped, only after an image has produced a frame', (tester) async {
    Future<void> show(Widget frame) => tester.pumpWidget(
      frostTestApp(
        Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: 100, height: 80, child: frame),
        ),
      ),
    );
    final frame = find.byType(FrostMediaFrame);

    await show(FrostMediaFrame.skeleton(aspectRatio: 1.25));
    expect(innerStrokes(tester, frame).single.draws, 0);

    final image = ControlledImage();
    await show(FrostMediaFrame(image: image));
    expect(innerStrokes(tester, frame).single.draws, 0, reason: 'placeholder');
    image.completer.chunk(1, 4);
    await tester.pump();
    expect(innerStrokes(tester, frame).single.draws, 0, reason: 'loading progress');
    image.completer.complete(ImageInfo(image: (await tester.runAsync(() => createTestImage(width: 2, height: 2)))!));
    await tester.pump();
    final stroke = innerStrokes(tester, frame).single;
    expect(stroke.draws, 1);
    expect(stroke.clipped, isFalse);
    expect(stroke.width, closeTo(1 / tester.view.devicePixelRatio, 1e-6));
    await tester.pumpAndSettle();

    final error = ControlledImage();
    await show(FrostMediaFrame(image: error));
    error.completer.fail(StateError('test image failure'));
    await tester.pump();
    expect(find.byType(FrostIcon), findsOneWidget);
    expect(innerStrokes(tester, frame).single.draws, 0, reason: 'error placeholder');

    await show(const FrostMediaFrame(child: Text('plain child')));
    expect(innerStrokes(tester, frame).single.draws, 1, reason: 'plain child content is not pending');
    await show(const FrostMediaFrame(child: FrostMediaImage(child: Text('displayed'))));
    expect(innerStrokes(tester, frame).single.draws, 1);
    expect(tester.takeException(), isNull);
    PaintingBinding.instance.imageCache.clear();
  });

  testWidgets('a replaced image stays up until the new one has faded in over it', (tester) async {
    final first = ControlledImage(), second = ControlledImage();
    final firstPixels = (await tester.runAsync(() => createTestImage(width: 2, height: 2)))!;
    final secondPixels = (await tester.runAsync(() => createTestImage(width: 3, height: 3)))!;
    Widget frame(ImageProvider image) => frostTestApp(
      SizedBox(
        width: 100,
        height: 80,
        child: FrostMediaFrame(image: image, placeholderBuilder: (_, _) => const Text('loading')),
      ),
    );
    Iterable<int> shown() => tester.widgetList<RawImage>(find.byType(RawImage)).where((raw) => raw.image != null).map((raw) => raw.image!.width);

    await tester.pumpWidget(frame(first));
    first.completer.complete(ImageInfo(image: firstPixels));
    await tester.pumpAndSettle();
    expect(shown(), [2]);

    await tester.pumpWidget(frame(second));
    expect(find.text('loading'), findsNothing);
    expect(shown(), [2]);
    await tester.pump(const Duration(milliseconds: 500));
    expect(shown(), [2]);

    second.completer.complete(ImageInfo(image: secondPixels));
    await tester.pump();
    expect(shown(), [2, 3]);
    await tester.pump(FrostMotion.imageFade ~/ 2);
    expect(shown(), [2, 3]);
    await tester.pumpAndSettle();
    expect(shown(), [3]);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    PaintingBinding.instance.imageCache.clear();
  });

  testWidgets('the arriving image covers its placeholder every frame, which keeps its state', (tester) async {
    final image = ControlledImage();
    var mounts = 0;
    await tester.pumpWidget(
      frostTestApp(
        ColoredBox(
          color: const Color(0xFFFF00FF),
          child: Center(
            child: SizedBox(
              width: 100,
              height: 80,
              child: FrostMediaFrame(image: image, placeholderBuilder: (_, _) => _CountingPlaceholder(onMount: () => mounts++)),
            ),
          ),
        ),
      ),
    );
    image.completer.chunk(1, 4);
    await tester.pump();
    expect(mounts, 1);
    image.completer.complete(ImageInfo(image: (await tester.runAsync(() => createTestImage(width: 2, height: 2)))!));
    await tester.pump();
    final frame = find.byType(FrostMediaFrame);
    double coverage() {
      final image = tester.renderObject<RenderOpacity>(find.descendant(of: frame, matching: find.byType(Opacity))).opacity;
      final under = find.descendant(of: frame, matching: find.byType(FadeTransition));
      final underlay = under.evaluate().isEmpty ? 0.0 : tester.widget<FadeTransition>(under.first).opacity.value;
      return image + underlay * (1 - image);
    }

    for (var elapsed = Duration.zero; elapsed <= FrostMotion.imageFade * 2; elapsed += const Duration(milliseconds: 8)) {
      expect(coverage(), 1, reason: 'at $elapsed');
      await tester.pump(const Duration(milliseconds: 8));
    }
    expect(find.byType(_CountingPlaceholder), findsNothing);
    expect(mounts, 1, reason: 'the placeholder moved under the image without remounting');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    PaintingBinding.instance.imageCache.clear();
  });

  testWidgets('rebuilding with an equal provider does not replay the fade', (tester) async {
    final completer = ControlledCompleter();
    final pixels = (await tester.runAsync(() => createTestImage(width: 2, height: 2)))!;
    Widget frame() => frostTestApp(SizedBox(width: 100, height: 80, child: FrostMediaFrame(image: _EqualImage(completer))));
    await tester.pumpWidget(frame());
    completer.complete(ImageInfo(image: pixels));
    await tester.pumpAndSettle();
    await tester.pumpWidget(frame());
    final fade = find.descendant(of: find.byType(FrostMediaFrame), matching: find.byType(Opacity));
    expect(tester.renderObject<RenderOpacity>(fade).opacity, 1);
    await tester.pumpWidget(const SizedBox());
    PaintingBinding.instance.imageCache.clear();
  });
}

class _EqualImage extends ImageProvider<_EqualImage> {
  _EqualImage(this.completer);
  final ControlledCompleter completer;
  @override
  Future<_EqualImage> obtainKey(ImageConfiguration configuration) => SynchronousFuture(this);
  @override
  ImageStreamCompleter loadImage(_EqualImage key, ImageDecoderCallback decode) => completer;
  @override
  bool operator ==(Object other) => other is _EqualImage && other.completer == completer;
  @override
  int get hashCode => completer.hashCode;
}

class _CountingPlaceholder extends StatefulWidget {
  const _CountingPlaceholder({required this.onMount});
  final VoidCallback onMount;
  @override
  State<_CountingPlaceholder> createState() => _CountingPlaceholderState();
}

class _CountingPlaceholderState extends State<_CountingPlaceholder> {
  @override
  void initState() {
    super.initState();
    widget.onMount();
  }

  @override
  Widget build(BuildContext context) => const ColoredBox(color: Color(0xFF00FF00), child: SizedBox.expand());
}
