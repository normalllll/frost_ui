import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'package:frost_ui/frost_ui.dart';
// ignore: implementation_imports -- same checkout; each such import is a layers row of the health gate.
import 'package:frost_ui/src/layout/content_viewport.dart' show FrostContentColumnBudget;
// ignore: implementation_imports -- same checkout; each such import is a layers row of the health gate.
import 'package:frost_ui/src/layout/waterfall_grid.dart' show frostBrowseGridPadding, frostFittedColumnCount;

import 'list_source.dart';
import 'loading_more_indicator.dart';

export 'loading_more_indicator.dart' show FrostLoadingMoreIndicator;

typedef FrostLoadingItemBuilder<T> = Widget Function(BuildContext context, T item, int index);

/// A source-owned paged list. Mix with arbitrary slivers in FrostLoadingScrollView.
/// The page creates/disposes [source]; this widget never copies its items.
class FrostSliverDataList<T> extends StatelessWidget {
  const FrostSliverDataList({
    required this.source,
    required this.itemBuilder,
    required this.firstLoadSkeleton,
    this.empty,
    this.padding,
    this.itemExtent,
    this.autoLoadMore = true,
    super.key,
  });
  final FrostListSource<T> source;
  final FrostLoadingItemBuilder<T> itemBuilder;

  /// Explicit first-load geometry; next pages use the shared three-dot footer.
  final Widget firstLoadSkeleton;

  /// App-owned empty-result content, normally FrostEmptyState. Null uses the
  /// generic localized noItems title; noMoreItems only describes a list's end.
  final Widget? empty;
  final EdgeInsetsGeometry? padding;
  final double? itemExtent;
  final bool autoLoadMore;
  @override
  Widget build(BuildContext context) => _PagedSliver<T>(
    source: source,
    firstLoadSkeleton: firstLoadSkeleton,
    empty: empty,
    autoLoadMore: autoLoadMore,
    contentBuilder: (context) {
      final delegate = SliverChildBuilderDelegate((context, index) => itemBuilder(context, source.items[index], index), childCount: source.items.length);
      final content = itemExtent == null ? SliverList(delegate: delegate) : SliverFixedExtentList(delegate: delegate, itemExtent: itemExtent!);
      return padding == null ? content : SliverPadding(padding: padding!, sliver: content);
    },
  );
}

/// The shared, state-preserving media waterfall with source-owned pagination.
class FrostSliverDataWaterfallGrid<T> extends StatelessWidget {
  const FrostSliverDataWaterfallGrid({
    required this.source,
    required this.itemBuilder,
    required this.firstLoadSkeleton,
    this.empty,
    this.preferredTileWidth = FrostMetrics.gridExtent,
    this.crossAxisSpacing = FrostGap.grid,
    this.mainAxisSpacing = FrostGap.grid,
    this.padding,
    this.columns,
    this.maxColumns,
    this.autoLoadMore = true,
    this.controller,
    super.key,
  });
  final FrostListSource<T> source;
  final FrostLoadingItemBuilder<T> itemBuilder;
  final Widget firstLoadSkeleton;

  /// Brings a loaded item into view by its index; see
  /// [FrostWaterfallController]. Unbound while the first page loads or the
  /// result is empty or an error.
  final FrostWaterfallController? controller;

  /// App-owned empty-result content, normally FrostEmptyState. Null uses the
  /// generic localized noItems title; noMoreItems only describes a list's end.
  final Widget? empty;
  final double preferredTileWidth, crossAxisSpacing, mainAxisSpacing;
  final EdgeInsetsGeometry? padding;
  final int? columns, maxColumns;
  final bool autoLoadMore;
  @override
  Widget build(BuildContext context) => _PagedSliver<T>(
    source: source,
    firstLoadSkeleton: firstLoadSkeleton,
    empty: empty,
    autoLoadMore: autoLoadMore,
    contentBuilder: (_) => FrostSliverWaterfallGrid<T>(
      items: source.items,
      itemBuilder: itemBuilder,
      preferredTileWidth: preferredTileWidth,
      crossAxisSpacing: crossAxisSpacing,
      mainAxisSpacing: mainAxisSpacing,
      padding: padding,
      columns: columns,
      maxColumns: maxColumns,
      controller: controller,
    ),
  );
}

/// Equal-height cards in fixed rows; the footer always spans the whole row.
class FrostSliverDataGrid<T> extends StatelessWidget {
  const FrostSliverDataGrid({
    required this.source,
    required this.itemBuilder,
    required this.firstLoadSkeleton,
    this.empty,
    required this.minTileWidth,
    required this.tileHeight,
    this.spacing = FrostGap.grid,
    super.key,
  });
  final FrostListSource<T> source;
  final FrostLoadingItemBuilder<T> itemBuilder;
  final Widget firstLoadSkeleton;

  /// App-owned empty-result content, normally FrostEmptyState. Null uses the
  /// generic localized noItems title; noMoreItems only describes a list's end.
  final Widget? empty;
  final double minTileWidth, spacing;
  final double Function(BuildContext context, double tileWidth) tileHeight;
  static ({EdgeInsets padding, int columns, double tileWidth}) geometry(
    BuildContext context,
    double crossAxisExtent, {
    required double minTileWidth,
    double spacing = FrostGap.grid,
  }) {
    final padding = frostBrowseGridPadding(crossAxisExtent);
    final width = crossAxisExtent - padding.horizontal;
    final count = frostFittedColumnCount(
      width: FrostContentColumnBudget.columnWidth(context, width),
      minTileWidth: minTileWidth,
      gap: spacing,
      textScale: MediaQuery.textScalerOf(context).scale(14) / 14,
    );
    return (padding: padding, columns: count, tileWidth: (width - spacing * (count - 1)) / count);
  }

  @override
  Widget build(BuildContext context) => _PagedSliver<T>(
    source: source,
    firstLoadSkeleton: firstLoadSkeleton,
    empty: empty,
    autoLoadMore: true,
    contentBuilder: (_) => SliverLayoutBuilder(
      builder: (context, constraints) {
        final layout = geometry(context, constraints.crossAxisExtent, minTileWidth: minTileWidth, spacing: spacing);
        return SliverPadding(
          padding: layout.padding,
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: layout.columns,
              crossAxisSpacing: spacing,
              mainAxisSpacing: spacing,
              mainAxisExtent: tileHeight(context, layout.tileWidth),
            ),
            delegate: SliverChildBuilderDelegate((context, index) => itemBuilder(context, source.items[index], index), childCount: source.items.length),
          ),
        );
      },
    ),
  );
}

class _PagedSliver<T> extends StatefulWidget {
  const _PagedSliver({required this.source, required this.contentBuilder, required this.firstLoadSkeleton, this.empty, required this.autoLoadMore});
  final FrostListSource<T> source;
  final WidgetBuilder contentBuilder;
  final Widget firstLoadSkeleton;

  /// App-owned empty-result content, normally FrostEmptyState. Null uses the
  /// generic localized noItems title; noMoreItems only describes a list's end.
  final Widget? empty;
  final bool autoLoadMore;
  @override
  State<_PagedSliver<T>> createState() => _PagedSliverState<T>();
}

class _PagedSliverState<T> extends State<_PagedSliver<T>> {
  FrostListSource<T>? _scheduled;

  void _load({required bool initial}) {
    final source = widget.source;
    if (identical(_scheduled, source)) return;
    _scheduled = source;
    // Geometry decides when the footer enters the scroll cache. Network and
    // provider writes run after layout, and an old source cannot start work
    // after this sliver is removed or retargeted.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (identical(_scheduled, source)) _scheduled = null;
      if (!mounted || !identical(widget.source, source) || source.busy || source.lastError != null) return;
      if (initial) {
        if (!source.initialized) source.refresh(true);
      } else if (widget.autoLoadMore && source.hasMore) {
        source.loadMore();
      }
    });
  }

  // Keep the source's public rebuild stream, including explicit setState(),
  // without importing a second viewport/renderer just for registration.
  @override
  Widget build(BuildContext context) => StreamBuilder<Iterable<T>>(stream: widget.source.rebuild, builder: (context, _) => _content(context));

  Widget _content(BuildContext context) {
    final source = widget.source;
    switch (source.phase) {
      case FrostLoadPhase.loading:
        if (!source.busy) _load(initial: true);
        return SliverToBoxAdapter(child: widget.firstLoadSkeleton);
      case FrostLoadPhase.error:
        return SliverFillRemaining(
          hasScrollBody: false,
          child: FrostPagedError(key: ObjectKey(source), source: source, placement: FrostPagedErrorPlacement.page),
        );
      case FrostLoadPhase.empty:
        return SliverFillRemaining(
          hasScrollBody: false,
          child: widget.empty ?? FrostEmptyState(icon: FrostIconSet.of(context).empty, title: FrostScope.labelsOf(context).noItems),
        );
      case FrostLoadPhase.content:
        return SliverMainAxisGroup(
          slivers: [
            widget.contentBuilder(context),
            SliverLayoutBuilder(
              builder: (context, constraints) {
                final near = constraints.remainingCacheExtent > 0;
                if (near && widget.autoLoadMore && source.hasMore && !source.busy && source.lastError == null) _load(initial: false);
                return SliverToBoxAdapter(
                  child: TickerMode(
                    enabled: near,
                    child: FrostLoadingMoreIndicator(source: source),
                  ),
                );
              },
            ),
          ],
        );
    }
  }
}
