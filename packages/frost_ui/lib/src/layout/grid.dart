import 'dart:math' as math;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../foundation/spacing.dart';
import 'content_viewport.dart';
import 'waterfall_grid.dart';

int _columns(double width, double minimum, double gap) => frostFittedColumnCount(width: width, minTileWidth: minimum, gap: gap, textScale: 1);

double _textScale(BuildContext context) => MediaQuery.textScalerOf(context).scale(14) / 14;

/// Equal-width columns. Without an aspect ratio, each row adopts the height of
/// its tallest item. Requires bounded horizontal space, like a normal grid.
class FrostGrid extends StatelessWidget {
  const FrostGrid({required this.minItemWidth, required this.children, this.aspectRatio, super.key})
    : assert(minItemWidth > 0 && minItemWidth < double.infinity),
      assert(aspectRatio == null || aspectRatio > 0 && aspectRatio < double.infinity);
  final double minItemWidth;
  final List<Widget> children;
  final double? aspectRatio;
  @override
  Widget build(BuildContext context) => _GridLayout(
    minimum: minItemWidth * math.max(1.0, _textScale(context)),
    reserved: FrostContentColumnBudget.of(context),
    ratio: aspectRatio,
    gap: FrostGap.of(context).grid,
    direction: Directionality.of(context),
    children: children,
  );
}

/// A lazy grid needs a fixed aspect ratio so offscreen geometry is known.
class FrostSliverGrid extends StatelessWidget {
  const FrostSliverGrid({required this.minItemWidth, required this.itemCount, required this.itemBuilder, this.aspectRatio, super.key})
    : assert(minItemWidth > 0 && minItemWidth < double.infinity),
      assert(itemCount >= 0),
      assert(aspectRatio != null && aspectRatio > 0 && aspectRatio < double.infinity);
  final double minItemWidth;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final double? aspectRatio;
  @override
  Widget build(BuildContext context) => SliverLayoutBuilder(
    builder: (context, constraints) {
      final gap = FrostGap.of(context).grid;
      return SliverGrid(
        delegate: SliverChildBuilderDelegate(itemBuilder, childCount: itemCount),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: _columns(
            FrostContentColumnBudget.columnWidth(context, constraints.crossAxisExtent),
            minItemWidth * math.max(1.0, _textScale(context)),
            gap,
          ),
          crossAxisSpacing: gap,
          mainAxisSpacing: gap,
          childAspectRatio: aspectRatio!,
        ),
      );
    },
  );
}

class _GridData extends ContainerBoxParentData<RenderBox> {}

class _GridLayout extends MultiChildRenderObjectWidget {
  const _GridLayout({required this.minimum, required this.reserved, required this.ratio, required this.gap, required this.direction, required super.children});
  final double minimum, reserved, gap;
  final double? ratio;
  final TextDirection direction;
  @override
  RenderObject createRenderObject(BuildContext context) => _RenderGrid(this);
  @override
  void updateRenderObject(BuildContext context, _RenderGrid renderObject) {
    renderObject.config = this;
    renderObject.markNeedsLayout();
  }
}

class _RenderGrid extends RenderBox with ContainerRenderObjectMixin<RenderBox, _GridData>, RenderBoxContainerDefaultsMixin<RenderBox, _GridData> {
  _RenderGrid(this.config);
  _GridLayout config;
  int _columnsAt(double width) => _columns(math.max(0, width - config.reserved), config.minimum, config.gap);
  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _GridData) child.parentData = _GridData();
  }

  @override
  void performLayout() {
    assert(constraints.hasBoundedWidth, 'FrostGrid requires bounded horizontal space.');
    final columns = _columnsAt(constraints.maxWidth);
    final width = (constraints.maxWidth - config.gap * (columns - 1)) / columns;
    final items = getChildrenAsList();
    var top = 0.0;
    for (var first = 0; first < items.length; first += columns) {
      final row = items.skip(first).take(columns);
      var height = config.ratio == null ? 0.0 : width / config.ratio!;
      for (final item in row) {
        item.layout(BoxConstraints.tightFor(width: width, height: config.ratio == null ? null : height), parentUsesSize: true);
        height = math.max(height, item.size.height);
      }
      var column = 0;
      for (final item in row) {
        if (config.ratio == null) item.layout(BoxConstraints.tight(Size(width, height)), parentUsesSize: true);
        final x = column * (width + config.gap);
        (item.parentData! as _GridData).offset = Offset(config.direction == TextDirection.ltr ? x : constraints.maxWidth - x - width, top);
        column++;
      }
      top += height;
      if (first + columns < items.length) top += config.gap;
    }
    size = constraints.constrain(Size(constraints.maxWidth, top));
  }

  double _heightAt(double available) {
    final columns = _columnsAt(available);
    final width = (available - config.gap * (columns - 1)) / columns;
    final items = getChildrenAsList();
    var total = 0.0;
    for (var first = 0; first < items.length; first += columns) {
      var height = config.ratio == null ? 0.0 : width / config.ratio!;
      if (config.ratio == null) {
        for (final item in items.skip(first).take(columns)) {
          height = math.max(height, item.getMaxIntrinsicHeight(width));
        }
      }
      total += height + (first + columns < items.length ? config.gap : 0);
    }
    return total;
  }

  // Every item on one row at its natural width, or the narrowest a column may be.
  @override
  double computeMaxIntrinsicWidth(double height) =>
      getChildrenAsList().fold(0.0, (sum, item) => sum + math.max(config.minimum, item.getMaxIntrinsicWidth(double.infinity))) +
      config.gap * math.max(0, childCount - 1);
  @override
  double computeMinIntrinsicWidth(double height) => config.minimum;
  @override
  double computeMaxIntrinsicHeight(double width) => _heightAt(width);
  @override
  double computeMinIntrinsicHeight(double width) => _heightAt(width);
  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.constrain(Size(constraints.maxWidth, _heightAt(constraints.maxWidth)));

  @override
  void paint(PaintingContext context, Offset offset) => defaultPaint(context, offset);
  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) => defaultHitTestChildren(result, position: position);
}
