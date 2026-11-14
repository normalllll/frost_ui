import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../foundation/_ambient_material.dart';
import '../foundation/metrics.dart';
import '../foundation/scope.dart';
import '../foundation/tokens.dart';

// Match the existing window-ambient cache's bounded capacity.
const frostAmbientCacheCapacity = 12;
// The same small pre-blurred sample as the window host; its palette is
// independent of the surround size, so resizing and moving reuse it.
const _mediaSampleWidth = 48;
final _samples = <ImageProvider, Future<FrostAmbientSample>>{};

Future<FrostAmbientSample> _sampleOf(ImageProvider provider, ImageConfiguration configuration) {
  if (_samples[provider] case final cached?) return cached;
  if (_samples.length >= frostAmbientCacheCapacity) _samples.remove(_samples.keys.first);
  final completion = Completer<FrostAmbientSample>();
  final stream = provider.resolve(configuration);
  late final ImageStreamListener listener;
  listener = ImageStreamListener(
    (info, _) {
      stream.removeListener(listener);
      unawaited(() async {
        try {
          final prepared = await frostAmbientSampleOf(info.image, _mediaSampleWidth);
          prepared.image.dispose();
          completion.complete(prepared.sample);
        } catch (error, stack) {
          completion.completeError(error, stack);
        } finally {
          info.dispose();
        }
      }());
    },
    onError: (Object error, StackTrace? stack) {
      stream.removeListener(listener);
      if (!completion.isCompleted) completion.completeError(error, stack);
    },
  );
  stream.addListener(listener);
  final future = completion.future;
  _samples[provider] = future;
  // A failure is not cached, so a later mount can retry the source.
  future.ignore();
  future.then<void>((_) {}, onError: (Object _) => _samples.remove(provider));
  return future;
}

/// Private media mode; the public ambient painter retains its window contract.
///
/// The image's dominant colours, tone-mapped per colour exactly as the window
/// ambient, extend around the media as radial gradients over canvas. Reduced
/// transparency fills with their weighted mean.
class FrostMediaAmbientBackdrop extends StatelessWidget {
  const FrostMediaAmbientBackdrop({required this.image, required this.child, this.stageKey, super.key});

  /// The media stage, whose centre anchors the light tint falloff.
  final GlobalKey? stageKey;
  final ImageProvider image;
  final Widget child;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => _SizedMediaAmbientBackdrop(image: image, size: constraints.biggest, stageKey: stageKey, child: child),
  );
}

class _SizedMediaAmbientBackdrop extends StatefulWidget {
  const _SizedMediaAmbientBackdrop({required this.image, required this.size, required this.child, this.stageKey});
  final GlobalKey? stageKey;
  final ImageProvider image;
  final Size size;
  final Widget child;
  @override
  State<_SizedMediaAmbientBackdrop> createState() => _FrostMediaAmbientBackdropState();
}

/// One endpoint of the surround: its canvas with the glow or palette over it,
/// prepared as one texture so the crossfade draws it once with an alpha.
/// Without a surface it is plain canvas.
class _MediaFrame implements FrostAmbientFading {
  _MediaFrame(this.tokens, this.solid, this.surface, this.startWeight);
  final FrostThemeTokens tokens;
  final Color solid;
  final ui.Image? surface;
  @override
  double startWeight;
  @override
  void dispose() => surface?.dispose();
}

Future<ui.Image> _mediaSurface({
  required FrostThemeTokens tokens,
  required Size size,
  required ui.Image? glow,
  required List<FrostAmbientPaletteEntry> palette,
  required Size sourceSize,
  required Rect? stage,
}) async {
  final scale = frostAmbientTextureScale(size);
  final rect = Offset.zero & size;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)..scale(scale, scale);
  canvas.drawRect(rect, Paint()..color = tokens.canvas);
  if (tokens.isDark) {
    if (glow != null) {
      canvas.drawImageRect(glow, Offset.zero & Size(glow.width.toDouble(), glow.height.toDouble()), rect, Paint()..filterQuality = FilterQuality.medium);
    }
  } else {
    frostPaintAmbientPalette(canvas, rect, rect, palette, sourceSize, 1, falloffFrom: stage?.center ?? rect.center);
  }
  final picture = recorder.endRecording();
  try {
    return await picture.toImage(math.max(1, (size.width * scale).ceil()), math.max(1, (size.height * scale).ceil()));
  } finally {
    picture.dispose();
  }
}

class _FrostMediaAmbientBackdropState extends State<_SizedMediaAmbientBackdrop> with SingleTickerProviderStateMixin {
  late final _fade = AnimationController(vsync: this, duration: FrostMotion.reveal, value: 1, animationBehavior: AnimationBehavior.preserve)
    ..addStatusListener((status) {
      if (status != AnimationStatus.completed || _frames.length < 2) return;
      for (final frame in _frames.take(_frames.length - 1)) {
        frame.dispose();
      }
      final last = _frames.last;
      setState(
        () => _frames
          ..clear()
          ..add(last),
      );
    });
  final _frames = <_MediaFrame>[];
  ImageProvider? _requested;
  FrostAmbientSample? _sample;
  FrostThemeTokens? _tokens;
  bool _solid = false, _scheduled = false;
  Object? _preparedKey;
  int _epoch = 0, _preparation = 0;
  final _settle = FrostAmbientSettle();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tokens = FrostThemeTokens.of(context);
    _solid = FrostScope.solidSurfaces(context);
    _request();
    _schedulePreparation();
  }

  @override
  void didUpdateWidget(_SizedMediaAmbientBackdrop oldWidget) {
    super.didUpdateWidget(oldWidget);
    _request();
    _schedulePreparation();
  }

  void _request() {
    if (widget.size.isEmpty || !widget.size.isFinite || _requested == widget.image) return;
    _requested = widget.image;
    _sample = null;
    _preparedKey = null;
    final epoch = ++_epoch;
    _preparation++;
    _settle.cancel();
    FrostAmbientGlowBakes.instance.cancel(this);
    _sampleOf(widget.image, createLocalImageConfiguration(context)).then(
      (sample) {
        if (!mounted || epoch != _epoch) return;
        _sample = sample;
        _schedulePreparation();
      },
      onError: (Object error, StackTrace stack) {
        if (mounted && epoch == _epoch) {
          FlutterError.reportError(FlutterErrorDetails(exception: error, stack: stack, library: 'media ambient backdrop'));
        }
      },
    );
  }

  void _schedulePreparation() {
    if (_scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (mounted) unawaited(_prepare());
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  Future<void> _prepare() async {
    final sample = _sample, tokens = _tokens;
    final size = widget.size;
    if (sample == null || tokens == null || size.isEmpty || !size.isFinite) return;
    final stage = _stageRect();
    final ratio = MediaQuery.devicePixelRatioOf(context);
    final key = (sample, tokens, size, stage, ratio, _solid);
    if (key == _preparedKey) return;
    _preparedKey = key;
    final epoch = ++_preparation;
    // Freeze the current mixture while the replacement prepares. Its field is
    // retained until the one source transition completes, including rapid flips.
    _fade.stop();
    final bakes = FrostAmbientGlowBakes.instance;
    ui.Image? glow;
    try {
      if (tokens.isDark && !_solid) {
        final model = frostAmbientGlows(tokens, sample.palette);
        final around = stage ?? Rect.fromCenter(center: size.center(Offset.zero), width: size.width / 2, height: size.height / 2);
        final radius = frostAmbientGlowDetailReach * math.sqrt(size.width * size.width + size.height * size.height);
        final bake = frostAmbientGlowBakeFor(tokens, model, frostAmbientDetailGlowCentres(model.glows, around), size, radius, ratio);
        glow = bakes.cached(bake);
        if (glow == null) {
          // A theme animation or a resize asks anew on every frame. Only what
          // it comes to rest on is worth a bake.
          if (!await _settle.wait() || !mounted || epoch != _preparation) return;
          glow = await bakes.request(this, bake);
          if (glow == null) return;
        }
      } else {
        _settle.cancel();
        bakes.cancel(this);
      }
      if (!mounted || epoch != _preparation) return;
      final toned = sample.toned(tokens);
      // Reduced transparency fills with the solid colour and needs no surface.
      final surface = _solid
          ? null
          : await _mediaSurface(
              tokens: tokens,
              size: size,
              glow: glow,
              palette: toned.palette,
              sourceSize: Size(sample.width.toDouble(), sample.height.toDouble()),
              stage: stage,
            );
      if (!mounted || epoch != _preparation) {
        surface?.dispose();
        return;
      }
      // What moved during the bake gets its own preparation; this result still
      // shows, so moving layout cannot hold the transition back.
      final moved = size != widget.size || stage != _stageRect();
      for (var index = 0; index < _frames.length; index++) {
        _frames[index].startWeight = _weight(index);
      }
      _frames.removeWhere((frame) {
        if (frame.startWeight > 0) return false;
        frame.dispose();
        return true;
      });
      frostAmbientBoundFading(_frames);
      if (_frames.isEmpty) _frames.add(_MediaFrame(tokens, tokens.canvas, null, 1));
      setState(() => _frames.add(_MediaFrame(tokens, toned.solid, surface, 0)));
      if (MediaQuery.disableAnimationsOf(context)) {
        _fade.value = 1;
        // Setting an already completed controller does not emit a status event.
        if (_frames.length > 1) {
          for (final frame in _frames.take(_frames.length - 1)) {
            frame.dispose();
          }
          final last = _frames.last;
          _frames
            ..clear()
            ..add(last);
        }
      } else {
        _fade.forward(from: 0);
      }
      if (moved) {
        _preparedKey = null;
        _schedulePreparation();
      }
    } catch (error, stack) {
      if (mounted && epoch == _preparation) {
        _preparedKey = null;
        FlutterError.reportError(FlutterErrorDetails(exception: error, stack: stack, library: 'media ambient preparation'));
      }
    } finally {
      glow?.dispose();
    }
  }

  double _weight(int index) => index == _frames.length - 1 ? _fade.value : _frames[index].startWeight * (1 - _fade.value);

  Rect? _stageRect() {
    final stage = widget.stageKey?.currentContext?.findRenderObject();
    final self = context.findRenderObject();
    if (stage is! RenderBox || self is! RenderBox || !stage.hasSize || !self.attached || !stage.attached) return null;
    return self.globalToLocal(stage.localToGlobal(Offset.zero)) & stage.size;
  }

  @override
  void dispose() {
    _epoch++;
    _preparation++;
    _settle.cancel();
    FrostAmbientGlowBakes.instance.cancel(this);
    _fade.dispose();
    for (final frame in _frames) {
      frame.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      ClipRect(
        child: ExcludeSemantics(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _fade,
              builder: (context, _) {
                final visible = <(_MediaFrame, double)>[];
                for (var i = 0; i < _frames.length; i++) {
                  final weight = _weight(i);
                  if (weight > 0) visible.add((_frames[i], weight));
                }
                if (_solid) {
                  var color = _tokens!.canvas, total = 0.0;
                  for (final (frame, weight) in visible) {
                    total += weight;
                    color = Color.lerp(color, frame.solid, weight / total)!;
                  }
                  return ColoredBox(color: color);
                }
                return CustomPaint(
                  painter: _MediaPalettePainter(tokens: _tokens!, frames: visible, pixelRatio: MediaQuery.devicePixelRatioOf(context)),
                  child: const SizedBox.expand(),
                );
              },
            ),
          ),
        ),
      ),
      widget.child,
    ],
  );
}

class _MediaPalettePainter extends CustomPainter {
  _MediaPalettePainter({required this.tokens, required this.frames, required this.pixelRatio}) : super(repaint: frostAmbientGrain);
  final FrostThemeTokens tokens;
  final List<(_MediaFrame, double)> frames;
  final double pixelRatio;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = tokens.canvas);
    // Each frame is one opaque draw laid over the ones before it with the
    // alpha of its share, which composites as fading it in as a group would,
    // without an opacity buffer.
    var total = 0.0, grain = 0.0;
    for (final (frame, weight) in frames) {
      total += weight;
      final opacity = weight / total;
      if (frame.surface case final surface?) {
        canvas.drawImageRect(
          surface,
          Offset.zero & Size(surface.width.toDouble(), surface.height.toDouble()),
          rect,
          Paint()
            ..filterQuality = FilterQuality.medium
            ..color = Color.fromRGBO(0, 0, 0, opacity),
        );
      } else {
        final canvasColor = frame.tokens.canvas;
        canvas.drawRect(rect, Paint()..color = canvasColor.withValues(alpha: canvasColor.a * opacity));
      }
      // The grain belongs to the light frames' share of the picture.
      grain = grain * (1 - opacity) + (frame.tokens.isDark ? 0 : opacity);
    }
    if (grain > 0) frostPaintAmbientGrain(canvas, rect, pixelRatio, opacity: grain.clamp(0.0, 1.0));
  }

  @override
  bool shouldRepaint(_MediaPalettePainter old) => true;
}
