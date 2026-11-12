import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../foundation/_ambient_material.dart';
import '../foundation/metrics.dart';
import '../foundation/scope.dart';
import '../foundation/tokens.dart';
import '../layout/window_caption_scope.dart';
import '../motion/_frame_work.dart';
import '_media_ambient.dart';
import '_window_background.dart';

// Bound full-window textures independently from the small decoded-art cache.
const _ambientTextureCapacity = 2;

typedef _AmbientGlow = ({ui.Image image, Size window, double ratio, List<Rect> cards});

class _AmbientFrame implements FrostAmbientFading {
  _AmbientFrame(this.image, this.tokens, this.intensity, this.material, this.startWeight, {this.accentFallback = false});
  final ui.Image? image;
  final FrostThemeTokens tokens;
  final double intensity;
  final FrostAmbientMaterials? material;
  final bool accentFallback;
  @override
  double startWeight;
  ui.Image? texture;
  FrostFrameWork? preparation;
  int textureEpoch = 0;
  // Dark: the baked glow field and the window it was baked for.
  ui.Image? glow;
  Size? glowWindow;
  double? glowRatio;
  // Set when the registered cards came to rest somewhere else.
  bool glowReshape = false;
  bool glowBaking = false, disposed = false;
  // Fade-in of the baked glow, 0 to 1.
  double glowFade = 1;
  // The cards the glow was shaped around, and the glow it replaces
  // while fading in.
  List<Rect> glowCards = const [];
  ui.Image? glowPrevious;
  @override
  void dispose() {
    disposed = true;
    textureEpoch++;
    preparation?.cancel();
    texture?.dispose();
    glow?.dispose();
    glowPrevious?.dispose();
    image?.dispose();
  }
}

/// Window-wide ambient state shared by every [FrostAmbientBackdrop] painter.
///
/// The shell paints one backdrop behind the title bar and navigation, and a
/// route paints an identical one beneath itself while it animates. Both read
/// this controller and paint in window coordinates, so the page and the glass
/// around it always agree, including during the image cross-fade.
class FrostAmbientBackdropController extends ChangeNotifier {
  final _frames = <_AmbientFrame>[];
  _AmbientFrame? _pending;

  /// What the window shows surfaces: the art's background colour and how far
  /// the art has faded in, which follows the glow frame by frame.
  final _material = ValueNotifier<({Color background, double weight})?>(null);
  double _progress = 1;
  Size _window = Size.zero;
  double _pixelRatio = 1;
  bool _disposed = false;
  bool _preparingTexture = false;
  // The glow fade-in is skipped under reduced motion.
  bool reduceMotion = false;
  // Registered cards; a settled change re-shapes the glow.
  late final _cards = FrostAmbientCardRegistry(_cardsChanged);
  // Registered media and their rects, for chrome above them.
  final _mediaRects = ValueNotifier<List<Rect>>(const []);
  late final FrostAmbientCardRegistry _media = FrostAmbientCardRegistry(() => _mediaRects.value = _media.current);
  Timer? _cardsSettle;
  final _glowSettle = FrostAmbientSettle();
  // The latest glow asked for; earlier askers give way to it.
  int _glowRequest = 0;

  FrostAmbientBackdropController() {
    frostAmbientGrain.addListener(_invalidateTextures);
  }

  // The rects seen after the latest frame: a bake can start during build,
  // before registered boxes and their ancestors are laid out.
  List<Rect> _cardRects() => _cards.current;

  void _cardsChanged() {
    _glowSettle.moved();
    _cardsSettle?.cancel();
    _cardsSettle = Timer(const Duration(milliseconds: 250), _reshapeGlow);
  }

  // Re-bakes the current glow for the cards now registered, unless a bake
  // or fade is running; those re-check when they finish.
  void _reshapeGlow() {
    final frame = _frames.lastOrNull;
    if (_disposed || _pending != null || _progress < 1 || frame == null || frame.glow == null || frame.glowBaking || frame.glowFade < 1) return;
    if (frostAmbientSameRects(frame.glowCards, _cardRects())) return;
    frame.textureEpoch++;
    frame.preparation?.cancel();
    frame.preparation = null;
    frame.texture?.dispose();
    frame.texture = null;
    frame.glowReshape = true;
    _prepareTexture(frame);
    notifyListeners();
  }

  void _resize(Size window, double pixelRatio) {
    if (_window == window && _pixelRatio == pixelRatio) return;
    _window = window;
    _pixelRatio = pixelRatio;
    _glowSettle.moved();
    _invalidateTextures();
  }

  // Window size, pixel ratio or the light grain arriving all change the
  // prepared endpoint.
  void _invalidateTextures() {
    if (_disposed) return;
    for (final frame in _frames) {
      frame.textureEpoch++;
      frame.preparation?.cancel();
      frame.preparation = null;
      frame.texture?.dispose();
      frame.texture = null;
    }
    if (_frames.isNotEmpty) _prepareTexture(_frames.last);
    notifyListeners();
  }

  FrostAmbientGlowBake _glowBakeFor(FrostThemeTokens tokens, FrostAmbientMaterials material) {
    final window = _window;
    final model = frostAmbientGlows(tokens, material.raw, window: true);
    return frostAmbientGlowBakeFor(
      tokens,
      model,
      frostAmbientWindowGlowCentres(model.glows, material.sourceSize, Offset.zero & window),
      window,
      frostAmbientGlowWindowReach * math.sqrt(window.width * window.width + window.height * window.height),
      _pixelRatio,
      freeLift: frostAmbientFreeLift(tokens, material.raw),
      cards: _cardRects(),
      window: true,
    );
  }

  bool get _windowUsable => !_window.isEmpty && _window.isFinite;

  // The field already baked for the present layout, if there is one. Whatever
  // was on its way gives way to it.
  _AmbientGlow? _cachedGlow(FrostThemeTokens tokens, FrostAmbientMaterials material) {
    if (!_windowUsable) return null;
    final image = FrostAmbientGlowBakes.instance.cached(_glowBakeFor(tokens, material));
    if (image == null) return null;
    _dropGlowRequest();
    return (image: image, window: _window, ratio: _pixelRatio, cards: _cardRects());
  }

  // The field for the layout once it has settled, or null when a newer request
  // took over. Layout that moves on during the bake does not discard the result:
  // the bake would never finish for layout that never rests. Whoever receives
  // it re-shapes the field once things have come to rest.
  Future<_AmbientGlow?> _bakedGlow(FrostThemeTokens tokens, FrostAmbientMaterials material, {bool settled = false}) async {
    final request = ++_glowRequest;
    final bakes = FrostAmbientGlowBakes.instance;
    bakes.cancel(this);
    while (!settled || !_windowUsable) {
      if (!await _glowSettle.wait() || _disposed || request != _glowRequest) return null;
      settled = true;
    }
    final window = _window, ratio = _pixelRatio, cards = _cardRects();
    final image = await bakes.request(this, _glowBakeFor(tokens, material));
    if (image == null) return null;
    if (_disposed || request != _glowRequest) {
      image.dispose();
      return null;
    }
    return (image: image, window: window, ratio: ratio, cards: cards);
  }

  // Dark bakes its glow field off the UI isolate first; the endpoint
  // texture is prepared once it arrives. Returns whether to wait for it.
  bool _bakeGlow(_AmbientFrame frame) {
    final material = frame.material;
    if (!frame.tokens.isDark || material == null || material.palette.isEmpty) return false;
    // Wait for a running fade-in before preparing the texture.
    if (frame.glow != null && frame.glowFade < 1) return true;
    if (frame.glow != null && frame.glowWindow == _window && frame.glowRatio == _pixelRatio && !frame.glowReshape) return false;
    if (frame.glowBaking) return true;
    // The endpoint on its way replaces this one, and bakes for the same layout.
    if (_pending != null) return true;
    frame.glowBaking = true;
    final settled = frame.glowReshape;
    frame.glowReshape = false;
    unawaited(_refreshGlow(frame, material, settled: settled));
    return true;
  }

  Future<void> _refreshGlow(_AmbientFrame frame, FrostAmbientMaterials material, {required bool settled}) async {
    final _AmbientGlow? glow;
    try {
      glow = _cachedGlow(frame.tokens, material) ?? await _bakedGlow(frame.tokens, material, settled: settled);
    } catch (error, stack) {
      frame.glowBaking = false;
      if (!_disposed) FlutterError.reportError(FlutterErrorDetails(exception: error, stack: stack, library: 'ambient endpoint preparation'));
      return;
    }
    frame.glowBaking = false;
    if (glow == null) return;
    if (_disposed || frame.disposed) {
      glow.image.dispose();
      return;
    }
    // Re-shaping fades from the previous field, not from canvas.
    frame.glowPrevious?.dispose();
    frame.glowPrevious = frame.glowWindow == glow.window ? frame.glow : null;
    if (frame.glowPrevious == null) frame.glow?.dispose();
    frame
      ..glow = glow.image
      ..glowWindow = glow.window
      ..glowRatio = glow.ratio
      ..glowCards = glow.cards
      ..texture?.dispose()
      ..texture = null;
    void settle() {
      frame.glowPrevious?.dispose();
      frame.glowPrevious = null;
      if (_frames.lastOrNull != frame) return;
      _prepareTexture(frame);
      // Cards that moved during the bake or fade.
      if (!frostAmbientSameRects(frame.glowCards, _cardRects())) _cardsChanged();
    }

    if (!reduceMotion) {
      // Fade the baked glow in over 300 ms, live, then prepare
      // the static endpoint texture.
      final clock = Stopwatch()..start();
      frame.glowFade = 0;
      void tick(Duration _) {
        if (_disposed || frame.disposed) return;
        frame.glowFade = (clock.elapsedMicroseconds / 300000).clamp(0.0, 1.0);
        notifyListeners();
        if (frame.glowFade < 1) {
          SchedulerBinding.instance.scheduleFrameCallback(tick);
        } else {
          settle();
        }
      }

      SchedulerBinding.instance.scheduleFrameCallback(tick);
      return;
    }
    settle();
    notifyListeners();
  }

  void _prepareTexture(_AmbientFrame frame) {
    if (_preparingTexture ||
        frame.texture != null ||
        _window.isEmpty ||
        !_window.isFinite ||
        frame.intensity == 0 ||
        frame.image == null && !frame.accentFallback) {
      return;
    }
    if (_bakeGlow(frame)) return;
    final epoch = ++frame.textureEpoch;
    final window = _window;
    final ratio = _pixelRatio;
    frame.preparation?.cancel();
    frame.preparation = FrostFrameWorkQueue.enqueue(() {
      frame.preparation = null;
      _preparingTexture = true;
      unawaited(() async {
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder)..scale(ratio, ratio);
        _RenderAmbient._paintEndpoint(canvas, frame, Offset.zero & window, Offset.zero & window, pixelRatio: ratio);
        final picture = recorder.endRecording();
        ui.Image? texture;
        try {
          texture = await picture.toImage((window.width * ratio).ceil(), (window.height * ratio).ceil());
          if (_disposed || frame.textureEpoch != epoch || _frames.lastOrNull != frame) return;
          // Only two full-resolution endpoints are retained. Rapid retargeting
          // keeps the original live paint for older, fading endpoints instead
          // of growing a window-sized texture cache without a bound.
          final cached = _frames.where((f) => f.texture != null && f != frame).toList();
          for (final old in cached.take((cached.length + 1 - _ambientTextureCapacity).clamp(0, cached.length))) {
            old.texture?.dispose();
            old.texture = null;
          }
          frame.texture?.dispose();
          frame.texture = texture;
          texture = null;
          notifyListeners();
        } catch (error, stack) {
          if (!_disposed && frame.textureEpoch == epoch) {
            FlutterError.reportError(FlutterErrorDetails(exception: error, stack: stack, library: 'ambient endpoint preparation'));
          }
        } finally {
          texture?.dispose();
          picture.dispose();
          _preparingTexture = false;
          // Native preparation cannot be cancelled. Keep at most one in flight,
          // then prepare the latest retarget instead of accumulating old work.
          if (!_disposed && frame.textureEpoch != epoch && _frames.isNotEmpty) _prepareTexture(_frames.last);
        }
      }());
    });
  }

  ui.Image? get current => _frames.lastOrNull?.image;
  ui.Image? get previous => _frames.length < 2 ? null : _frames.first.image;
  double get progress => _progress;
  double _weight(int index) => index == _frames.length - 1 ? _progress : _frames[index].startWeight * (1 - _progress);

  Future<void> _show(
    ui.Image? image,
    FrostThemeTokens tokens,
    double intensity,
    FrostAmbientMaterials? material, {
    required bool accentFallback,
    required VoidCallback onReady,
  }) async {
    _pending?.dispose();
    final target = _AmbientFrame(image, tokens, intensity, material, 0, accentFallback: accentFallback);
    _pending = target;
    // A dark endpoint draws its glow from a field baked once layout rests.
    // Over a picture that shows a glow, keep that picture still until the new
    // field is ready, so one artwork never dims to canvas on its way to the
    // next. Over a picture without one there is nothing to dim: commit now,
    // so the window colour follows the page in, and the glow fades in over it
    // when its bake lands. Resize/retarget during the bake never touches the
    // visible picture.
    final showsGlow = _frames.any((frame) => frame.glow != null && frame.intensity > 0);
    if (tokens.isDark && intensity > 0 && material != null && material.palette.isNotEmpty) {
      final _AmbientGlow? glow;
      try {
        glow = _cachedGlow(tokens, material) ?? (showsGlow ? await _bakedGlow(tokens, material) : null);
      } catch (error, stack) {
        if (!target.disposed) {
          _pending = null;
          target.dispose();
          FlutterError.reportError(FlutterErrorDetails(exception: error, stack: stack, library: 'ambient endpoint preparation'));
        }
        return;
      }
      if (glow == null && showsGlow) return;
      if (_disposed || target.disposed) {
        glow?.image.dispose();
        return;
      }
      if (glow != null) {
        target
          ..glow = glow.image
          ..glowWindow = glow.window
          ..glowRatio = glow.ratio
          ..glowCards = glow.cards;
      }
    } else {
      _dropGlowRequest();
    }
    if (_disposed || target.disposed) return;
    _pending = null;
    for (var index = 0; index < _frames.length; index++) {
      _frames[index].startWeight = _weight(index);
    }
    _frames.removeWhere((frame) {
      if (frame.startWeight > 0) return false;
      frame.dispose();
      return true;
    });
    frostAmbientBoundFading(_frames);
    if (_frames.isEmpty) _frames.add(_AmbientFrame(null, tokens, 0, null, 1));
    for (final frame in _frames) {
      frame.textureEpoch++;
      frame.preparation?.cancel();
      frame.preparation = null;
    }
    _frames.add(target);
    _prepareTexture(target);
    _progress = 0;
    _publishMaterial();
    notifyListeners();
    onReady();
  }

  void _dropGlowRequest() {
    _glowRequest++;
    _glowSettle.cancel();
    FrostAmbientGlowBakes.instance.cancel(this);
  }

  // Withdraws the replacement on its way, and what it was waiting for.
  void _dropPending() {
    _pending?.dispose();
    _pending = null;
    _dropGlowRequest();
  }

  // The art's share of the picture is the glow's own weights, so surfaces
  // change with the glow: none at the start of a fade in, all at its end, and
  // the backgrounds of two pieces of art mixed by their weights in between.
  void _publishMaterial() {
    final active = [
      for (var index = 0; index < _frames.length; index++)
        if (_frames[index] case _AmbientFrame(:final material?, :final intensity) when intensity > 0) (material.background, _weight(index)),
    ];
    if (active.isEmpty) {
      _material.value = null;
      return;
    }
    final total = active.fold(0.0, (sum, entry) => sum + entry.$2);
    var red = 0.0, green = 0.0, blue = 0.0;
    for (final (color, weight) in active) {
      final share = total == 0 ? 1 / active.length : weight / total;
      red += color.r * share;
      green += color.g * share;
      blue += color.b * share;
    }
    final next = (background: Color.from(alpha: 1, red: red, green: green, blue: blue), weight: total.clamp(0.0, 1.0));
    if (next != _material.value) _material.value = next;
  }

  void _setProgress(double value) {
    if (_progress == value) return;
    _progress = value;
    if (value >= 1 && _frames.length > 1) {
      for (final frame in _frames.take(_frames.length - 1)) {
        frame.dispose();
      }
      final last = _frames.last;
      _frames
        ..clear()
        ..add(last);
      _cardsChanged();
    }
    _publishMaterial();
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    frostAmbientGrain.removeListener(_invalidateTextures);
    _dropGlowRequest();
    _cardsSettle?.cancel();
    _cards.dispose();
    _media.dispose();
    _mediaRects.dispose();
    _pending?.dispose();
    for (final frame in _frames) {
      frame.dispose();
    }
    _material.dispose();
    super.dispose();
  }
}

class _AmbientScope extends InheritedWidget {
  const _AmbientScope({required this.controller, required this.forceSolid, required super.child});

  final FrostAmbientBackdropController controller;
  final bool forceSolid;

  @override
  bool updateShouldNotify(_AmbientScope oldWidget) => !identical(controller, oldWidget.controller) || forceSolid != oldWidget.forceSolid;
}

/// Optional artwork-free ambient paint. None preserves native Mica visibility.
enum FrostAmbientFallback { none, accentWash }

/// Owns the ambient state for the window and paints it behind [child].
///
/// [image] is the current page's artwork, if any. Supply a provider that
/// decodes at about [sampleWidth] pixels wide; it is pre-blurred once and up
/// to three hue-separated colours are picked from it. In dark they become
/// glows that lift lightness, baked off the UI isolate and faded in; opaque
/// cards keep a lower peak beneath them. In light they are tone-mapped radial
/// gradients that fade out from the top-leading corner, with a static grain.
/// Hue, the surface hierarchy and text contrast hold throughout. The window
/// endpoint is then prepared at the view's physical resolution, and moving
/// pages composite that texture instead of re-running the paint. At most two
/// endpoints are retained.
/// Providers are cached by equality, so equal providers
/// for the same picture reuse the blurred copy. A replacement keeps the last
/// usable artwork while loading and after failure; only an explicit null clears
/// artwork. Late results from earlier replacements are discarded.
class FrostAmbientBackdropHost extends StatefulWidget {
  const FrostAmbientBackdropHost({required this.image, required this.child, this.intensity = 1, this.fallback = FrostAmbientFallback.none, super.key})
    : assert(intensity >= 0 && intensity <= 1);

  /// Palette (or mesh) contribution: the alpha of each colour's
  /// gradient centre. Zero paints a solid canvas even when system Mica is
  /// available. Changes cross-fade cached paint states; they never re-decode
  /// the artwork. Every tone-mapped colour is readable on its own, so lower
  /// values, which only mix it toward canvas, stay readable too.
  final double intensity;

  /// None keeps the existing no-image canvas/Mica behaviour. AccentWash
  /// paints a static mesh tinted by the accent hue when no artwork is
  /// available, through the same contrast solver. Zero intensity is always
  /// solid. Artwork without a usable colour (fully transparent) also uses it.
  final FrostAmbientFallback fallback;

  /// Decode width the blurred backdrop needs; larger decodes are wasted.
  static const sampleWidth = 48;

  final ImageProvider? image;
  final Widget child;

  @override
  State<FrostAmbientBackdropHost> createState() => _FrostAmbientBackdropHostState();
}

class _FrostAmbientBackdropHostState extends State<FrostAmbientBackdropHost> with SingleTickerProviderStateMixin {
  static const _sampleWidth = FrostAmbientBackdropHost.sampleWidth;
  final _controller = FrostAmbientBackdropController();
  late final AnimationController _fade = AnimationController(vsync: this, duration: const Duration(milliseconds: 420))
    ..addListener(() => _controller._setProgress(Curves.easeInOut.transform(_fade.value)));
  final Map<ImageProvider, ({ui.Image image, FrostAmbientSample sample})> _blurred = {};
  FrostAmbientSample? _sample;
  FrostThemeTokens? _tokens;
  Object? _appearanceKey;
  ImageProvider? _requested;
  ImageStream? _stream;
  ImageStreamListener? _listener;
  int _transitionEpoch = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final raw = FrostThemeTokens.of(context);
    _tokens = context.dependOnInheritedWidgetOfExactType<FrostAmbientThemeScope>()?.tokens ?? raw;
    // Subscribes to the window metrics, which View.of does not.
    MediaQuery.of(context);
    final view = View.of(context);
    _controller._resize(view.physicalSize / view.devicePixelRatio, view.devicePixelRatio);
    _controller.reduceMotion = MediaQuery.disableAnimationsOf(context);
    _request(widget.image);
    _refreshAppearance();
  }

  @override
  void didUpdateWidget(FrostAmbientBackdropHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.image != widget.image) _request(widget.image);
    if (oldWidget.intensity != widget.intensity || oldWidget.fallback != widget.fallback) _refreshAppearance();
  }

  void _request(ImageProvider? provider) {
    if (provider == _requested) return;
    _requested = provider;
    _transitionEpoch++;
    _controller._dropPending();
    _detachStream();
    if (provider == null) {
      _present(null);
      return;
    }
    if (_blurred[provider] case final cached?) {
      _present(cached.image.clone(), cached.sample);
      return;
    }
    final stream = provider.resolve(ImageConfiguration.empty);
    final listener = ImageStreamListener(
      (info, _) {
        if (!mounted || _requested != provider) {
          info.dispose();
          return;
        }
        _detachStream();
        unawaited(_prepareArtwork(provider, info));
      },
      onError: (_, _) {
        if (!mounted || _requested != provider) return;
        _detachStream();
        if (_controller.current == null && _controller.previous == null) {
          _present(null);
        } else if (_controller._frames.lastOrNull case final frame?) {
          // The withdrawn replacement may have held back what this one needs.
          _controller._prepareTexture(frame);
        }
      },
    );
    _stream = stream;
    _listener = listener;
    stream.addListener(listener);
  }

  Future<void> _prepareArtwork(ImageProvider provider, ImageInfo info) async {
    ui.Image? image;
    try {
      final prepared = await frostAmbientSampleOf(info.image, _sampleWidth);
      image = prepared.image;
      if (!mounted || _requested != provider) return;
      _accept(provider, image, prepared.sample);
      image = null; // The cache owns this handle after acceptance.
    } catch (error, stack) {
      if (mounted && _requested == provider) {
        FlutterError.reportError(FlutterErrorDetails(exception: error, stack: stack, library: 'ambient artwork'));
      }
    } finally {
      image?.dispose();
      info.dispose();
    }
  }

  void _detachStream() {
    if (_listener case final listener?) _stream?.removeListener(listener);
    _stream = null;
    _listener = null;
  }

  void _accept(ImageProvider provider, ui.Image image, FrostAmbientSample sample) {
    if (!mounted) {
      image.dispose();
      return;
    }
    if (_blurred.length >= frostAmbientCacheCapacity) _blurred.remove(_blurred.keys.first)?.image.dispose();
    _blurred[provider] = (image: image, sample: sample);
    if (_requested == provider) _present(image.clone(), sample);
  }

  void _present(ui.Image? image, [FrostAmbientSample? sample]) {
    if (image == null &&
        _controller.current == null &&
        _controller.previous == null &&
        _controller._pending == null &&
        widget.fallback == FrostAmbientFallback.none) {
      return;
    }
    _sample = sample;
    _appearanceKey = null;
    _animate(image, sample, imageChange: true);
  }

  void _refreshAppearance() {
    if (_controller.current == null && _controller._pending == null && _controller._frames.isEmpty && widget.fallback == FrostAmbientFallback.none) return;
    final tokens = _tokens!;
    final key = (
      tokens.brightness,
      tokens.tone,
      tokens.canvas,
      tokens.surface,
      tokens.textPrimary,
      tokens.textSecondary,
      tokens.accent,
      widget.intensity,
      widget.fallback,
    );
    if (key == _appearanceKey) return;
    _appearanceKey = key;
    _animate((_controller._pending?.image ?? _controller.current)?.clone(), _sample, imageChange: false);
  }

  void _animate(ui.Image? image, FrostAmbientSample? sample, {required bool imageChange}) {
    final epoch = ++_transitionEpoch;
    final tokens = _tokens!;
    _appearanceKey = (
      tokens.brightness,
      tokens.tone,
      tokens.canvas,
      tokens.surface,
      tokens.textPrimary,
      tokens.textSecondary,
      tokens.accent,
      widget.intensity,
      widget.fallback,
    );
    final accentFallback = widget.fallback == FrostAmbientFallback.accentWash;
    final usable = sample != null && sample.palette.isNotEmpty;
    // No usable colour: the accent-tinted mesh, when the fallback asks for it.
    final material = accentFallback && !usable ? frostAmbientMeshMaterial(tokens) : sample?.resolve(tokens, widget.intensity);
    _fade.stop();
    unawaited(
      _controller._show(
        image,
        tokens,
        widget.intensity,
        material,
        accentFallback: accentFallback,
        onReady: () {
          if (!mounted || epoch != _transitionEpoch) return;
          _fade.duration = imageChange ? const Duration(milliseconds: 420) : FrostMotion.hover;
          if (MediaQuery.disableAnimationsOf(context)) {
            _controller._setProgress(1);
          } else {
            _fade.forward(from: 0);
          }
        },
      ),
    );
  }

  @override
  void dispose() {
    _detachStream();
    _fade.dispose();
    _controller.dispose();
    for (final image in _blurred.values) {
      image.image.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller._material,
      child: widget.child,
      builder: (context, child) => FrostWindowBackgroundScope(
        hasAmbient: _controller._material.value != null,
        ambientWeight: _controller._material.value?.weight ?? 0,
        forceSolidBase: widget.intensity == 0,
        background: _controller._material.value?.background,
        child: _AmbientScope(
          controller: _controller,
          forceSolid: widget.intensity == 0,
          child: Stack(
            fit: StackFit.expand,
            children: [
              const RepaintBoundary(child: FrostAmbientBackdrop()),
              FrostAmbientCardScope(registry: _controller._cards, media: _controller._media, mediaRects: _controller._mediaRects, child: child!),
            ],
          ),
        ),
      ),
    );
  }
}

/// Paints the window's ambient backdrop, aligned to the window rather than to
/// this widget. Use it wherever the ambient layer has to be opaque locally,
/// such as beneath a route while its transition overlaps the previous page.
class FrostAmbientBackdrop extends StatelessWidget {
  const FrostAmbientBackdrop({super.key}) : _media = null;

  /// Extends app-owned media's dominant colours around it as tone-mapped  /// gradients over canvas. Reduced transparency uses their weighted mean.
  ///
  /// [stageKey] names the media stage, whose centre anchors the light theme's
  /// tint falloff; without one it is the centre of this backdrop.
  const FrostAmbientBackdrop.fromImage({required ImageProvider image, required Widget child, GlobalKey? stageKey, super.key})
    : _media = (image: image, child: child, stageKey: stageKey);
  final ({ImageProvider image, Widget child, GlobalKey? stageKey})? _media;

  @override
  Widget build(BuildContext context) {
    if (_media case final media?) return FrostMediaAmbientBackdrop(image: media.image, stageKey: media.stageKey, child: media.child);
    final tokens = FrostThemeTokens.of(context);
    final plain = FrostScope.solidSurfaces(context);
    final scope = context.dependOnInheritedWidgetOfExactType<_AmbientScope>();
    final controller = scope?.controller;
    // No repaint boundary here: the backdrop is window-aligned, so it has to
    // repaint when an ancestor transition moves it.
    // Reduced transparency still follows the controller, painting each
    // endpoint as one opaque palette fill.
    return _AmbientPaint(
      controller: controller,
      tokens: tokens,
      plain: plain,
      systemBackdrop: !plain && !(scope?.forceSolid ?? false) && FrostWindowCaptionScope.systemBackdropActiveOf(context),
    );
  }
}

class _AmbientPaint extends LeafRenderObjectWidget {
  const _AmbientPaint({required this.controller, required this.tokens, required this.plain, required this.systemBackdrop});

  final FrostAmbientBackdropController? controller;
  final FrostThemeTokens tokens;
  final bool plain;
  final bool systemBackdrop;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderAmbient(controller: controller, tokens: tokens, plain: plain, systemBackdrop: systemBackdrop);

  @override
  void updateRenderObject(BuildContext context, _RenderAmbient renderObject) {
    renderObject
      ..controller = controller
      ..tokens = tokens
      ..plain = plain
      ..systemBackdrop = systemBackdrop;
  }
}

class _RenderAmbient extends RenderBox {
  _RenderAmbient({required FrostAmbientBackdropController? controller, required FrostThemeTokens tokens, required bool plain, required bool systemBackdrop})
    : this._(controller, tokens, plain, systemBackdrop);
  _RenderAmbient._(this._controller, this._tokens, this._plain, this._systemBackdrop);

  FrostAmbientBackdropController? _controller;
  set controller(FrostAmbientBackdropController? value) {
    if (identical(value, _controller)) return;
    if (attached) {
      _controller?.removeListener(markNeedsPaint);
      value?.addListener(markNeedsPaint);
    }
    _controller = value;
    markNeedsPaint();
  }

  FrostThemeTokens _tokens;
  set tokens(FrostThemeTokens value) {
    if (value == _tokens) return;
    _tokens = value;
    markNeedsPaint();
  }

  bool _plain;
  set plain(bool value) {
    if (value == _plain) return;
    _plain = value;
    markNeedsPaint();
  }

  bool _systemBackdrop;
  set systemBackdrop(bool value) {
    if (_systemBackdrop == value) return;
    _systemBackdrop = value;
    markNeedsPaint();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _controller?.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _controller?.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  bool get sizedByParent => true;

  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.biggest;

  @override
  bool hitTestSelf(Offset position) => false;

  @override
  void paint(PaintingContext context, Offset offset) {
    final canvas = context.canvas;
    final local = offset & size;
    // An absent/failed ambient image reveals Mica when actually available.
    // Opaque fallbacks remain entirely app-owned on every other platform.
    final hasAccentFallback = _controller?._frames.any((frame) => frame.accentFallback && frame.intensity > 0) ?? false;
    if (!_plain && _systemBackdrop && !hasAccentFallback && _controller?.current == null && _controller?.previous == null) return;
    if (_controller == null || _controller!._frames.isEmpty) {
      canvas.drawRect(local, Paint()..color = _tokens.canvas);
      return;
    }
    final view = ui.PlatformDispatcher.instance.implicitView;
    final window = view == null ? size : view.physicalSize / view.devicePixelRatio;
    final toWindow = Matrix4.tryInvert(getTransformTo(null));
    final windowRect = toWindow == null
        ? (offset - localToGlobal(Offset.zero)) & window
        : MatrixUtils.transformRect(toWindow, Offset.zero & window).shift(offset);
    final frames = _controller!._frames;
    final visible = <(int, double)>[];
    var total = 0.0;
    for (var index = 0; index < frames.length; index++) {
      final weight = _controller!._weight(index);
      if (weight <= 0 || (_systemBackdrop && frames[index].image == null && !frames[index].accentFallback)) continue;
      visible.add((index, weight));
      total += weight;
    }
    if (total == 0) return;
    final opacity = total.clamp(0.0, 1.0);
    // A complete endpoint is opaque. Do not allocate a window-sized opacity
    // buffer for alpha one on every moving-page frame.
    if (opacity < 1) {
      canvas.saveLayer(local, Paint()..color = _tokens.canvas.withValues(alpha: opacity));
    } else {
      canvas.save();
    }
    canvas.clipRect(local);
    var accumulated = 0.0;
    for (final (index, weight) in visible) {
      final frame = frames[index];
      accumulated += weight;
      // Blend complete, already-readable endpoints. Retargeting retains the
      // current weighted picture instead of jumping to the old target.
      final blend = weight / accumulated;
      if (blend < 1) canvas.saveLayer(local, Paint()..color = _tokens.canvas.withValues(alpha: blend));
      if (_plain) {
        _paintEndpoint(canvas, frame, local, windowRect, solid: true);
      } else if (frame.texture case final texture?) {
        canvas.drawRect(local, Paint()..color = frame.tokens.canvas);
        canvas.drawImageRect(
          texture,
          Rect.fromLTWH(0, 0, texture.width.toDouble(), texture.height.toDouble()),
          windowRect,
          Paint()..filterQuality = FilterQuality.medium,
        );
      } else {
        _paintEndpoint(canvas, frame, local, windowRect, pixelRatio: view?.devicePixelRatio ?? 1);
      }
      if (blend < 1) canvas.restore();
    }
    canvas.restore();
  }

  static void _paintEndpoint(Canvas canvas, _AmbientFrame frame, Rect local, Rect windowRect, {bool solid = false, double pixelRatio = 1}) {
    final material = frame.material;
    if (solid) {
      // Reduced transparency: the palette's weighted mean as one opaque fill.
      final fill = material?.solid;
      canvas.drawRect(local, Paint()..color = fill == null ? frame.tokens.canvas : Color.lerp(frame.tokens.canvas, fill, frame.intensity)!);
      return;
    }
    canvas.drawRect(local, Paint()..color = frame.tokens.canvas);
    if (frame.intensity <= 0 || material == null) return;
    if (material.palette.isNotEmpty) {
      if (frame.tokens.isDark) {
        // Dark: the baked glow field, until then plain canvas.
        if (frame.glowPrevious case final previous?) {
          // A re-shaped glow fades in over the one it replaces.
          canvas.drawImageRect(
            previous,
            Offset.zero & Size(previous.width.toDouble(), previous.height.toDouble()),
            windowRect,
            Paint()
              ..filterQuality = FilterQuality.medium
              ..color = Color.fromRGBO(0, 0, 0, frame.intensity),
          );
        }
        if (frame.glow case final glow?) {
          canvas.drawImageRect(
            glow,
            Offset.zero & Size(glow.width.toDouble(), glow.height.toDouble()),
            windowRect,
            Paint()
              ..filterQuality = FilterQuality.medium
              ..color = Color.fromRGBO(0, 0, 0, frame.intensity * frame.glowFade),
          );
        }
      } else {
        frostPaintAmbientPalette(canvas, local, windowRect, material.palette, material.sourceSize, frame.intensity);
      }
    } else if (frame.accentFallback) {
      // No usable artwork colour: the accent-tinted mesh.
      frostPaintAmbientMesh(canvas, local, windowRect, frame.tokens, frame.intensity);
    } else {
      return;
    }
    if (material.palette.isNotEmpty) {
      final colors = frame.tokens.isDark
          ? frostAmbientGlowPeaks(frame.tokens, material.raw, free: true)
          : material.palette.map((entry) => entry.color).toList();
      if (colors.isNotEmpty) {
        final wash = Color.from(
          alpha: 1,
          red: colors.fold(0.0, (sum, color) => sum + color.r) / colors.length,
          green: colors.fold(0.0, (sum, color) => sum + color.g) / colors.length,
          blue: colors.fold(0.0, (sum, color) => sum + color.b) / colors.length,
        );
        canvas.drawRect(local, Paint()..color = wash.withValues(alpha: .20 * frame.intensity));
      }
    }
    // Light grain, part of the static endpoint (and its texture).
    frostPaintAmbientGrain(canvas, local, pixelRatio, dark: frame.tokens.isDark);
  }
}
