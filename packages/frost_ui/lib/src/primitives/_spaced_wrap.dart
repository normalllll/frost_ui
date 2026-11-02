import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Library-only: a horizontal Wrap whose natural width counts its spacing, so a
/// shrink-wrapped parent gives it room for one run instead of folding the last
/// child onto a second.
class FrostSpacedWrap extends StatelessWidget {
  const FrostSpacedWrap({
    this.spacing = 0,
    this.runSpacing = 0,
    this.alignment = WrapAlignment.start,
    this.crossAxisAlignment = WrapCrossAlignment.start,
    this.children = const [],
    super.key,
  });
  final double spacing, runSpacing;
  final WrapAlignment alignment;
  final WrapCrossAlignment crossAxisAlignment;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => _SpacingInNaturalWidth(
    spacing: spacing * (children.length > 1 ? children.length - 1 : 0),
    child: Wrap(spacing: spacing, runSpacing: runSpacing, alignment: alignment, crossAxisAlignment: crossAxisAlignment, children: children),
  );
}

class _SpacingInNaturalWidth extends SingleChildRenderObjectWidget {
  const _SpacingInNaturalWidth({required this.spacing, required super.child});
  final double spacing;
  @override
  RenderObject createRenderObject(BuildContext context) => _RenderSpacingInNaturalWidth(spacing);
  @override
  void updateRenderObject(BuildContext context, _RenderSpacingInNaturalWidth renderObject) => renderObject.spacing = spacing;
}

class _RenderSpacingInNaturalWidth extends RenderProxyBox {
  _RenderSpacingInNaturalWidth(this._spacing);
  double _spacing;
  set spacing(double value) {
    if (value == _spacing) return;
    _spacing = value;
    markNeedsLayout();
  }

  @override
  double computeMaxIntrinsicWidth(double height) => super.computeMaxIntrinsicWidth(height) + _spacing;
}
