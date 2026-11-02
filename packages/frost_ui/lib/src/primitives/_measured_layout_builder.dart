import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// The one-line size of [text] in [style] as a Text below [context] lays it out.
Size frostTextLineSize(BuildContext context, String text, TextStyle style) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: DefaultTextStyle.of(context).style.merge(style)),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
    locale: Localizations.maybeLocaleOf(context),
    maxLines: 1,
  )..layout();
  final size = painter.size;
  painter.dispose();
  return size;
}

/// Library-only: a LayoutBuilder for content whose natural size its owner can
/// tell before building it. Unlike LayoutBuilder it answers intrinsic and
/// dry-layout queries, so IntrinsicHeight and IntrinsicWidth parents work:
/// [naturalSize] is the content at its preferred width, and [heightForWidth]
/// the height at another width when that differs.
class FrostMeasuredLayoutBuilder extends ConstrainedLayoutBuilder<BoxConstraints> {
  const FrostMeasuredLayoutBuilder({required this.naturalSize, this.heightForWidth, required super.builder, super.key});
  final Size naturalSize;
  final double Function(double width)? heightForWidth;

  @override
  RenderAbstractLayoutBuilderMixin<BoxConstraints, RenderBox> createRenderObject(BuildContext context) =>
      _RenderMeasuredLayoutBuilder(naturalSize, heightForWidth);

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) => (renderObject as _RenderMeasuredLayoutBuilder)
    ..heightForWidth = heightForWidth
    ..naturalSize = naturalSize;
}

class _RenderMeasuredLayoutBuilder extends RenderBox
    with RenderObjectWithChildMixin<RenderBox>, RenderObjectWithLayoutCallbackMixin, RenderAbstractLayoutBuilderMixin<BoxConstraints, RenderBox> {
  _RenderMeasuredLayoutBuilder(this._naturalSize, this.heightForWidth);
  double Function(double width)? heightForWidth;
  Size _naturalSize;
  set naturalSize(Size value) {
    if (value == _naturalSize) return;
    _naturalSize = value;
    markNeedsLayout();
  }

  double _height(double width) => heightForWidth?.call(width) ?? _naturalSize.height;

  // The builder's content adapts downwards; only its preferred width is known.
  @override
  double computeMinIntrinsicWidth(double height) => 0;
  @override
  double computeMaxIntrinsicWidth(double height) => _naturalSize.width;
  @override
  double computeMinIntrinsicHeight(double width) => _height(width);
  @override
  double computeMaxIntrinsicHeight(double width) => _height(width);
  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final width = math.min(_naturalSize.width, constraints.maxWidth);
    return constraints.constrain(Size(width, _height(width)));
  }

  @override
  void performLayout() {
    runLayoutCallback();
    if (child case final child?) {
      child.layout(constraints, parentUsesSize: true);
      size = constraints.constrain(child.size);
    } else {
      size = constraints.smallest;
    }
  }

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) => child?.getDistanceToActualBaseline(baseline);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) => child?.hitTest(result, position: position) ?? false;

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child case final child?) context.paintChild(child, offset);
  }
}
