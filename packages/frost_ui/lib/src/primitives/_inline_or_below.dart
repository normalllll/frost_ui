import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Library-only: two groups side by side while they fit, with [end] moving below
/// [start] when they do not. Both stay mounted through the switch, the decision
/// comes from the real render children (text scale included), and intrinsic and
/// dry-layout queries answer without a separate measuring pass.
class FrostInlineOrBelow extends MultiChildRenderObjectWidget {
  FrostInlineOrBelow({
    required Widget start,
    required Widget end,
    required this.direction,
    required this.gap,
    this.minimumStart,
    this.measuresEndAtWidth = true,
    this.fillsStart = false,
    this.shrinkWraps = false,
    this.belowAtStart = false,
    this.onLayout,
    super.key,
  }) : super(children: [start, end]);

  final TextDirection direction;
  final double gap;

  /// How narrow [start] may get on the shared row, given a way to ask its natural
  /// width and the row's. Its natural width by default, so it never has to wrap
  /// there. A rule that does not ask leaves [start] free of intrinsic queries, so
  /// it can hold content that cannot answer them.
  final double Function(double Function() natural, double width)? minimumStart;

  /// Whether the decision reads the end group's width as laid out in the row's
  /// width (a wrap can fold to fit) or its natural single-run width.
  final bool measuresEndAtWidth;

  /// Whether [start] takes all the width [end] leaves, not just what it needs.
  final bool fillsStart;

  /// Whether the box hugs its content instead of taking the row's width.
  final bool shrinkWraps;

  /// Whether [end] lies at the start edge when below, instead of the end edge.
  final bool belowAtStart;

  /// Reports the decision and the constraints it was made under, during layout.
  final void Function(bool below, BoxConstraints constraints)? onLayout;

  @override
  RenderObject createRenderObject(BuildContext context) => RenderFrostInlineOrBelow(this);
  @override
  void updateRenderObject(BuildContext context, RenderFrostInlineOrBelow renderObject) => renderObject.config = this;
}

class _Data extends ContainerBoxParentData<RenderBox> {}

class RenderFrostInlineOrBelow extends RenderBox with ContainerRenderObjectMixin<RenderBox, _Data>, RenderBoxContainerDefaultsMixin<RenderBox, _Data> {
  RenderFrostInlineOrBelow(this._config);
  FrostInlineOrBelow _config;
  set config(FrostInlineOrBelow value) {
    _config = value;
    markNeedsLayout();
  }

  /// The outcome of the last layout, for an owner that aligns around the first line.
  bool below = false;
  Size startSize = Size.zero, endSize = Size.zero;

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _Data) child.parentData = _Data();
  }

  double _startNatural() => firstChild!.getMaxIntrinsicWidth(double.infinity);
  double _minimumStart(double width) => _config.minimumStart?.call(_startNatural, width) ?? _startNatural();

  Size _layout(BoxConstraints limits, {required bool dry}) {
    final start = firstChild!, end = lastChild!;
    Size measure(RenderBox child, BoxConstraints bounds) {
      if (dry) return child.getDryLayout(bounds);
      child.layout(bounds, parentUsesSize: true);
      return child.size;
    }

    final width = limits.hasBoundedWidth ? limits.maxWidth : _minimumStart(double.infinity) + _config.gap + end.getMaxIntrinsicWidth(double.infinity);
    final endSize = measure(end, BoxConstraints(maxWidth: width, maxHeight: limits.maxHeight));
    final gap = endSize.width > 0 ? _config.gap : 0.0;
    final isBelow =
        endSize.width > 0 && (_config.measuresEndAtWidth ? endSize.width : end.getMaxIntrinsicWidth(double.infinity)) + gap + _minimumStart(width) > width;
    if (!dry) {
      below = isBelow;
      _config.onLayout?.call(isBelow, limits);
    }
    final startWidth = isBelow ? width : math.max(0.0, width - endSize.width - gap);
    final startHeight = isBelow ? double.infinity : limits.maxHeight;
    final startSize = measure(
      start,
      _config.fillsStart
          ? BoxConstraints(minWidth: startWidth, maxWidth: startWidth, maxHeight: startHeight)
          : BoxConstraints(maxWidth: startWidth, maxHeight: startHeight),
    );
    final height = isBelow ? startSize.height + gap + endSize.height : math.max(startSize.height, endSize.height);
    final hugged = isBelow ? math.max(startSize.width, endSize.width) : startSize.width + gap + endSize.width;
    final size = limits.constrain(Size(_config.shrinkWraps ? hugged : width, height));
    if (!dry) {
      this.startSize = startSize;
      this.endSize = endSize;
      void place(RenderBox child, double x, double y) =>
          (child.parentData! as _Data).offset = Offset(_config.direction == TextDirection.ltr ? x : size.width - x - child.size.width, y);
      place(start, 0, isBelow ? 0 : (height - startSize.height) / 2);
      place(end, isBelow && _config.belowAtStart ? 0 : size.width - endSize.width, isBelow ? startSize.height + gap : (height - endSize.height) / 2);
    }
    return size;
  }

  @override
  void performLayout() => size = _layout(constraints, dry: false);
  @override
  Size computeDryLayout(BoxConstraints constraints) => _layout(constraints, dry: true);
  @override
  double computeMinIntrinsicWidth(double height) =>
      math.max(firstChild!.getMinIntrinsicWidth(double.infinity), lastChild!.getMinIntrinsicWidth(double.infinity));
  @override
  double computeMaxIntrinsicWidth(double height) {
    final end = lastChild!.getMaxIntrinsicWidth(double.infinity);
    return firstChild!.getMaxIntrinsicWidth(double.infinity) + (end > 0 ? _config.gap + end : 0);
  }

  @override
  double computeMaxIntrinsicHeight(double width) => _layout(BoxConstraints(maxWidth: width), dry: true).height;
  @override
  double computeMinIntrinsicHeight(double width) => computeMaxIntrinsicHeight(width);
  @override
  void paint(PaintingContext context, Offset offset) => defaultPaint(context, offset);
  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) => defaultHitTestChildren(result, position: position);
}
