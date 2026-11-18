import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

/// Paints again what lies directly behind some content, over that content, so
/// an edge can fade into the backdrop by drawing over it instead of masking
/// the content through an offscreen layer.
abstract class FrostBackdropVeil {
  const FrostBackdropVeil();

  /// The opaque backdrop drawn by one colour.
  const factory FrostBackdropVeil.solid(Color color) = _SolidVeil;

  /// A translucent [fill] laid over the window backdrop, which [below]
  /// reproduces. Its fill follows the art's fade, so an edge over it keeps
  /// its mask; a moving page still carries it as its ground.
  const factory FrostBackdropVeil.windowLayer(Color fill, FrostBackdropVeil? below) = _WindowLayerVeil;

  /// Whether this veil reproduces the backdrop below [context]. A veil that
  /// cannot (a system backdrop shows through) leaves the edge to a mask.
  bool reproducesBelow(BuildContext context) => true;

  /// The plain colour this backdrop lays over the window backdrop: opaque for
  /// a solid fill, translucent for a window layer, or null where content lies
  /// on the window backdrop itself.
  Color? get groundFill => null;

  /// Notifies when the backdrop changes.
  Listenable? get repaint => null;

  /// Paints the backdrop over [strip], in [box]'s paint coordinates at
  /// [offset], fully at [opaqueAt] and not at all at [clearAt], linearly in
  /// between.
  void paint(Canvas canvas, RenderBox box, Offset offset, Rect strip, Offset opaqueAt, Offset clearAt);

  /// Linear coverage at [point], 1 at [opaqueAt] and 0 at [clearAt].
  static double coverageAt(Offset point, Offset opaqueAt, Offset clearAt) {
    final axis = clearAt - opaqueAt;
    final length = axis.distanceSquared;
    if (length == 0) return 0;
    final along = ((point - opaqueAt).dx * axis.dx + (point - opaqueAt).dy * axis.dy) / length;
    return (1 - along).clamp(0.0, 1.0);
  }

  /// Draws [shader] over [strip] with linear coverage times [alpha], as two
  /// triangles whose corners carry the coverage. [blendMode] lays the result
  /// on the canvas.
  static void drawShaded(
    Canvas canvas,
    Rect strip,
    Offset opaqueAt,
    Offset clearAt,
    Shader shader, {
    double alpha = 1,
    BlendMode blendMode = BlendMode.srcOver,
  }) {
    final corners = [strip.topLeft, strip.topRight, strip.bottomRight, strip.bottomLeft];
    final vertices = ui.Vertices(
      ui.VertexMode.triangles,
      corners,
      colors: [for (final corner in corners) Color.fromRGBO(255, 255, 255, alpha * coverageAt(corner, opaqueAt, clearAt))],
      indices: const [0, 1, 2, 0, 2, 3],
    );
    canvas.drawVertices(
      vertices,
      BlendMode.modulate,
      Paint()
        ..shader = shader
        ..blendMode = blendMode
        ..filterQuality = FilterQuality.medium,
    );
    vertices.dispose();
  }

  /// Draws [color] over [strip] with linear coverage.
  static void drawColor(Canvas canvas, Rect strip, Offset opaqueAt, Offset clearAt, Color color) {
    if (color.a <= 0) return;
    canvas.drawRect(strip, Paint()..shader = ui.Gradient.linear(opaqueAt, clearAt, [color, color.withValues(alpha: 0)]));
  }
}

class _SolidVeil extends FrostBackdropVeil {
  const _SolidVeil(this.color);
  final Color color;

  @override
  Color get groundFill => color;

  @override
  void paint(Canvas canvas, RenderBox box, Offset offset, Rect strip, Offset opaqueAt, Offset clearAt) =>
      FrostBackdropVeil.drawColor(canvas, strip, opaqueAt, clearAt, color);

  @override
  bool operator ==(Object other) => other is _SolidVeil && other.color == color;

  @override
  int get hashCode => color.hashCode;
}

class _WindowLayerVeil extends FrostBackdropVeil {
  const _WindowLayerVeil(this.fill, this.below);
  final Color fill;
  final FrostBackdropVeil? below;

  @override
  bool reproducesBelow(BuildContext context) => false;

  @override
  Color get groundFill => fill;

  @override
  Listenable? get repaint => below?.repaint;

  @override
  void paint(Canvas canvas, RenderBox box, Offset offset, Rect strip, Offset opaqueAt, Offset clearAt) {
    below?.paint(canvas, box, offset, strip, opaqueAt, clearAt);
    FrostBackdropVeil.drawColor(canvas, strip, opaqueAt, clearAt, fill);
  }

  @override
  bool operator ==(Object other) => other is _WindowLayerVeil && other.fill == fill && other.below == below;

  @override
  int get hashCode => Object.hash(fill, below);
}

/// Says what lies directly behind the content below it. Whatever paints a
/// backdrop for content (the window's ambient art, an opaque page or surface
/// fill) provides one; whatever paints something a veil cannot repaint (glass,
/// a translucent fill, media) provides none.
class FrostBackdropVeilScope extends InheritedWidget {
  const FrostBackdropVeilScope({required this.veil, required super.child, super.key});
  final FrostBackdropVeil? veil;

  /// The veil for content at [context], or null when an edge there has to be
  /// masked.
  static FrostBackdropVeil? of(BuildContext context) {
    final veil = context.dependOnInheritedWidgetOfExactType<FrostBackdropVeilScope>()?.veil;
    return veil != null && veil.reproducesBelow(context) ? veil : null;
  }

  @override
  bool updateShouldNotify(FrostBackdropVeilScope oldWidget) => veil != oldWidget.veil;
}
