import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../foundation/_ambient_material.dart';

import '../foundation/scope.dart';
import '../foundation/tokens.dart';
import '../layout/window_caption_scope.dart';

/// Internal window-base availability, updated when an ambient image resolves.
class FrostWindowBackgroundScope extends InheritedWidget {
  const FrostWindowBackgroundScope({
    required this.hasAmbient,
    required super.child,
    this.forceSolidBase = false,
    this.background,
    this.ambientWeight = 1,
    super.key,
  });
  final bool hasAmbient;

  /// How far the ambient art has faded in while [hasAmbient]: 0 at the start
  /// of a fade in and the end of a fade out, 1 at rest.
  final double ambientWeight;
  final bool forceSolidBase;
  final Color? background;
  static FrostWindowBackgroundScope? maybeOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<FrostWindowBackgroundScope>();
  @override
  bool updateShouldNotify(FrostWindowBackgroundScope oldWidget) =>
      hasAmbient != oldWidget.hasAmbient ||
      ambientWeight != oldWidget.ambientWeight ||
      forceSolidBase != oldWidget.forceSolidBase ||
      background != oldWidget.background;
}

bool frostHasTranslucentWindowBase(BuildContext context) =>
    !FrostScope.solidSurfaces(context) &&
    !(FrostWindowBackgroundScope.maybeOf(context)?.forceSolidBase ?? false) &&
    ((context.dependOnInheritedWidgetOfExactType<FrostWindowBackgroundScope>()?.hasAmbient ?? false) ||
        FrostWindowCaptionScope.systemBackdropActiveOf(context));

/// Target theme, independent of AnimatedTheme's intermediate paint frames.
class FrostAmbientThemeScope extends InheritedWidget {
  const FrostAmbientThemeScope({required this.tokens, required super.child, super.key});
  final FrostThemeTokens tokens;
  @override
  bool updateShouldNotify(FrostAmbientThemeScope oldWidget) =>
      tokens.brightness != oldWidget.tokens.brightness ||
      tokens.tone != oldWidget.tokens.tone ||
      tokens.canvas != oldWidget.tokens.canvas ||
      tokens.surface != oldWidget.tokens.surface ||
      tokens.textPrimary != oldWidget.tokens.textPrimary ||
      tokens.textSecondary != oldWidget.tokens.textSecondary ||
      tokens.accent != oldWidget.tokens.accent;
}

/// Plain window background (no ambient host): the static accent-tinted mesh
/// with the light grain; reduced transparency keeps the flat canvas.
class FrostWindowBaseMesh extends StatelessWidget {
  const FrostWindowBaseMesh({required this.opacity, super.key});
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final tokens = FrostThemeTokens.of(context);
    if (FrostScope.solidSurfaces(context)) {
      return ColoredBox(color: tokens.canvas.withValues(alpha: opacity));
    }
    return Opacity(
      opacity: opacity,
      child: CustomPaint(painter: _MeshPainter(tokens, MediaQuery.devicePixelRatioOf(context)), child: const SizedBox.expand()),
    );
  }
}

class _MeshPainter extends CustomPainter {
  _MeshPainter(this.tokens, this.pixelRatio) : super(repaint: frostAmbientGrain);
  final FrostThemeTokens tokens;
  final double pixelRatio;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = tokens.canvas);
    frostPaintAmbientMesh(canvas, rect, rect, tokens, 1);
    frostPaintAmbientGrain(canvas, rect, pixelRatio, dark: tokens.isDark);
  }

  @override
  bool shouldRepaint(_MeshPainter old) => tokens != old.tokens || pixelRatio != old.pixelRatio;
}

// Frames drawn so far, counted once each frame's build, layout and paint are
// done. Frame timestamps cannot tell frames apart: a warm-up frame reuses the
// previous one's.
int _framesDrawn = 0;
bool _countingFrames = false;

// The frame being drawn, or after its paint, the latest one drawn.
int _frostFrame() {
  final scheduler = SchedulerBinding.instance;
  if (!_countingFrames) {
    _countingFrames = true;
    // Registered after the binding's own, so it runs after the paint.
    scheduler.addPersistentFrameCallback((_) => _framesDrawn++);
  }
  return scheduler.schedulerPhase == SchedulerPhase.persistentCallbacks ? _framesDrawn : _framesDrawn - 1;
}

/// The window's registered cards, which keep the lower glow peak.
///
/// Opaque, raised [FrostSurface]s register their render boxes while they are
/// attached. [rects] reads their current window rects, rounded to whole
/// logical pixels; after every frame that changes them [onChange] runs.
class FrostAmbientCardRegistry {
  FrostAmbientCardRegistry(this.onChange);
  final VoidCallback onChange;
  final _boxes = <FrostRenderAmbientCard>{};
  List<Rect> _last = const [];

  /// The rects seen after the latest frame.
  List<Rect> get current => _last;
  bool _watching = false, _disposed = false;

  /// How many registered boxes have had their window rect computed, across
  /// all registries. Boxes that do not paint on screen are not counted.
  @visibleForTesting
  static int debugRectEvaluations = 0;

  void _add(FrostRenderAmbientCard box) {
    _boxes.add(box);
    _evaluated = null;
    _watch(schedule: true);
  }

  void _remove(FrostRenderAmbientCard box) {
    _boxes.remove(box);
    _evaluated = null;
    _watch(schedule: true);
  }

  // Every chrome guard of a frame and the check after it share one reading
  // per phase of that frame: the paint phase, then the post-frame callbacks.
  List<Rect>? _evaluated;
  (int, SchedulerPhase)? _evaluatedIn;

  /// The painted window rects of the registered boxes, read live. Call after
  /// layout.
  List<Rect> _painted() {
    final phase = SchedulerBinding.instance.schedulerPhase;
    final key = (_frostFrame(), phase);
    // Outside a frame, nothing marks a change, so read afresh.
    final cacheable = phase == SchedulerPhase.persistentCallbacks || phase == SchedulerPhase.postFrameCallbacks;
    if (cacheable && _evaluatedIn == key && _evaluated != null) return _evaluated!;
    final placements = <RenderObject, _Placement>{};
    final result = <Rect>[];
    for (final box in _boxes) {
      if (box._paintedWindowRect(placements) case final rect?) result.add(rect);
    }
    if (cacheable) {
      _evaluated = result;
      _evaluatedIn = key;
    }
    return result;
  }

  /// Whether a registered box overlaps [rect] now, read live. Call after
  /// layout; while some box's ancestors are not laid out, nothing overlaps.
  bool overlaps(Rect rect) {
    final List<Rect> painted;
    try {
      painted = _painted();
    } on FlutterError {
      return false;
    } on AssertionError {
      return false;
    }
    for (final bounds in painted) {
      final overlap = bounds.intersect(rect);
      if (overlap.width > 0 && overlap.height > 0) return true;
    }
    return false;
  }

  /// Rects of the registered boxes within [window], in window coordinates.
  List<Rect> rects(Size window) {
    final bounds = Offset.zero & window;
    final result = <Rect>[];
    for (final rect in _painted()) {
      if (!rect.overlaps(bounds)) continue;
      final clipped = rect.intersect(bounds);
      result.add(Rect.fromLTRB(clipped.left.roundToDouble(), clipped.top.roundToDouble(), clipped.right.roundToDouble(), clipped.bottom.roundToDouble()));
    }
    result.sort((a, b) => a.top != b.top ? a.top.compareTo(b.top) : a.left.compareTo(b.left));
    return result;
  }

  // Rects move without repainting their boxes (scrolling reuses layers), so
  // compare after each frame instead of at paint time.
  void _watch({bool schedule = false}) {
    if (_disposed) return;
    // Only a registration change asks for a frame; otherwise wait for one.
    if (schedule) WidgetsBinding.instance.ensureVisualUpdate();
    if (_watching) return;
    _watching = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _watching = false;
      if (_disposed) return;
      final view = WidgetsBinding.instance.platformDispatcher.implicitView;
      final current = view == null ? const <Rect>[] : rects(view.physicalSize / view.devicePixelRatio);
      if (!frostAmbientSameRects(current, _last)) {
        _last = current;
        onChange();
      }
      if (_boxes.isNotEmpty) _watch();
    });
  }

  void dispose() => _disposed = true;
}

bool frostAmbientSameRects(List<Rect> a, List<Rect> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Provides the host's [FrostAmbientCardRegistry] to the surfaces below and,
/// a second one for opaque media, with its current rects.
class FrostAmbientCardScope extends InheritedWidget {
  const FrostAmbientCardScope({required this.registry, required super.child, this.media, this.mediaRects, super.key});
  final FrostAmbientCardRegistry registry;
  final FrostAmbientCardRegistry? media;
  final ValueListenable<List<Rect>>? mediaRects;
  static FrostAmbientCardRegistry? maybeOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<FrostAmbientCardScope>()?.registry;
  static FrostAmbientCardScope? scopeOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<FrostAmbientCardScope>();
  @override
  bool updateShouldNotify(FrostAmbientCardScope oldWidget) =>
      !identical(registry, oldWidget.registry) || !identical(media, oldWidget.media) || !identical(mediaRects, oldWidget.mediaRects);
}

/// Registers opaque media (frames, cards, detail stages) so chrome
/// over them can fall back to the black/white-safe fill.
class FrostAmbientMediaRegistration extends StatelessWidget {
  const FrostAmbientMediaRegistration({required this.child, super.key});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final media = FrostAmbientCardScope.scopeOf(context)?.media;
    return media == null ? child : FrostAmbientCardRegistration(registry: media, child: child);
  }
}

/// Registers [child]'s box with the nearest card registry.
class FrostAmbientCardRegistration extends SingleChildRenderObjectWidget {
  const FrostAmbientCardRegistration({required this.registry, required super.child, super.key});
  final FrostAmbientCardRegistry registry;

  @override
  RenderObject createRenderObject(BuildContext context) => FrostRenderAmbientCard(registry);

  @override
  void updateRenderObject(BuildContext context, FrostRenderAmbientCard renderObject) => renderObject.registry = registry;
}

class FrostRenderAmbientCard extends RenderProxyBox {
  FrostRenderAmbientCard(this._registry);
  FrostAmbientCardRegistry _registry;
  set registry(FrostAmbientCardRegistry value) {
    if (identical(value, _registry)) return;
    if (attached) {
      _registry._remove(this);
      value._add(this);
    }
    _registry = value;
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _registry._add(this);
  }

  @override
  void detach() {
    _registry._remove(this);
    super.detach();
  }

  int? _paintedIn;

  @override
  void paint(PaintingContext context, Offset offset) {
    _paintedIn = _frostFrame();
    super.paint(context, offset);
  }

  // Whether this box is in the picture of the latest frame. Parents up to the
  // nearest repaint boundary say whether they paint it. Above that, the
  // boundary's layer is in the composited tree only while every ancestor
  // paints it: a page covered by another, an offstage subtree, or a scroll
  // view's cache leaves it out without saying so through paintsChild. A box
  // painted in this frame counts while its new layers are still on their way
  // into the tree.
  bool get _onScreen {
    RenderObject child = this;
    RenderObject? boundary = isRepaintBoundary ? this : null;
    for (var parent = this.parent; boundary == null && parent != null; child = parent, parent = parent.parent) {
      if (!parent.paintsChild(child)) return false;
      // An indexed stack paints one child without saying so through paintsChild.
      if (parent is RenderIndexedStack && parent.getChildrenAsList().indexOf(child as RenderBox) != parent.index) return false;
      if (parent.isRepaintBoundary) boundary = parent;
    }
    if (_paintedIn == _frostFrame()) return true;
    return boundary?.layer?.attached ?? false;
  }

  /// The part of this box that paints, in window coordinates: nothing on a
  /// hidden page, or in a scroll view's cache, where it is laid out and clipped
  /// away. [placements] keeps the ancestors' placements for the other boxes.
  Rect? _paintedWindowRect(Map<RenderObject, _Placement> placements) {
    if (!attached || !hasSize || !_onScreen) return null;
    FrostAmbientCardRegistry.debugRectEvaluations++;
    final placement = _Placement.of(this, placements);
    final bounds = MatrixUtils.transformRect(placement.transform, Offset.zero & size);
    final painted = placement.clip == null ? bounds : bounds.intersect(placement.clip!);
    return painted.width > 0 && painted.height > 0 ? painted : null;
  }
}

/// A render object's paint transform to the window and the clip its ancestors
/// apply to it there.
class _Placement {
  const _Placement(this.transform, this.clip);
  final Matrix4 transform;
  final Rect? clip;

  // Ancestors shared by several boxes are placed once.
  static _Placement of(RenderObject object, Map<RenderObject, _Placement> placements) {
    if (placements[object] case final known?) return known;
    final parent = object.parent;
    final _Placement placement;
    if (parent == null) {
      placement = _Placement(Matrix4.identity(), null);
    } else {
      final above = of(parent, placements);
      final transform = above.transform.clone();
      // Window coordinates are the root's own, as for getTransformTo(null):
      // the root's transform to the device is not applied.
      if (parent.parent != null) parent.applyPaintTransform(object, transform);
      var clip = above.clip;
      if (parent.describeApproximatePaintClip(object) case final local?) {
        final window = MatrixUtils.transformRect(above.transform, local);
        clip = clip == null ? window : clip.intersect(window);
      }
      placement = _Placement(transform, clip);
    }
    return placements[object] = placement;
  }
}

/// Chrome over media. Runs at paint time, after layout, so it sees
/// where the media is in this frame: when a registered media rect overlaps
/// it, it paints the extra fill that brings the chrome from [fillAlpha] to
/// [safeAlpha] at once, then [onCovered] lets the surface take that alpha
/// itself. It repaints with every frame while media is registered, without
/// asking for frames of its own; give it a child that is a repaint boundary,
/// so that repaint stays within the guard.
class FrostChromeMediaGuard extends SingleChildRenderObjectWidget {
  const FrostChromeMediaGuard({
    required this.registry,
    required this.color,
    required this.fillAlpha,
    required this.safeAlpha,
    required this.onCovered,
    required super.child,
    super.key,
  });
  final FrostAmbientCardRegistry registry;
  final Color color;
  final double fillAlpha, safeAlpha;
  final VoidCallback onCovered;

  @override
  RenderObject createRenderObject(BuildContext context) => FrostRenderChromeMediaGuard(registry, color, fillAlpha, safeAlpha, onCovered);

  @override
  void updateRenderObject(BuildContext context, FrostRenderChromeMediaGuard renderObject) {
    renderObject
      ..registry = registry
      ..color = color
      ..fillAlpha = fillAlpha
      ..safeAlpha = safeAlpha
      ..onCovered = onCovered;
  }
}

class FrostRenderChromeMediaGuard extends RenderProxyBox {
  FrostRenderChromeMediaGuard(this.registry, this._color, this._fillAlpha, this._safeAlpha, this.onCovered);
  FrostAmbientCardRegistry registry;
  VoidCallback onCovered;
  Color _color;
  set color(Color value) {
    if (value == _color) return;
    _color = value;
    markNeedsPaint();
  }

  double _fillAlpha, _safeAlpha;
  set fillAlpha(double value) {
    if (value == _fillAlpha) return;
    _fillAlpha = value;
    markNeedsPaint();
  }

  set safeAlpha(double value) {
    if (value == _safeAlpha) return;
    _safeAlpha = value;
    markNeedsPaint();
  }

  bool _covered = false;
  int? _tick;

  // The per-frame repaint below records the extra fill and nothing else: the
  // chrome's content sits behind a boundary of its own (see FrostSurface).
  @override
  bool get isRepaintBoundary => true;

  /// The chrome's composed fill alpha in the latest paint.
  @visibleForTesting
  double debugEffectiveAlpha = 0;

  // Media moves without repainting this box (scrolling reuses layers), so
  // mark it for paint at the start of every frame that happens anyway.
  void _everyFrame(Duration _) {
    _tick = null;
    if (!attached) return;
    if (registry._boxes.isNotEmpty) markNeedsPaint();
    _tick = SchedulerBinding.instance.scheduleFrameCallback(_everyFrame, scheduleNewFrame: false);
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _tick ??= SchedulerBinding.instance.scheduleFrameCallback(_everyFrame, scheduleNewFrame: false);
  }

  @override
  void detach() {
    if (_tick case final id?) SchedulerBinding.instance.cancelFrameCallbackWithId(id);
    _tick = null;
    super.detach();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final own = MatrixUtils.transformRect(getTransformTo(null), Offset.zero & size);
    final covered = registry.overlaps(own);
    var extra = 0.0;
    if (covered && _fillAlpha < _safeAlpha) {
      // 1 − (1 − fill)(1 − extra) = safe.
      extra = (_safeAlpha - _fillAlpha) / (1 - _fillAlpha);
      context.canvas.drawRect(offset & size, Paint()..color = _color.withValues(alpha: extra));
    }
    debugEffectiveAlpha = 1 - (1 - _fillAlpha) * (1 - extra);
    if (covered != _covered) {
      _covered = covered;
      SchedulerBinding.instance.addPostFrameCallback((_) => onCovered());
    }
    super.paint(context, offset);
  }
}

/// How far the translucent window base stands in for the opaque one: 0
/// without it, 1 at rest, and the ambient art's fade progress while it comes
/// or goes. A system backdrop is always at rest.
double frostWindowBaseWeight(BuildContext context) {
  if (!frostHasTranslucentWindowBase(context)) return 0;
  if (FrostWindowCaptionScope.systemBackdropActiveOf(context)) return 1;
  // Translucent without a system backdrop means the ambient scope said so.
  return FrostWindowBackgroundScope.maybeOf(context)!.ambientWeight;
}

/// The colour behind a window-level surface: the ambient background mixed
/// with the canvas by how far the art has faded in, or null without one.
Color? frostWindowBackgroundOf(BuildContext context, FrostThemeTokens tokens) {
  final scope = FrostWindowBackgroundScope.maybeOf(context);
  final background = scope?.background;
  if (scope == null || background == null) return null;
  return Color.lerp(tokens.canvas, background, scope.ambientWeight);
}
