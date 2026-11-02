import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../foundation/_control_dimming.dart';
import '../foundation/_premultiplied_lerp.dart';
import '../foundation/density.dart';
import '../foundation/metrics.dart';
import '../foundation/sizes.dart';
import '../motion/_material_reveal.dart';
import '../motion/_spring_size.dart';
import '../motion/layout_crossfade.dart';
import '_field_chrome.dart';
import '_field_layout.dart';
import '_field_options.dart';
import 'field_appearance.dart';

/// Shared field paint and geometry for text, segmented time and readonly paths.
/// Editors own their input; this frame owns the single disabled opacity.
class FrostFieldFrame extends StatefulWidget {
  const FrostFieldFrame({
    required this.child,
    required this.size,
    required this.enabled,
    required this.focused,
    required this.invalid,
    this.onPaddingTap,
    this.multiline = false,
    this.trailingBleed = 0,
    super.key,
  });
  final Widget child;
  final FrostControlSize size;
  final bool enabled, focused, invalid, multiline;

  /// How much of the end inset [FrostFieldRow] takes over; see its parameter.
  final double trailingBleed;
  final VoidCallback? onPaddingTap;
  @override
  State<FrostFieldFrame> createState() => _FrostFieldFrameState();
}

class _FrostFieldFrameState extends State<FrostFieldFrame> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final FrostFieldFrame(:child, :size, :enabled, :focused, :invalid, :multiline) = widget;
    final geometry = frostControlGeometry(context, size);
    final composer = (FrostFieldScope.maybeOf(context) ?? FrostFieldOptions.of(context)?.appearance) == FrostFieldAppearance.composer;
    final chrome = FrostFieldChrome.resolve(context, enabled: enabled, focused: focused, invalid: invalid, hovered: _hovered);
    final contents = ConstrainedBox(
      constraints: BoxConstraints(minHeight: geometry.height),
      child: FrostAnimatedMaterialReveal(
        opacity: enabled ? 1 : .38,
        duration: FrostMotion.duration(context, FrostMotion.hover),
        child: FrostControlDimming(
          disabled: !enabled,
          child: Padding(
            padding: EdgeInsetsDirectional.only(start: frostFieldInset(size), end: frostFieldInset(size) - widget.trailingBleed),
            child: multiline ? child : SizedBox(height: geometry.height, child: child),
          ),
        ),
      ),
    );
    // Only the content is clipped to the silhouette. Clipping the hairline to
    // the same antialiased shape squares its edge coverage and steps corners.
    final visual = FrostFieldPaint(
      duration: FrostMotion.duration(context, FrostMotion.hover),
      curve: FrostMotion.hoverCurve,
      fill: chrome.fill,
      shape: chrome.shape,
      side: (chrome.edge.shape as OutlinedBorder).side,
      child: ClipPath(
        clipper: ShapeBorderClipper(shape: chrome.shape),
        child: composer ? FrostSpringSize(child: contents) : contents,
      ),
    );
    final sizedVisual = composer
        ? visual
        : FrostMotionSize(duration: FrostMotion.duration(context, FrostMotion.layoutFade), alignment: AlignmentDirectional.topStart, child: visual);
    // The paint stays at the requested size; only transparent layout space
    // reaches the platform target. The editor owns focus and padding actions.
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onTap: enabled ? widget.onPaddingTap : null,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: FrostDensity.of(context).targetHeight),
          child: Align(alignment: Alignment.center, heightFactor: 1, widthFactor: 1, child: sizedVisual),
        ),
      ),
    );
  }
}

/// Fill and hairline of a field, animated with premultiplied alpha. The rest
/// fill is a translucent wash and the focused fill opaque; a straight-channel
/// lerp between them passes through a brighter (dark) or darker (light) grey.
/// [fill], [shape] and [side] are the resolved targets of the field's state.
class FrostFieldPaint extends ImplicitlyAnimatedWidget {
  const FrostFieldPaint({required this.fill, required this.shape, required this.side, required this.child, required super.duration, super.curve, super.key});
  final Color fill;
  final OutlinedBorder shape;
  final BorderSide side;
  final Widget child;
  @override
  AnimatedWidgetBaseState<FrostFieldPaint> createState() => _FieldPaintState();
}

class _FieldPaintState extends AnimatedWidgetBaseState<FrostFieldPaint> {
  ColorTween? _fill, _edge;
  @override
  void forEachTween(TweenVisitor<dynamic> visitor) {
    _fill = visitor(_fill, widget.fill, (value) => FrostPremultipliedColorTween(begin: value as Color)) as ColorTween?;
    _edge = visitor(_edge, widget.side.color, (value) => FrostPremultipliedColorTween(begin: value as Color)) as ColorTween?;
  }

  @override
  Widget build(BuildContext context) => _PixelFieldPaint(
    fill: _fill!.evaluate(animation)!,
    shape: widget.shape,
    side: widget.side.copyWith(color: _edge!.evaluate(animation)),
    devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
    textDirection: Directionality.of(context),
    child: widget.child,
  );
}

class _PixelFieldPaint extends SingleChildRenderObjectWidget {
  const _PixelFieldPaint({
    required this.fill,
    required this.shape,
    required this.side,
    required this.devicePixelRatio,
    required this.textDirection,
    required super.child,
  });
  final Color fill;
  final OutlinedBorder shape;
  final BorderSide side;
  final double devicePixelRatio;
  final TextDirection textDirection;

  @override
  RenderObject createRenderObject(BuildContext context) => RenderFrostFieldPaint(fill, shape, side, devicePixelRatio, textDirection);

  @override
  void updateRenderObject(BuildContext context, RenderFrostFieldPaint renderObject) => renderObject
    ..fill = fill
    ..shape = shape
    ..side = side
    ..devicePixelRatio = devicePixelRatio
    ..textDirection = textDirection;
}

/// Paints the fill below and the hairline above the child, on the frame
/// rectangle snapped to device pixels against the window origin. A centred
/// field often lands on a fractional pixel at 125% (the caption field's 30 at
/// y 9 is 37.5 pixels at 11.25), where a one-pixel hairline would straddle two
/// pixel rows at half strength and break up around the corners.
class RenderFrostFieldPaint extends RenderProxyBox {
  RenderFrostFieldPaint(this._fill, this._shape, this._side, this._devicePixelRatio, this._textDirection);

  /// The fill, outline and shape painted this frame.
  Color get fill => _fill;
  Color _fill;
  set fill(Color value) {
    if (value == _fill) return;
    _fill = value;
    markNeedsPaint();
  }

  OutlinedBorder get shape => _shape;
  OutlinedBorder _shape;
  set shape(OutlinedBorder value) {
    if (value == _shape) return;
    _shape = value;
    markNeedsPaint();
  }

  BorderSide get side => _side;
  BorderSide _side;
  set side(BorderSide value) {
    if (value == _side) return;
    _side = value;
    markNeedsPaint();
  }

  double _devicePixelRatio;
  set devicePixelRatio(double value) {
    if (value == _devicePixelRatio) return;
    _devicePixelRatio = value;
    markNeedsPaint();
  }

  TextDirection _textDirection;
  set textDirection(TextDirection value) {
    if (value == _textDirection) return;
    _textDirection = value;
    markNeedsPaint();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final origin = localToGlobal(Offset.zero);
    double snap(double value, double from) => ((from + value) * _devicePixelRatio).roundToDouble() / _devicePixelRatio - from;
    final rect = Rect.fromLTRB(snap(0, origin.dx), snap(0, origin.dy), snap(size.width, origin.dx), snap(size.height, origin.dy)).shift(offset);
    if (_fill.a > 0) {
      final paint = Paint()..color = _fill;
      if (_shape.preferPaintInterior) {
        _shape.paintInterior(context.canvas, rect, paint, textDirection: _textDirection);
      } else {
        context.canvas.drawPath(_shape.getOuterPath(rect, textDirection: _textDirection), paint);
      }
    }
    super.paint(context, offset);
    if (_side.style != BorderStyle.none && _side.color.a > 0) {
      _shape.copyWith(side: _side).paint(context.canvas, rect, textDirection: _textDirection);
    }
  }
}
