import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/media.dart';
import 'package:frost_ui/src/primitives/_media_image_registry.dart';

import 'media_frame_test.dart' show ControlledImage;
import 'support.dart';

Future<ImageInfo> _decoded(WidgetTester tester) async => ImageInfo(image: (await tester.runAsync(() => createTestImage(width: 2, height: 2)))!);

void main() {
  Future<void> show(WidgetTester tester, Widget child) => tester.pumpWidget(
    frostTestApp(
      Align(
        alignment: Alignment.topLeft,
        child: SizedBox(width: 100, height: 80, child: child),
      ),
    ),
  );

  testWidgets('plain content gets the stroke: a frame, an initials avatar and a thumbnail with any widget', (tester) async {
    await show(tester, const FrostMediaFrame(child: ColoredBox(color: Colors.red)));
    expect(innerStrokes(tester, find.byType(FrostMediaFrame)).single.draws, 1);
    await show(tester, const FrostAvatar(semanticLabel: 'User'));
    expect(innerStrokes(tester, find.byType(FrostAvatar)).single.draws, 1);
    await show(
      tester,
      const FrostThumbnail(
        image: ColoredBox(color: Colors.red),
        semanticLabel: 'Preview',
      ),
    );
    expect(innerStrokes(tester, find.byType(FrostThumbnail)).single.draws, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an image that has not produced a frame, or failed, gets no stroke; a loaded one does', (tester) async {
    final image = ControlledImage();
    await show(
      tester,
      FrostThumbnail(
        image: FrostMediaFrame(image: image),
        semanticLabel: 'Preview',
      ),
    );
    final thumbnail = find.byType(FrostThumbnail);
    expect(innerStrokes(tester, thumbnail).single.draws, 0, reason: 'loading');
    image.completer.complete(await _decoded(tester));
    await tester.pump();
    expect(innerStrokes(tester, thumbnail).single.draws, 1, reason: 'loaded');
    await tester.pumpAndSettle();

    final error = ControlledImage();
    await show(
      tester,
      FrostThumbnail(
        image: FrostMediaFrame(image: error),
        semanticLabel: 'Preview',
      ),
    );
    error.completer.fail(StateError('test image failure'));
    await tester.pump();
    expect(innerStrokes(tester, thumbnail).single.draws, 0, reason: 'error placeholder');

    await show(tester, FrostMediaFrame.skeleton(aspectRatio: 1.25));
    expect(innerStrokes(tester, find.byType(FrostMediaFrame)).single.draws, 0, reason: 'skeleton');
    PaintingBinding.instance.imageCache.clear();
  });

  testWidgets('mid-fade the stroke alpha is proportional to the image opacity', (tester) async {
    final image = ControlledImage();
    await show(tester, FrostMediaFrame(image: image));
    final frame = find.byType(FrostMediaFrame);
    final base = innerStrokes(tester, frame).single.color!.a;
    image.completer.complete(await _decoded(tester));
    await tester.pump();
    final fade = find.descendant(of: frame, matching: find.byType(Opacity));
    expect(tester.renderObject<RenderOpacity>(fade).opacity, 0);
    expect(innerStrokes(tester, frame).single.drawn!.a, closeTo(0, 1e-3));
    await tester.pump(FrostMotion.imageFade ~/ 3);
    final opacity = tester.renderObject<RenderOpacity>(fade).opacity;
    expect(opacity, inExclusiveRange(0, 1));
    expect(innerStrokes(tester, frame).single.drawn!.a, closeTo(base * opacity, 2 / 255));
    await tester.pumpAndSettle();
    expect(innerStrokes(tester, frame).single.drawn!.a, closeTo(base, 2 / 255));
    PaintingBinding.instance.imageCache.clear();
  });

  testWidgets('a keyed image moved between two scopes re-registers with the new owner', (tester) async {
    final first = FrostMediaImageRegistry(), second = FrostMediaImageRegistry();
    addTearDown(first.dispose);
    addTearDown(second.dispose);
    final displayed = GlobalKey(), pending = GlobalKey();
    Widget scoped(FrostMediaImageRegistry registry, Widget? child) => FrostMediaImageRegistryScope(registry: registry, child: child ?? const SizedBox());
    Widget host({required bool inFirst}) {
      final image = FrostMediaImage(key: displayed, child: const SizedBox());
      final waiting = FrostMediaImagePending(key: pending, child: const SizedBox());
      return Column(
        children: [
          scoped(first, inFirst ? Column(children: [image, waiting]) : null),
          scoped(second, inFirst ? null : Column(children: [image, waiting])),
        ],
      );
    }

    await tester.pumpWidget(host(inFirst: true));
    expect((first.hasImages, first.hasPending, second.hasImages, second.hasPending), (true, true, false, false));
    await tester.pumpWidget(host(inFirst: false));
    expect((first.hasImages, first.hasPending, second.hasImages, second.hasPending), (false, false, true, true));
    await tester.pumpWidget(const SizedBox());
    expect((second.hasImages, second.hasPending), (false, false));
  });

  testWidgets('a card scope forwards pending images to the frame that owns the stroke', (tester) async {
    final image = ControlledImage();
    await tester.pumpWidget(
      frostTestApp(
        Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 100,
            child: FrostMediaCard(
              aspectRatio: 1,
              media: FrostMediaFrame(image: image),
              onPressed: () {},
            ),
          ),
        ),
      ),
    );
    final card = find.byType(FrostMediaCard);
    expect(innerStrokes(tester, card).where((s) => s.draws > 0), isEmpty);
    image.completer.complete(await _decoded(tester));
    await tester.pumpAndSettle();
    expect(innerStrokes(tester, card).where((s) => s.draws > 0), hasLength(1));
    PaintingBinding.instance.imageCache.clear();
  });
}
