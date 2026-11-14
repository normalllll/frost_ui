import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../foundation/tokens.dart';
import '../surface/_backdrop_veil.dart';

// Shared by shelves and thumbnail strips; fades reveal at most 24 logical pixels.
const _scrollFadeExtent = 24.0;

/// Reads final scroll geometry when painting, including the first layout.
/// While not [active], the child paints as it is, and keeps its state when
/// the fade comes back.
///
/// Over a backdrop that can be painted again (the window's ambient art, an
/// opaque page or surface fill) the edges fade by laying that backdrop over
/// the content, with no offscreen layer; elsewhere they mask the content.
class FrostScrollEdgeFade extends StatelessWidget {
  const FrostScrollEdgeFade({required this.controller, required this.child, this.repaint, this.active = true, super.key});
  final ScrollController controller;
  final Listenable? repaint;
  final bool active;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final veil = FrostBackdropVeilScope.of(context);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    // Left and right fade widths, each where content is hidden past that edge.
    EdgeInsets edges(Size size) {
      final position = controller.hasClients && controller.position.hasContentDimensions ? controller.position : null;
      final limit = math.min(_scrollFadeExtent, size.width / 2);
      final before = (position?.extentBefore ?? 0).clamp(0.0, limit);
      final after = (position?.extentAfter ?? 0).clamp(0.0, limit);
      return EdgeInsets.only(left: rtl ? after : before, right: rtl ? before : after);
    }

    return ListenableBuilder(
      listenable: Listenable.merge([controller, ?repaint, ?veil?.repaint]),
      builder: (context, child) => FrostEdgeFadeMask(
        fades: active,
        veil: veil,
        edges: edges,
        shader: (rect) {
          final fade = edges(rect.size);
          final opaque = FrostThemeTokens.of(context).canvas.withValues(alpha: 1), clear = opaque.withValues(alpha: 0);
          return LinearGradient(
            colors: [fade.left == 0 ? opaque : clear, opaque, opaque, fade.right == 0 ? opaque : clear],
            stops: [0, rect.width == 0 ? 0 : fade.left / rect.width, rect.width == 0 ? 1 : 1 - fade.right / rect.width, 1],
          ).createShader(rect);
        },
        child: child,
      ),
      child: child,
    );
  }
}

/// A mask that is in the tree whether or not it fades, so the content under it
/// keeps its state and focus as the fades come and go. It takes a layer only to
/// fade by [shader]; with a [veil] it fades each of [edges] by painting the
/// backdrop over the content instead.
class FrostEdgeFadeMask extends SingleChildRenderObjectWidget {
  const FrostEdgeFadeMask({required this.fades, required this.shader, this.veil, this.edges, required super.child, super.key})
    : assert(veil == null || edges != null, 'A veil fades the edges it is given.');
  final bool fades;
  final ShaderCallback shader;
  final FrostBackdropVeil? veil;
  final EdgeInsets Function(Size size)? edges;

  @override
  RenderObject createRenderObject(BuildContext context) => FrostRenderEdgeFadeMask(shader, fades)
    .._veil = veil
    .._edges = edges;

  @override
  void updateRenderObject(BuildContext context, FrostRenderEdgeFadeMask renderObject) => renderObject
    ..shaderCallback = shader
    ..fades = fades
    ..veil = veil
    ..edges = edges;
}

class FrostRenderEdgeFadeMask extends RenderShaderMask {
  FrostRenderEdgeFadeMask(ShaderCallback shader, this._fades) : super(shaderCallback: shader, blendMode: BlendMode.dstIn);
  bool _fades;
  set fades(bool value) {
    if (value == _fades) return;
    _fades = value;
    markNeedsCompositingBitsUpdate();
    markNeedsPaint();
  }

  FrostBackdropVeil? _veil;
  set veil(FrostBackdropVeil? value) {
    if (value == _veil) return;
    if ((value == null) != (_veil == null)) markNeedsCompositingBitsUpdate();
    _veil = value;
    markNeedsPaint();
  }

  EdgeInsets Function(Size size)? _edges;
  set edges(EdgeInsets Function(Size size)? value) {
    _edges = value;
    markNeedsPaint();
  }

  bool get _masks => _fades && _veil == null;

  @override
  bool get alwaysNeedsCompositing => _masks && super.alwaysNeedsCompositing;

  @override
  void paint(PaintingContext context, Offset offset) {
    if (_masks) return super.paint(context, offset);
    layer = null;
    final child = this.child;
    if (child == null) return;
    context.paintChild(child, offset);
    final veil = _veil, edges = _edges;
    if (!_fades || veil == null || edges == null) return;
    final fade = edges(size), bounds = offset & size;
    if (fade.left > 0) {
      final strip = Rect.fromLTRB(bounds.left, bounds.top, bounds.left + fade.left, bounds.bottom);
      veil.paint(context.canvas, this, offset, strip, strip.centerLeft, strip.centerRight);
    }
    if (fade.right > 0) {
      final strip = Rect.fromLTRB(bounds.right - fade.right, bounds.top, bounds.right, bounds.bottom);
      veil.paint(context.canvas, this, offset, strip, strip.centerRight, strip.centerLeft);
    }
    if (fade.top > 0) {
      final strip = Rect.fromLTRB(bounds.left, bounds.top, bounds.right, bounds.top + fade.top);
      veil.paint(context.canvas, this, offset, strip, strip.topCenter, strip.bottomCenter);
    }
    if (fade.bottom > 0) {
      final strip = Rect.fromLTRB(bounds.left, bounds.bottom - fade.bottom, bounds.right, bounds.bottom);
      veil.paint(context.canvas, this, offset, strip, strip.bottomCenter, strip.topCenter);
    }
  }
}
