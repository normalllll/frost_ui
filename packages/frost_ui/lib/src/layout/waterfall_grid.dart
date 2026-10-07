import 'dart:math' as math;

import 'package:frost_ui/src/foundation/metrics.dart';
import 'package:frost_ui/src/layout/content_viewport.dart';
import 'package:flutter/material.dart';
import 'package:waterfall_flow/waterfall_flow.dart';

typedef FrostWaterfallGridItemBuilder<T> = Widget Function(BuildContext context, T item, int index);

typedef FrostLoadingWaterfallGridItemBuilder<T> = Widget Function(BuildContext context, T item, int index);

/// Media columns: the count whose tiles come closest to
/// [preferredTileWidth], so a grid about 2.8 tiles wide shows three slightly
/// narrower tiles rather than two much wider ones. Tiles therefore range a
/// little either side of the preferred width instead of never going below
/// it. Grids narrower than 320 use one column, other grids at least two, and
/// very large text gives up a column.
int frostWaterfallColumnCount({required double width, required double preferredTileWidth, required double gap, required double textScale}) {
  double tileWidth(int columns) => (width + gap) / columns - gap;
  // Sidebar interpolation may differ by a subpixel at an exact threshold.
  final fewer = math.max(1, ((width + gap) / (preferredTileWidth + gap) + 1e-9).floor());
  final nearest = tileWidth(fewer) - preferredTileWidth <= preferredTileWidth - tileWidth(fewer + 1) + 1e-9 ? fewer : fewer + 1;
  final count = width < 320 ? 1 : math.max(2, nearest);
  return textScale >= 1.8 ? math.max(1, count - 1) : count;
}

/// Columns for cards that need a minimum width to stay readable, such as
/// user cards: as many as fit at [minTileWidth] (scaled with the text), and a
/// single column when only one fits. Unlike media tiles, cards are never
/// forced into two columns on phones or narrow windows.
int frostFittedColumnCount({required double width, required double minTileWidth, required double gap, required double textScale}) {
  final tile = minTileWidth * math.max(1.0, textScale);
  return math.max(1, ((width + gap) / (tile + gap) + 1e-9).floor());
}

class FrostWaterfallGrid<T> extends StatelessWidget {
  const FrostWaterfallGrid({
    required this.items,
    required this.itemBuilder,
    this.preferredTileWidth = FrostMetrics.gridExtent,
    this.crossAxisSpacing = FrostMetrics.gridGap,
    this.mainAxisSpacing = FrostMetrics.gridGap,
    this.padding,
    this.physics,
    this.shrinkWrap = false,
    this.sliverHeader,
    super.key,
  });

  final List<T> items;
  final FrostWaterfallGridItemBuilder<T> itemBuilder;
  final double preferredTileWidth;
  final double crossAxisSpacing;
  final double mainAxisSpacing;

  /// Defaults to [frostBrowseGridPadding] for the grid's own width.
  final EdgeInsetsGeometry? padding;
  final ScrollPhysics? physics;
  final bool shrinkWrap;
  final Widget? sliverHeader;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: physics,
      shrinkWrap: shrinkWrap,
      slivers: [
        ?sliverHeader,
        FrostSliverWaterfallGrid<T>(
          items: items,
          itemBuilder: itemBuilder,
          preferredTileWidth: preferredTileWidth,
          crossAxisSpacing: crossAxisSpacing,
          mainAxisSpacing: mainAxisSpacing,
          padding: padding,
        ),
      ],
    );
  }
}

class FrostSliverWaterfallGrid<T> extends StatelessWidget {
  const FrostSliverWaterfallGrid({
    required this.items,
    required this.itemBuilder,
    this.preferredTileWidth = FrostMetrics.gridExtent,
    this.crossAxisSpacing = FrostMetrics.gridGap,
    this.mainAxisSpacing = FrostMetrics.gridGap,
    this.padding,
    super.key,
  });

  final List<T> items;
  final FrostWaterfallGridItemBuilder<T> itemBuilder;
  final double preferredTileWidth;
  final double crossAxisSpacing;
  final double mainAxisSpacing;

  /// Defaults to [frostBrowseGridPadding] for the grid's own width.
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    // Same measurement as FrostSliverDataWaterfallGrid: the padding is subtracted
    // once from the full width, so skeletons and results share column counts.
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final padding = this.padding ?? frostBrowseGridPadding(constraints.crossAxisExtent);
        final inset = padding.resolve(Directionality.of(context)).horizontal;
        final width = FrostContentColumnBudget.columnWidth(context, constraints.crossAxisExtent - inset);
        final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
        final readableCount = frostWaterfallColumnCount(width: width, preferredTileWidth: preferredTileWidth, gap: crossAxisSpacing, textScale: textScale);
        return SliverPadding(
          padding: padding,
          sliver: SliverWaterfallFlow(
            gridDelegate: SliverWaterfallFlowDelegateWithFixedCrossAxisCount(
              crossAxisCount: readableCount,
              crossAxisSpacing: crossAxisSpacing,
              mainAxisSpacing: mainAxisSpacing,
            ),
            delegate: SliverChildBuilderDelegate((context, index) {
              return itemBuilder(context, items[index], index);
            }, childCount: items.length),
          ),
        );
      },
    );
  }
}

/// Grid padding that lines the outer columns up with the page's section
/// titles on both sides.
EdgeInsets frostBrowseGridPadding(double width) {
  final inset = FrostMetrics.browseInset(width);
  return EdgeInsets.fromLTRB(inset, 4, inset, inset);
}
