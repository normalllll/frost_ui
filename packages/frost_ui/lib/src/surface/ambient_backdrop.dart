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
import '_backdrop_veil.dart';
import '_media_ambient.dart';
import '_window_background.dart';

// Bound full-window textures independently from the small decoded-art cache:
// the endpoints still fading and the one entering, so every endpoint in a
// crossfade stays one draw.
const _ambientTextureCapacity = 3;

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
  // While a glow fades in over a prepared texture: the one draw it fades
  // from, the endpoint's flat colour or its previous texture.
  Object? glowFrom;
  @override
  void dispose() {
    disposed = true;
    textureEpoch++;
    preparation?.cancel();
    texture?.dispose();
    glow?.dispose();
    glowPrevious?.dispose();
    if (glowFrom case final ui.Image from) from.dispose();
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
    // The grain is painted live over the prepared endpoints.
    frostAmbientGrain.addListener(notifyListeners);
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
    // The endpoint keeps its texture while the new field bakes; the new glow
    // fades in over it.
    frame.glowReshape = true;
    if (!_bakeGlow(frame)) _prepareTexture(frame);
  }

  void _resize(Size window, double pixelRatio) {
    if (_window == window && _pixelRatio == pixelRatio) return;
    _window = window;
    _pixelRatio = pixelRatio;
    _glowSettle.moved();
    _invalidateTextures();
  }

  // Window size and pixel ratio change the prepared endpoint and its glow.
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
    if (glow == null) {
      frame.glowBaking = false;
      return;
    }
    // The glow waits for a running crossfade to end, and an endpoint on its
    // way out keeps what it shows.
    if (_frames.lastOrNull == frame && _progress < 1) await (_resting ??= Completer<void>()).future;
    if (_disposed || frame.disposed || _frames.lastOrNull != frame) {
      frame.glowBaking = false;
      glow.image.dispose();
      return;
    }
    // Over an endpoint that shows as one draw, the glow fades in as a
    // crossfade of single draws, from that draw to the endpoint's texture with
    // the glow in full. Painted live, the fade would take a window-sized layer
    // whenever the endpoint blends, as in the backdrop a moving page carries.
    // The endpoint keeps showing as it does until that texture lands.
    final from = frame.texture ?? _RenderAmbient._flatColor(frame, solid: false);
    final texture = from == null || !_windowUsable ? null : await _glowTexture(frame, glow);
    frame.glowBaking = false;
    if (_disposed || frame.disposed || _frames.lastOrNull != frame) {
      texture?.dispose();
      glow.image.dispose();
      return;
    }
    final unchanged = switch (from) {
      final ui.Image image => identical(frame.texture, image),
      final Color color => frame.texture == null && _RenderAmbient._flatColor(frame, solid: false) == color,
      _ => false,
    };
    frame.glowPrevious?.dispose();
    if (texture != null && unchanged) {
      frame.glow?.dispose();
      frame
        ..glowPrevious = null
        ..textureEpoch += 1;
      frame.preparation?.cancel();
      frame.preparation = null;
      // The texture it fades from moves to [glowFrom]; the endpoint owns the
      // new one.
      frame
        ..glowFrom = from
        ..texture = texture;
    } else {
      // What the endpoint showed changed meanwhile, by a resize say, or it is
      // painted live already: the glow fades in live. Re-shaping fades from
      // the previous field, not from canvas.
      texture?.dispose();
      frame.glowPrevious = frame.glowWindow == glow.window ? frame.glow : null;
      if (frame.glowPrevious == null) frame.glow?.dispose();
      frame
        ..texture?.dispose()
        ..texture = null;
    }
    frame
      ..glow = glow.image
      ..glowWindow = glow.window
      ..glowRatio = glow.ratio
      ..glowCards = glow.cards;
    void settle() {
      frame.glowPrevious?.dispose();
      frame.glowPrevious = null;
      if (frame.glowFrom case final ui.Image previous) previous.dispose();
      frame.glowFrom = null;
      if (_frames.lastOrNull != frame) return;
      _prepareTexture(frame);
      // Cards that moved during the bake or fade.
      if (!frostAmbientSameRects(frame.glowCards, _cardRects())) _cardsChanged();
    }

    if (!reduceMotion) {
      // Fade the baked glow in over 300 ms.
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

  /// The texture of [frame] with [glow] in full, recorded without touching
  /// what [frame] shows now.
  Future<ui.Image?> _glowTexture(_AmbientFrame frame, _AmbientGlow glow) async {
    final window = _window, scale = frostAmbientTextureScale(window);
    final kept = (frame.glow, frame.glowWindow, frame.glowRatio, frame.glowCards, frame.glowFade, frame.glowPrevious);
    frame
      ..glow = glow.image
      ..glowWindow = glow.window
      ..glowRatio = glow.ratio
      ..glowCards = glow.cards
      ..glowFade = 1
      ..glowPrevious = null;
    final picture = _endpointPicture(frame, window, scale);
    frame
      ..glow = kept.$1
      ..glowWindow = kept.$2
      ..glowRatio = kept.$3
      ..glowCards = kept.$4
      ..glowFade = kept.$5
      ..glowPrevious = kept.$6;
    try {
      return await picture.toImage(math.max(1, (window.width * scale).ceil()), math.max(1, (window.height * scale).ceil()));
    } catch (error, stack) {
      if (!_disposed) FlutterError.reportError(FlutterErrorDetails(exception: error, stack: stack, library: 'ambient endpoint preparation'));
      return null;
    } finally {
      picture.dispose();
    }
  }

  // Without the grain, the endpoint is smooth; the grain is painted live.
  static ui.Picture _endpointPicture(_AmbientFrame frame, Size window, double scale) {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(scale, scale);
    _RenderAmbient._paintEndpoint(canvas, frame, Offset.zero & window, Offset.zero & window, grain: false);
    return recorder.endRecording();
  }

  bool _needsTextureBeforeShowing(_AmbientFrame frame) => _windowUsable && _RenderAmbient._flatColor(frame, solid: false) == null;

  /// Holds back the raster work of endpoint textures until it completes, as a
  /// busy raster thread does.
  @visibleForTesting
  static Future<void>? debugTextureDelay;

  /// The texture of an endpoint as it paints now.
  Future<ui.Image> _endpointTexture(_AmbientFrame frame) async {
    final window = _window, scale = frostAmbientTextureScale(window);
    final picture = _endpointPicture(frame, window, scale);
    try {
      return await picture.toImage(math.max(1, (window.width * scale).ceil()), math.max(1, (window.height * scale).ceil()));
    } finally {
      picture.dispose();
    }
  }

  /// The texture of an endpoint that is not on screen yet. Withdrawn work
  /// never completes.
  Future<ui.Image?> _textureBeforeShowing(_AmbientFrame frame) async {
    final window = _window, scale = frostAmbientTextureScale(window);
    final recorded = Completer<ui.Picture>();
    frame.preparation = FrostFrameWorkQueue.enqueue(() {
      frame.preparation = null;
      recorded.complete(_endpointPicture(frame, window, scale));
    });
    final picture = await recorded.future;
    try {
      await debugTextureDelay;
      return await picture.toImage(math.max(1, (window.width * scale).ceil()), math.max(1, (window.height * scale).ceil()));
    } finally {
      picture.dispose();
    }
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
    final scale = frostAmbientTextureScale(window);
    frame.preparation?.cancel();
    frame.preparation = FrostFrameWorkQueue.enqueue(() {
      frame.preparation = null;
      _preparingTexture = true;
      unawaited(() async {
        final picture = _endpointPicture(frame, window, scale);
        ui.Image? texture;
        try {
          await debugTextureDelay;
          texture = await picture.toImage(math.max(1, (window.width * scale).ceil()), math.max(1, (window.height * scale).ceil()));
          if (_disposed || frame.textureEpoch != epoch || _frames.lastOrNull != frame) return;
          // Only two endpoint textures are retained. Rapid retargeting keeps
          // the original live paint for older, fading endpoints instead of
          // growing a texture cache without a bound.
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
    // The new endpoint enters as one draw, a prepared texture or a flat
    // colour, so the crossfade never paints it live through a layer.
    // A flat endpoint commits at once, in the frame that asked for it.
    ui.Image? texture;
    try {
      if (_needsTextureBeforeShowing(target)) texture = await _textureBeforeShowing(target);
    } catch (error, stack) {
      if (!target.disposed) {
        _pending = null;
        target.dispose();
        FlutterError.reportError(FlutterErrorDetails(exception: error, stack: stack, library: 'ambient endpoint preparation'));
      }
      return;
    }
    if (_disposed || target.disposed) {
      texture?.dispose();
      return;
    }
    // An endpoint on its way out blends too. One still painted live, such as
    // one whose glow has just faded in and whose texture is still preparing,
    // would fade out through a window-sized layer, so it is rasterized as it
    // shows now first.
    final outgoing = <_AmbientFrame, ui.Image>{};
    try {
      for (var index = 0; index < _frames.length; index++) {
        final frame = _frames[index];
        if (frame.texture != null || _weight(index) <= 0 || !_needsTextureBeforeShowing(frame)) continue;
        outgoing[frame] = await _endpointTexture(frame);
        if (_disposed || target.disposed) break;
      }
    } catch (error, stack) {
      FlutterError.reportError(FlutterErrorDetails(exception: error, stack: stack, library: 'ambient endpoint preparation'));
    }
    if (_disposed || target.disposed) {
      texture?.dispose();
      for (final image in outgoing.values) {
        image.dispose();
      }
      return;
    }
    for (final MapEntry(key: frame, value: image) in outgoing.entries) {
      if (frame.disposed || frame.texture != null) {
        image.dispose();
      } else {
        frame.texture = image;
      }
    }
    target.texture = texture;
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
    // Only two endpoint textures are retained, the newest ones.
    final cached = _frames.where((frame) => frame.texture != null).toList();
    for (final old in cached.take((cached.length + (target.texture == null ? 0 : 1) - _ambientTextureCapacity).clamp(0, cached.length))) {
      old.texture?.dispose();
      old.texture = null;
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

  // Completes when the crossfade in progress ends.
  Completer<void>? _resting;

  void _setProgress(double value) {
    if (_progress == value) return;
    _progress = value;
    if (value >= 1) {
      _resting?.complete();
      _resting = null;
    }
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
    _resting?.complete();
    _resting = null;
    frostAmbientGrain.removeListener(notifyListeners);
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
              FrostAmbientCardScope(
                registry: _controller._cards,
                media: _controller._media,
                mediaRects: _controller._mediaRects,
                // Content lying on the window fades its edges into the art.
                child: FrostBackdropVeilScope(
                  veil: _AmbientVeil(
                    controller: _controller,
                    tokens: FrostThemeTokens.of(context),
                    plain: FrostScope.solidSurfaces(context),
                    systemBackdrop: !FrostScope.solidSurfaces(context) && widget.intensity != 0 && FrostWindowCaptionScope.systemBackdropActiveOf(context),
                  ),
                  child: child!,
                ),
              ),
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
    return _ambientPaint(context, 1);
  }
}

/// The window backdrop a moving page carries, faded by its own paint alpha
/// rather than inside an opacity layer, so a page transition composites no
/// window-sized offscreen buffer for it.
class FrostFadingAmbientBackdrop extends StatelessWidget {
  const FrostFadingAmbientBackdrop({required this.opacity, super.key});
  final double opacity;

  @override
  Widget build(BuildContext context) => _ambientPaint(context, opacity);
}

/// Whether a backdrop painted here at full opacity hides what lies below it.
/// Over a system backdrop, endpoints without artwork leave the window to the
/// system and hide nothing.
bool frostAmbientBackdropCovers(BuildContext context) {
  if (FrostScope.solidSurfaces(context)) return true;
  final scope = context.dependOnInheritedWidgetOfExactType<_AmbientScope>();
  if ((scope?.forceSolid ?? false) || !FrostWindowCaptionScope.systemBackdropActiveOf(context)) return true;
  final controller = scope?.controller;
  if (controller == null) return false;
  final frames = controller._frames;
  var covered = false;
  for (var index = 0; index < frames.length; index++) {
    if (controller._weight(index) <= 0) continue;
    if (frames[index].image == null && !frames[index].accentFallback) return false;
    covered = true;
  }
  return covered;
}

Widget _ambientPaint(BuildContext context, double opacity) {
  final tokens = FrostThemeTokens.of(context);
  final plain = FrostScope.solidSurfaces(context);
  final scope = context.dependOnInheritedWidgetOfExactType<_AmbientScope>();
  // No repaint boundary here: the backdrop is window-aligned, so it has to
  // repaint when an ancestor transition moves it.
  // Reduced transparency still follows the controller, painting each
  // endpoint as one opaque palette fill.
  return _AmbientPaint(
    controller: scope?.controller,
    tokens: tokens,
    plain: plain,
    systemBackdrop: !plain && !(scope?.forceSolid ?? false) && FrostWindowCaptionScope.systemBackdropActiveOf(context),
    opacity: opacity.clamp(0.0, 1.0),
  );
}

/// The draws that make up the ambient picture, bottom first, each with the
/// alpha that lays it over the ones before it, and the live grain's opacity;
/// null when nothing is painted.
///
/// An endpoint is a flat colour or a texture, and one whose glow is fading in
/// over a prepared texture is that texture over the draw it fades from. Only
/// an endpoint with neither is painted live (null).
({List<(_AmbientFrame, Object?, double)> draws, double grain})? _ambientDraws(
  FrostAmbientBackdropController controller, {
  required bool plain,
  required bool systemBackdrop,
  required double opacity,
}) {
  final frames = controller._frames;
  final draws = <(_AmbientFrame, Object?, double)>[];
  var total = 0.0;
  for (var index = 0; index < frames.length; index++) {
    final frame = frames[index], weight = controller._weight(index);
    if (weight <= 0 || (systemBackdrop && frame.image == null && !frame.accentFallback)) continue;
    total += weight;
    if (_RenderAmbient._flatColor(frame, solid: plain) case final color?) {
      draws.add((frame, color, weight));
    } else if (frame.texture case final texture?) {
      if (frame.glowFrom case final from? when frame.glowFade < 1) draws.add((frame, from, weight * (1 - frame.glowFade)));
      draws.add((frame, texture, frame.glowFrom != null && frame.glowFade < 1 ? weight * frame.glowFade : weight));
    } else {
      draws.add((frame, null, weight));
    }
  }
  if (total == 0) return null;
  final scale = total.clamp(0.0, 1.0) * opacity;
  // Each draw's share of the picture is its weight, scaled to the picture's
  // opacity. Retargeting retains the current weighted picture instead of
  // jumping to the old target. Laying each draw over the ones before it with
  // an alpha solved from the top gives it that share without an opacity
  // buffer: its share is its alpha times what the draws above it let
  // through.
  final shares = [for (final (_, _, weight) in draws) scale * weight / total];
  final alphas = List.filled(draws.length, 0.0);
  var through = 1.0;
  for (var index = draws.length - 1; index >= 0; index--) {
    alphas[index] = through <= 0 ? 0 : (shares[index] / through).clamp(0.0, 1.0);
    through *= 1 - alphas[index];
  }
  var grain = 0.0;
  for (var index = 0; index < draws.length; index++) {
    if (alphas[index] > 0 && draws[index].$2 is ui.Image && !draws[index].$1.tokens.isDark) grain += shares[index];
  }
  return (draws: [for (var index = 0; index < draws.length; index++) (draws[index].$1, draws[index].$2, alphas[index])], grain: grain.clamp(0.0, 1.0));
}

/// The rect of a window of [window] size in [box]'s paint coordinates at [offset].
Rect _ambientWindowRect(Size window, RenderBox box, Offset offset) {
  final toWindow = Matrix4.tryInvert(box.getTransformTo(null));
  return toWindow == null ? (offset - box.localToGlobal(Offset.zero)) & window : MatrixUtils.transformRect(toWindow, Offset.zero & window).shift(offset);
}

/// The window's ambient backdrop laid over content near an edge, as the same
/// draws the backdrop is made of, each faded across the strip. At rest the
/// backdrop is one draw and the veil repaints it exactly; while it changes,
/// each draw is faded on its own, which is close to the crossfading picture.
class _AmbientVeil extends FrostBackdropVeil {
  const _AmbientVeil({required this.controller, required this.tokens, required this.plain, required this.systemBackdrop});
  final FrostAmbientBackdropController controller;
  final FrostThemeTokens tokens;
  final bool plain, systemBackdrop;

  @override
  bool reproducesBelow(BuildContext context) => frostAmbientBackdropCovers(context);

  @override
  Listenable get repaint => controller;

  @override
  void paint(Canvas canvas, RenderBox box, Offset offset, Rect strip, Offset opaqueAt, Offset clearAt) {
    if (controller._frames.isEmpty) return FrostBackdropVeil.drawColor(canvas, strip, opaqueAt, clearAt, tokens.canvas);
    final picture = _ambientDraws(controller, plain: plain, systemBackdrop: systemBackdrop, opacity: 1);
    if (picture == null) return;
    // Textures are prepared for this window size.
    final windowRect = _ambientWindowRect(controller._window.isEmpty ? box.size : controller._window, box, offset);
    for (final (frame, draw, alpha) in picture.draws) {
      if (alpha <= 0) continue;
      switch (draw) {
        case final Color color:
          FrostBackdropVeil.drawColor(canvas, strip, opaqueAt, clearAt, color.withValues(alpha: color.a * alpha));
        case final ui.Image texture:
          final matrix = Matrix4.translationValues(windowRect.left, windowRect.top, 0)
            ..scaleByDouble(windowRect.width / texture.width, windowRect.height / texture.height, 1, 1);
          FrostBackdropVeil.drawShaded(canvas, strip, opaqueAt, clearAt, ImageShader(texture, TileMode.clamp, TileMode.clamp, matrix.storage), alpha: alpha);
        default:
          // A live endpoint is rare and short; its canvas stands in for it.
          FrostBackdropVeil.drawColor(canvas, strip, opaqueAt, clearAt, frame.tokens.canvas.withValues(alpha: frame.tokens.canvas.a * alpha));
      }
    }
    if (picture.grain > 0) {
      if (frostAmbientGrain.value case final grain?) {
        final pixelRatio = controller._pixelRatio;
        final scale = Matrix4.diagonal3Values(1 / pixelRatio, 1 / pixelRatio, 1);
        FrostBackdropVeil.drawShaded(
          canvas,
          strip,
          opaqueAt,
          clearAt,
          ImageShader(grain, TileMode.repeated, TileMode.repeated, scale.storage),
          alpha: picture.grain,
          blendMode: BlendMode.difference,
        );
      }
    }
  }

  @override
  bool operator ==(Object other) =>
      other is _AmbientVeil && other.controller == controller && other.tokens == tokens && other.plain == plain && other.systemBackdrop == systemBackdrop;

  @override
  int get hashCode => Object.hash(controller, tokens, plain, systemBackdrop);
}

class _AmbientPaint extends LeafRenderObjectWidget {
  const _AmbientPaint({required this.controller, required this.tokens, required this.plain, required this.systemBackdrop, required this.opacity});

  final FrostAmbientBackdropController? controller;
  final FrostThemeTokens tokens;
  final bool plain;
  final bool systemBackdrop;
  final double opacity;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderAmbient(controller: controller, tokens: tokens, plain: plain, systemBackdrop: systemBackdrop).._opacity = opacity;

  @override
  void updateRenderObject(BuildContext context, _RenderAmbient renderObject) {
    renderObject
      ..controller = controller
      ..tokens = tokens
      ..plain = plain
      ..systemBackdrop = systemBackdrop
      ..opacity = opacity;
  }
}

class _RenderAmbient extends RenderBox {
  _RenderAmbient({required FrostAmbientBackdropController? controller, required FrostThemeTokens tokens, required bool plain, required bool systemBackdrop})
    : this._(controller, tokens, plain, systemBackdrop);
  _RenderAmbient._(this._controller, this._tokens, this._plain, this._systemBackdrop);

  // The whole picture's alpha, applied to each draw.
  double _opacity = 1;
  set opacity(double value) {
    if (value == _opacity) return;
    _opacity = value;
    markNeedsPaint();
  }

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
    if (_opacity <= 0) return;
    if (_controller == null || _controller!._frames.isEmpty) {
      canvas.drawRect(local, Paint()..color = _tokens.canvas.withValues(alpha: _tokens.canvas.a * _opacity));
      return;
    }
    final picture = _ambientDraws(_controller!, plain: _plain, systemBackdrop: _systemBackdrop, opacity: _opacity);
    if (picture == null) return;
    final view = ui.PlatformDispatcher.instance.implicitView;
    final windowRect = _ambientWindowRect(view == null ? size : view.physicalSize / view.devicePixelRatio, this, offset);
    final pixelRatio = view?.devicePixelRatio ?? 1;
    canvas.save();
    canvas.clipRect(local);
    for (final (frame, draw, alpha) in picture.draws) {
      if (alpha <= 0) continue;
      switch (draw) {
        case final Color color:
          canvas.drawRect(local, Paint()..color = color.withValues(alpha: color.a * alpha));
        case final ui.Image texture:
          canvas.drawImageRect(
            texture,
            Rect.fromLTWH(0, 0, texture.width.toDouble(), texture.height.toDouble()),
            windowRect,
            Paint()
              ..filterQuality = FilterQuality.medium
              ..color = Color.fromRGBO(0, 0, 0, alpha),
          );
        default:
          // Painted live in several draws, which fade as one.
          if (alpha < 1) canvas.saveLayer(local, Paint()..color = Color.fromRGBO(0, 0, 0, alpha));
          _paintEndpoint(canvas, frame, local, windowRect, pixelRatio: pixelRatio);
          if (alpha < 1) canvas.restore();
      }
    }
    if (picture.grain > 0) frostPaintAmbientGrain(canvas, local, pixelRatio, opacity: picture.grain);
    canvas.restore();
  }

  /// The one colour [frame] paints, or null when it paints more than that.
  static Color? _flatColor(_AmbientFrame frame, {required bool solid}) {
    final material = frame.material;
    if (solid) {
      // Reduced transparency: the palette's weighted mean as one opaque fill.
      final fill = material?.solid;
      return fill == null ? frame.tokens.canvas : Color.lerp(frame.tokens.canvas, fill, frame.intensity)!;
    }
    if (frame.intensity <= 0 || material == null || material.palette.isEmpty && !frame.accentFallback) return frame.tokens.canvas;
    // Dark before its glow field arrives: the canvas under the wash.
    if (frame.tokens.isDark && material.palette.isNotEmpty && frame.glow == null && frame.glowPrevious == null) {
      final wash = _washOf(frame, material);
      return wash == null ? frame.tokens.canvas : Color.alphaBlend(wash, frame.tokens.canvas);
    }
    return null;
  }

  /// The tint laid over a palette endpoint: the mean of its colours.
  static Color? _washOf(_AmbientFrame frame, FrostAmbientMaterials material) {
    final colors = frame.tokens.isDark ? frostAmbientGlowPeaks(frame.tokens, material.raw, free: true) : material.palette.map((entry) => entry.color).toList();
    if (colors.isEmpty) return null;
    return Color.from(
      alpha: .20 * frame.intensity,
      red: colors.fold(0.0, (sum, color) => sum + color.r) / colors.length,
      green: colors.fold(0.0, (sum, color) => sum + color.g) / colors.length,
      blue: colors.fold(0.0, (sum, color) => sum + color.b) / colors.length,
    );
  }

  static void _paintEndpoint(Canvas canvas, _AmbientFrame frame, Rect local, Rect windowRect, {double pixelRatio = 1, bool grain = true}) {
    if (_flatColor(frame, solid: false) case final color?) {
      canvas.drawRect(local, Paint()..color = color);
      return;
    }
    final material = frame.material!;
    canvas.drawRect(local, Paint()..color = frame.tokens.canvas);
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
    } else {
      // No usable artwork colour: the accent-tinted mesh.
      frostPaintAmbientMesh(canvas, local, windowRect, frame.tokens, frame.intensity);
    }
    if (material.palette.isNotEmpty) {
      if (_washOf(frame, material) case final wash?) canvas.drawRect(local, Paint()..color = wash);
    }
    // Light grain; a prepared texture leaves it out and has it painted live.
    if (grain) frostPaintAmbientGrain(canvas, local, pixelRatio, dark: frame.tokens.isDark);
  }
}
