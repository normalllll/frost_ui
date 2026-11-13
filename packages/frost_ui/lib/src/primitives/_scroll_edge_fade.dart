import 'dart:math' as math;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../foundation/tokens.dart';

// Shared by shelves and thumbnail strips; fades reveal at most 24 logical pixels.
const _scrollFadeExtent = 24.0;

/// Reads final scroll geometry when painting, including the first layout.
/// While not [active], the child paints as it is, and keeps its state when
/// the fade comes back.
class FrostScrollEdgeFade extends StatelessWidget {
  const FrostScrollEdgeFade({required this.controller, required this.child, this.repaint, this.active = true, super.key});
  final ScrollController controller;
  final Listenable? repaint;
  final bool active;
  final Widget child;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([controller, ?repaint]),
    builder: (context, child) => FrostEdgeFadeMask(
      fades: active,
      shader: (rect) {
        final position = controller.hasClients && controller.position.hasContentDimensions ? controller.position : null;
        final limit = math.min(_scrollFadeExtent, rect.width / 2);
        final before = (position?.extentBefore ?? 0).clamp(0.0, limit);
        final after = (position?.extentAfter ?? 0).clamp(0.0, limit);
        final rtl = Directionality.of(context) == TextDirection.rtl;
        final left = rtl ? after : before, right = rtl ? before : after;
        final opaque = FrostThemeTokens.of(context).canvas.withValues(alpha: 1), clear = opaque.withValues(alpha: 0);
        return LinearGradient(
          colors: [left == 0 ? opaque : clear, opaque, opaque, right == 0 ? opaque : clear],
          stops: [0, rect.width == 0 ? 0 : left / rect.width, rect.width == 0 ? 1 : 1 - right / rect.width, 1],
        ).createShader(rect);
      },
      child: child,
    ),
    child: child,
  );
}

/// A mask that is in the tree whether or not it fades, so the content under it
/// keeps its state and focus as the fades come and go. It takes a layer only to
/// fade.
class FrostEdgeFadeMask extends SingleChildRenderObjectWidget {
  const FrostEdgeFadeMask({required this.fades, required this.shader, required super.child, super.key});
  final bool fades;
  final ShaderCallback shader;

  @override
  RenderObject createRenderObject(BuildContext context) => FrostRenderEdgeFadeMask(shader, fades);

  @override
  void updateRenderObject(BuildContext context, FrostRenderEdgeFadeMask renderObject) => renderObject
    ..shaderCallback = shader
    ..fades = fades;
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

  @override
  bool get alwaysNeedsCompositing => _fades && super.alwaysNeedsCompositing;

  @override
  void paint(PaintingContext context, Offset offset) {
    if (_fades) return super.paint(context, offset);
    layer = null;
    if (child case final child?) context.paintChild(child, offset);
  }
}
