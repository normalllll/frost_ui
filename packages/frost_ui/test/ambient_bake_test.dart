import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/foundation/_ambient_material.dart';

import 'ambient_material_test.dart' show settleGlow;
import 'ambient_transition_test.dart' show complete, pixels;
import 'media_frame_test.dart' show ControlledImage;
import 'support.dart';

FrostAmbientGlowBakes get _bakes => FrostAmbientGlowBakes.instance;

// Distinct bakes differ by width, which also names them to the runner below.
FrostAmbientGlowBake _bake(int id) => (
  width: id,
  height: 1,
  scale: 1,
  canvas: const [0.2, 0, 0],
  canvasRgb: const [10, 10, 10],
  cap: .8,
  dither: false,
  lift: .1,
  freeLift: .1,
  cards: const [],
  radius: 10,
  glows: const [],
);

Future<ui.Image> _image() async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawColor(Colors.red, BlendMode.src);
  final picture = recorder.endRecording();
  final image = await picture.toImage(1, 1);
  picture.dispose();
  return image;
}

class _Runner {
  _Runner() {
    _bakes.debugRunner = (bake) {
      final completer = Completer<ui.Image>();
      started.add(bake.width);
      running[bake.width] = completer;
      return completer.future;
    };
  }
  final started = <int>[];
  final running = <int, Completer<ui.Image>>{};
  ui.Image? last;

  Future<void> finish(int id) async {
    await pumpEventQueue();
    last = await _image();
    running.remove(id)!.complete(last);
    await pumpEventQueue();
  }
}

class _MemoryImage extends ImageProvider<_MemoryImage> {
  _MemoryImage(this.bytes);
  final Uint8List bytes;
  @override
  Future<_MemoryImage> obtainKey(ImageConfiguration configuration) => SynchronousFuture(this);
  @override
  ImageStreamCompleter loadImage(_MemoryImage key, ImageDecoderCallback decode) => OneFrameImageStreamCompleter(_load(decode));
  Future<ImageInfo> _load(ImageDecoderCallback decode) async {
    final codec = await decode(await ui.ImmutableBuffer.fromUint8List(bytes));
    final frame = await codec.getNextFrame();
    codec.dispose();
    return ImageInfo(image: frame.image);
  }
}

Future<_MemoryImage> _solid(WidgetTester tester, Color color) async => (await tester.runAsync(() async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(const Rect.fromLTWH(0, 0, 32, 32), Paint()..color = color);
  final picture = recorder.endRecording();
  final image = await picture.toImage(32, 32);
  final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
  image.dispose();
  picture.dispose();
  return _MemoryImage(bytes);
}))!;

Finder get _paint => find.byWidgetPredicate((w) => w.runtimeType.toString() == '_AmbientPaint');

int _saveLayers(RenderObject render) {
  final canvas = TestRecordingCanvas();
  render.paint(TestRecordingPaintingContext(canvas), Offset.zero);
  return canvas.invocations.where((call) => call.invocation.memberName == #saveLayer).length;
}

class _Fading implements FrostAmbientFading {
  _Fading(this.startWeight);
  @override
  double startWeight;
  bool disposed = false;
  @override
  void dispose() => disposed = true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => _bakes.debugReset());
  tearDown(() => _bakes.debugReset());

  group('one bake at a time', () {
    test('at most one bake runs however many owners ask, and each owner is served', () async {
      final runner = _Runner();
      final results = [for (var id = 1; id <= 4; id++) _bakes.request(Object(), _bake(id))];
      await pumpEventQueue();
      expect(runner.started, [1]);
      for (final id in [1, 2, 3, 4]) {
        await runner.finish(id);
        expect(runner.running.length, lessThanOrEqualTo(1));
      }
      expect(_bakes.debugPeakRunning, 1);
      for (final result in results) {
        (await result)!.dispose();
      }
    });

    test('a newer request replaces the waiting one, which never runs', () async {
      final runner = _Runner();
      final owner = Object();
      final first = _bakes.request(owner, _bake(1));
      final replaced = _bakes.request(owner, _bake(2));
      final latest = _bakes.request(owner, _bake(3));
      await pumpEventQueue();
      await runner.finish(1);
      await runner.finish(3);
      expect(runner.started, [1, 3]);
      expect(await replaced, isNull);
      expect(await first, isNull);
      (await latest)!.dispose();
    });

    test('a result nobody waits for any more is dropped without being cached', () async {
      final runner = _Runner();
      final owner = Object();
      final stale = _bakes.request(owner, _bake(1));
      final latest = _bakes.request(owner, _bake(2));
      await runner.finish(1);
      expect(await stale, isNull);
      expect(runner.last!.debugDisposed, isTrue);
      expect(_bakes.cached(_bake(1)), isNull);
      expect(runner.started, [1, 2]);
      await runner.finish(2);
      (await latest)!.dispose();
    });

    test('a cancelled request does not run', () async {
      final runner = _Runner();
      final owner = Object();
      final running = _bakes.request(Object(), _bake(1));
      final waiting = _bakes.request(owner, _bake(2));
      _bakes.cancel(owner);
      await runner.finish(1);
      expect(runner.started, [1]);
      expect(await waiting, isNull);
      (await running)!.dispose();
    });

    test('asking again for the running field joins it', () async {
      final runner = _Runner();
      final owner = Object();
      final first = _bakes.request(owner, _bake(1));
      final other = _bakes.request(owner, _bake(2));
      final again = _bakes.request(owner, _bake(1));
      await runner.finish(1);
      expect(runner.started, [1]);
      expect(await first, isNull);
      expect(await other, isNull);
      (await again)!.dispose();
    });

    test('a failed bake reports to its owner and frees the slot', () async {
      final runner = _Runner();
      final failed = _bakes.request(Object(), _bake(1));
      final next = _bakes.request(Object(), _bake(2));
      final outcome = expectLater(failed, throwsStateError);
      await pumpEventQueue();
      runner.running.remove(1)!.completeError(StateError('bake failed'));
      await outcome;
      await runner.finish(2);
      (await next)!.dispose();
    });
  });

  group('reusing results', () {
    test('the same field is not baked twice, and every owner gets its own handle', () async {
      final runner = _Runner();
      final first = _bakes.request(Object(), _bake(1));
      await runner.finish(1);
      final a = (await first)!;
      final second = _bakes.request(Object(), _bake(1));
      await pumpEventQueue();
      expect(runner.started, [1]);
      if (runner.running.containsKey(1)) await runner.finish(1);
      final b = (await second)!;
      final c = _bakes.cached(_bake(1))!;
      expect(a.isCloneOf(b) && b.isCloneOf(c), isTrue);
      a.dispose();
      expect(b.debugDisposed, isFalse);
      b.dispose();
      c.dispose();
    });

    test('evicted images are disposed, and the cache stays bounded', () async {
      final runner = _Runner();
      Future<void> bake(int id) async {
        final result = _bakes.request(Object(), _bake(id));
        await runner.finish(id);
        (await result)!.dispose();
      }

      await bake(1);
      final oldest = _bakes.debugCachedImages.first;
      for (var id = 2; id <= 40; id++) {
        await bake(id);
      }
      expect(oldest.debugDisposed, isTrue);
      expect(_bakes.debugCachedImages.length, lessThanOrEqualTo(8));
      expect(_bakes.debugCachedImages.every((image) => !image.debugDisposed), isTrue);
    });

    test('a field in use outlives its eviction', () async {
      final runner = _Runner();
      final first = _bakes.request(Object(), _bake(1));
      await runner.finish(1);
      final held = (await first)!;
      for (var id = 2; id <= 40; id++) {
        final result = _bakes.request(Object(), _bake(id));
        await runner.finish(id);
        (await result)!.dispose();
      }
      expect(held.debugDisposed, isFalse);
      held.dispose();
    });
  });

  test('fading endpoints stay bounded: the faintest go and the rest keep their proportions', () {
    final frames = [_Fading(.5), _Fading(.02), _Fading(.08), _Fading(.4)];
    final faint = frames.sublist(1, 3);
    frostAmbientBoundFading(frames);
    expect(frames.length, 2);
    expect(faint.every((frame) => frame.disposed), isTrue);
    expect(frames.map((frame) => frame.startWeight).reduce((a, b) => a + b), closeTo(1, 1e-9));
    expect(frames[0].startWeight / frames[1].startWeight, closeTo(.5 / .4, 1e-9));
    final kept = [_Fading(.6), _Fading(.4)];
    frostAmbientBoundFading(kept);
    expect(kept.map((frame) => frame.startWeight), [.6, .4]);
  });

  group('window backdrop', () {
    void smallWindow(WidgetTester tester) {
      tester.view.physicalSize = const Size(180, 120);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }

    testWidgets('a new image begins while cards move every frame, without baking per move', (tester) async {
      smallWindow(tester);
      final first = ControlledImage(), second = ControlledImage();
      ImageProvider image = first;
      final top = ValueNotifier(50.0);
      final key = GlobalKey();
      late StateSetter update;
      await tester.pumpWidget(
        frostTestApp(
          StatefulBuilder(
            builder: (_, set) {
              update = set;
              return RepaintBoundary(
                key: key,
                child: FrostAmbientBackdropHost(
                  image: image,
                  child: ValueListenableBuilder(
                    valueListenable: top,
                    builder: (_, value, _) => Stack(
                      children: [
                        Positioned(
                          left: 40,
                          top: value,
                          width: 20,
                          height: 10,
                          child: const FrostSurface(role: FrostSurfaceRole.module, child: SizedBox.expand()),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          brightness: Brightness.dark,
        ),
      );
      await complete(tester, first, Colors.purple);
      await settleGlow(tester);
      final before = await pixels(tester, key);
      final bakesBefore = _bakes.debugStarted;
      update(() => image = second);
      await tester.pump();
      await complete(tester, second, Colors.green);
      for (var frame = 0; frame < 160; frame++) {
        top.value = 50 + (frame % 40).toDouble();
        await tester.pump(const Duration(milliseconds: 16));
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5)));
      }
      expect(await pixels(tester, key), isNot(before));
      expect(_bakes.debugStarted - bakesBefore, lessThanOrEqualTo(2));
      expect(_bakes.debugPeakRunning, 1);
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    });

    testWidgets('leaving an image and coming back does not bake again, with cards arriving each time', (tester) async {
      smallWindow(tester);
      final art = ControlledImage();
      ImageProvider? image;
      double? top;
      late StateSetter update;
      await tester.pumpWidget(
        frostTestApp(
          StatefulBuilder(
            builder: (_, set) {
              update = set;
              return FrostAmbientBackdropHost(
                image: image,
                fallback: FrostAmbientFallback.accentWash,
                child: Stack(
                  children: [
                    if (top != null)
                      Positioned(
                        left: 40,
                        top: top,
                        width: 20,
                        height: 10,
                        child: const FrostSurface(role: FrostSurfaceRole.module, child: SizedBox.expand()),
                      ),
                  ],
                ),
              );
            },
          ),
          brightness: Brightness.dark,
        ),
      );
      Future<void> enter({bool resolve = false}) async {
        update(() {
          image = art;
          top = 90;
        });
        await tester.pump();
        if (resolve) await complete(tester, art, Colors.purple);
        // The page slides in: its cards move for a while, then rest.
        for (var frame = 1; frame <= 10; frame++) {
          update(() => top = 90 - 4.0 * frame);
          await tester.pump(const Duration(milliseconds: 16));
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 2)));
        }
        await settleGlow(tester);
      }

      await enter(resolve: true);
      expect(_bakes.debugStarted, 1);
      for (var round = 0; round < 3; round++) {
        update(() {
          image = null;
          top = null;
        });
        await settleGlow(tester);
        await enter();
      }
      expect(_bakes.debugStarted, 1);
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    });

    for (final brightness in Brightness.values) {
      testWidgets('the prepared texture follows the window when it grows, $brightness', (tester) async {
        smallWindow(tester);
        final art = ControlledImage();
        await tester.pumpWidget(
          frostTestApp(
            FrostAmbientBackdropHost(image: art, child: const SizedBox.expand()),
            brightness: brightness,
          ),
        );
        await complete(tester, art, Colors.purple);
        await settleGlow(tester);
        expect(tester.renderObject(_paint.first), paints..drawImageRect(source: const Rect.fromLTWH(0, 0, 180, 120)));
        tester.view.physicalSize = const Size(300, 200);
        await tester.pump();
        await settleGlow(tester);
        expect(tester.renderObject(_paint.first), paints..drawImageRect(source: const Rect.fromLTWH(0, 0, 300, 200)));
        await tester.pumpWidget(const SizedBox());
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('rapid light switching keeps a bounded number of window-sized layers per frame', (tester) async {
      smallWindow(tester);
      final images = [for (var i = 0; i < 9; i++) ControlledImage()];
      ImageProvider image = images.first;
      late StateSetter update;
      await tester.pumpWidget(
        frostTestApp(
          StatefulBuilder(
            builder: (_, set) {
              update = set;
              return FrostAmbientBackdropHost(image: image, child: const SizedBox.expand());
            },
          ),
        ),
      );
      await complete(tester, images.first, Colors.purple);
      await settleGlow(tester);
      for (final next in images.skip(1)) {
        update(() => image = next);
        await tester.pump();
        await complete(tester, next, Color.fromARGB(255, 25 * images.indexOf(next), 90, 200));
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
        await tester.pump();
        // Well inside the 420 ms cross-fade, so no switch ever completes.
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(_saveLayers(tester.renderObject(_paint.first)), lessThanOrEqualTo(6));
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    });
  });

  group('media surround', () {
    Future<void> settleMedia(WidgetTester tester) async {
      for (var i = 0; i < 12; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.pumpAndSettle();
    }

    Widget surround(ImageProvider image, Brightness brightness) => frostTestApp(
      Center(
        child: SizedBox(
          width: 160,
          height: 100,
          child: FrostAmbientBackdrop.fromImage(image: image, child: const SizedBox.expand()),
        ),
      ),
      brightness: brightness,
    );

    testWidgets('an identical theme rebuild does not bake', (tester) async {
      final art = await _solid(tester, Colors.red);
      await tester.pumpWidget(surround(art, Brightness.dark));
      await settleMedia(tester);
      expect(_bakes.debugStarted, 1);
      for (var i = 0; i < 6; i++) {
        await tester.pumpWidget(surround(art, Brightness.dark));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      }
      await settleMedia(tester);
      expect(_bakes.debugStarted, 1);
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    });

    testWidgets('the theme switch animation coalesces into one bake at a time', (tester) async {
      final art = await _solid(tester, Colors.red);
      await tester.pumpWidget(surround(art, Brightness.light));
      await settleMedia(tester);
      expect(_bakes.debugStarted, 0);
      await tester.pumpWidget(surround(art, Brightness.dark));
      for (var frame = 0; frame < 40; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 2)));
      }
      await settleMedia(tester);
      expect(_bakes.debugStarted, 1);
      expect(_bakes.debugPeakRunning, 1);
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    });

    testWidgets('leaving the page and coming back does not bake again', (tester) async {
      final art = await _solid(tester, Colors.red);
      for (var round = 0; round < 3; round++) {
        await tester.pumpWidget(surround(art, Brightness.dark));
        await settleMedia(tester);
        await tester.pumpWidget(frostTestApp(const SizedBox.expand(), brightness: Brightness.dark));
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(_bakes.debugStarted, 1);
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    });
  });

  group('theme tokens', () {
    final tokens = FrostPalettes.pink.darkNeutral;

    test('tokens with the same values are equal and hash alike', () {
      final copy = tokens.copyWith();
      expect(identical(copy, tokens), isFalse);
      expect(copy, tokens);
      expect(copy.hashCode, tokens.hashCode);
      expect(tokens.copyWith(categorical: List.of(tokens.categorical)), tokens);
    });

    test('any changed value makes them differ', () {
      expect(tokens.copyWith(accent: const Color(0xff123456)), isNot(tokens));
      expect(tokens.copyWith(canvas: const Color(0xff123456)), isNot(tokens));
      expect(tokens.copyWith(fill: const Color(0x10123456)), isNot(tokens));
      expect(tokens.copyWith(categorical: const [Color(0xff123456)]), isNot(tokens));
      expect(tokens.copyWith(shadowAmbient: const []), isNot(tokens));
      expect(tokens.copyWith(brightness: Brightness.light), isNot(tokens));
    });

    test('the end of a theme animation equals the theme it animated to', () {
      final end = FrostPalettes.pink.lightNeutral.lerp(tokens, 1);
      expect(end, tokens);
      expect(end.hashCode, tokens.hashCode);
    });
  });
}
