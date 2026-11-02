import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../foundation/metrics.dart';
import '../primitives/_eager_layout_builder.dart';
import '../primitives/_page_outline.dart';
import '../primitives/keyline.dart';
import '_column_padding_rule.dart';
import '_content_padding.dart';
import '_page_scroll_behavior.dart';
import 'column_placement.dart';

/// Measures content in the space remaining after window navigation.
class FrostContentViewport extends StatelessWidget {
  const FrostContentViewport({required this.child, this.navigationReserve, super.key});
  final Widget child;
  final double? navigationReserve;

  @override
  Widget build(BuildContext context) {
    final reserve = navigationReserve ?? FrostContentColumnBudget.of(context);
    return LayoutBuilder(
      builder: (context, constraints) => FrostContentColumnBudget(
        reservedWidth: reserve,
        child: MediaQuery(
          data: MediaQuery.of(context).copyWith(size: Size(FrostPageOutline.contentWidth(context, constraints.maxWidth), constraints.maxHeight)),
          child: ScrollConfiguration(behavior: FrostPageScrollBehavior(ScrollConfiguration.of(context)), child: child),
        ),
      ),
    );
  }
}

/// Keeps responsive column counts stable while the user opens the sidebar.
/// The count still follows the window, text scale, and each grid's own inset.
class FrostContentColumnBudget extends InheritedWidget {
  const FrostContentColumnBudget({required this.reservedWidth, required super.child, super.key});

  final double reservedWidth;

  static double of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<FrostContentColumnBudget>()?.reservedWidth ?? 0;

  static double columnWidth(BuildContext context, double availableWidth) => math.max(0, availableWidth - of(context));

  @override
  bool updateShouldNotify(FrostContentColumnBudget oldWidget) => reservedWidth != oldWidget.reservedWidth;
}

/// A page's content column: at most [maxWidth] wide, centred in any free space, and inset by
/// [FrostMetrics.columnPadding] so every page shares the same edges.
class FrostContentColumn extends StatelessWidget {
  const FrostContentColumn({required this.child, this.maxWidth = FrostMetrics.contentMaxWidth, super.key});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return FrostEagerLayoutBuilder(
      builder: (context, constraints) {
        final rule = frostColumnPaddingRule(context, maxWidth: maxWidth);
        return _ContentKeyline(
          insets: rule(constraints.maxWidth),
          child: FrostBleedBoundary(
            child: _ColumnPadding(rule: rule, offered: constraints.maxWidth, child: child),
          ),
        );
      },
    );
  }
}

/// Insets its child by the column rule at whatever width it is given, in layout
/// and in intrinsic queries alike.
class _ColumnPadding extends SingleChildRenderObjectWidget {
  const _ColumnPadding({required this.rule, required this.offered, required super.child});
  final EdgeInsets Function(double width) rule;
  final double offered;
  @override
  RenderObject createRenderObject(BuildContext context) => _RenderColumnPadding(rule, offered);
  @override
  void updateRenderObject(BuildContext context, _RenderColumnPadding renderObject) => renderObject
    ..offered = offered
    ..rule = rule;
}

class _RenderColumnPadding extends RenderShiftedBox {
  _RenderColumnPadding(this._rule, this._widest) : super(null);

  // Only ever grows: an IntrinsicWidth parent's own answer comes back as the
  // width offered, and must not shrink the next answer.
  double _widest;
  set offered(double value) => _widest = value.isFinite && value > _widest ? value : _widest;
  EdgeInsets Function(double width) _rule;
  set rule(EdgeInsets Function(double width) value) {
    _rule = value;
    markNeedsLayout();
  }

  double _inner(double width) => math.max(0.0, width - _rule(width).horizontal);

  // Asked without a width, the column sits as it would in the widest room it
  // has been offered: with the free space that room leaves around it.
  double _natural(double content) => content + _rule(_widest).horizontal;

  @override
  double computeMinIntrinsicWidth(double height) => _natural(child!.getMinIntrinsicWidth(height));
  @override
  double computeMaxIntrinsicWidth(double height) => _natural(child!.getMaxIntrinsicWidth(height));
  @override
  double computeMinIntrinsicHeight(double width) => child!.getMinIntrinsicHeight(_inner(width));
  @override
  double computeMaxIntrinsicHeight(double width) => child!.getMaxIntrinsicHeight(_inner(width));

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final insets = _rule(constraints.maxWidth);
    return constraints.constrain(child!.getDryLayout(constraints.deflate(insets)) + Offset(insets.horizontal, 0));
  }

  @override
  void performLayout() {
    final child = this.child!;
    final insets = _rule(constraints.maxWidth);
    child.layout(constraints.deflate(insets), parentUsesSize: true);
    size = constraints.constrain(Size(child.size.width + insets.horizontal, child.size.height));
    (child.parentData! as BoxParentData).offset = Offset(insets.left, 0);
  }
}

/// [FrostContentColumn] for a sliver inside a scroll view; the scroll view itself
/// stays full width so its scrollbar remains at the window edge.
class FrostSliverContentColumn extends StatelessWidget {
  const FrostSliverContentColumn({required this.sliver, this.maxWidth = FrostMetrics.contentMaxWidth, super.key});

  final Widget sliver;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final insets = FrostColumnPlacement.columnPadding(context, constraints.crossAxisExtent, maxWidth: maxWidth);
        return _ContentKeyline(
          insets: insets,
          child: FrostSliverBleedBoundary(
            child: SliverPadding(padding: insets, sliver: sliver),
          ),
        );
      },
    );
  }
}

/// Box and sliver columns expose the same alignment and bleed budget.
class _ContentKeyline extends StatelessWidget {
  const _ContentKeyline({required this.insets, required this.child});
  final EdgeInsets insets;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return FrostKeyline(
      leadingRoom: rtl ? insets.right : insets.left,
      trailingRoom: rtl ? insets.left : insets.right,
      edgeDistanceStart: rtl ? insets.right : insets.left,
      edgeDistanceEnd: rtl ? insets.left : insets.right,
      contentStart: rtl ? insets.right : insets.left,
      insideContainer: false,
      child: FrostPageOutline.content(context, FrostContentPadding(padding: null, child: child)),
    );
  }
}
