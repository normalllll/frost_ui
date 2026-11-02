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
  const FrostWindowBackgroundScope({required this.hasAmbient, required super.child, this.forceSolidBase = false, this.background, super.key});
  final bool hasAmbient;
  final bool forceSolidBase;
  final Color? background;
  static FrostWindowBackgroundScope? maybeOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<FrostWindowBackgroundScope>();
  @override
  bool updateShouldNotify(FrostWindowBackgroundScope oldWidget) =>
      hasAmbient != oldWidget.hasAmbient || forceSolidBase != oldWidget.forceSolidBase || background != oldWidget.background;
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

/// The window's registered cards, which keep the lower glow peak.
///
/// Opaque, raised [FrostSurface]s register their render boxes while they are
/// attached. [rects] reads their current window rects, rounded to whole
/// logical pixels; after every frame that changes them [onChange] runs.
class FrostAmbientCardRegistry {
  FrostAmbientCardRegistry(this.onChange);
  final VoidCallback onChange;
  final _boxes = <RenderBox>{};
  List<Rect> _last = const [];

  /// The rects seen after the latest frame.
  List<Rect> get current => _last;
  bool _watching = false, _disposed = false;

  void _add(RenderBox box) {
    _boxes.add(box);
    _watch(schedule: true);
  }

  void _remove(RenderBox box) {
    _boxes.remove(box);
    _watch(schedule: true);
  }

  /// The part of [box] that paints, in window coordinates: nothing on a hidden
  /// page, or in a scroll view's cache, where it is laid out and clipped away.
  static Rect? _painted(RenderBox box) {
    if (!box.attached || !box.hasSize) return null;
    var bounds = MatrixUtils.transformRect(box.getTransformTo(null), Offset.zero & box.size);
    RenderObject child = box;
    for (var parent = box.parent; parent != null; child = parent, parent = parent.parent) {
      if (!parent.paintsChild(child)) return null;
      // An indexed stack paints one child without saying so through paintsChild.
      if (parent is RenderIndexedStack && parent.getChildrenAsList().indexOf(child as RenderBox) != parent.index) return null;
      if (parent.describeApproximatePaintClip(child) case final clip?) {
        bounds = bounds.intersect(MatrixUtils.transformRect(parent.getTransformTo(null), clip));
      }
    }
    return bounds.width > 0 && bounds.height > 0 ? bounds : null;
  }

  /// Whether a registered box overlaps [rect] now, read live. Call after
  /// layout; a box whose ancestors are not laid out is skipped.
  bool overlaps(Rect rect) {
    for (final box in _boxes) {
      final Rect? bounds;
      try {
        bounds = _painted(box);
      } on FlutterError {
        continue;
      } on AssertionError {
        continue;
      }
      if (bounds == null) continue;
      final overlap = bounds.intersect(rect);
      if (overlap.width > 0 && overlap.height > 0) return true;
    }
    return false;
  }

  /// Rects of the registered boxes within [window], in window coordinates.
  List<Rect> rects(Size window) {
    final bounds = Offset.zero & window;
    final result = <Rect>[];
    for (final box in _boxes) {
      final rect = _painted(box);
      if (rect == null || !rect.overlaps(bounds)) continue;
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
}

/// Chrome over media. Runs at paint time, after layout, so it sees
/// where the media is in this frame: when a registered media rect overlaps
/// it, it paints the extra fill that brings the chrome from [fillAlpha] to
/// [safeAlpha] at once, then [onCovered] lets the surface take that alpha
/// itself. It repaints with every frame while media is registered, without
/// asking for frames of its own.
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
