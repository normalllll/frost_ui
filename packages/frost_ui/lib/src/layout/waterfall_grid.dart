import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:waterfall_flow/waterfall_flow.dart';

import '../foundation/metrics.dart';
import '../foundation/spacing.dart';
import 'content_viewport.dart';

typedef FrostWaterfallGridItemBuilder<T> = Widget Function(BuildContext context, T item, int index);

/// Brings one item of a media waterfall into view by its index, including an
/// item whose tile has not been built yet, such as the item a detail page
/// paged to before returning to the waterfall.
///
/// Pass it to one [FrostSliverWaterfallGrid], `FrostSliverDataWaterfallGrid`
/// or [FrostWaterfallGrid] at a time. Unbound calls are harmless, and the
/// controller owns no disposable resources.
class FrostWaterfallController {
  ValueChanged<int>? _reveal;

  /// Jumps, without animation, so the item at [index] is fully visible.
  ///
  /// An item that is already fully visible stays where it is. Otherwise its
  /// nearer edge is aligned with the nearer edge of the visible area: the
  /// viewport less the top and bottom [MediaQuery] padding the grid receives
  /// (the pinned chrome of [FrostPinnedChrome] and the page layouts, header
  /// and section rows included) and any pinned sliver overlapping the grid.
  /// An item taller than that area is aligned at its top.
  ///
  /// The move happens in the grid's next layout, before that frame paints, so
  /// a Hero flight starting after the frame finds the tile in place. Tiles
  /// between the current position and the item are laid out on the way, in
  /// the same columns scrolling would place them. Like a scroll offset
  /// correction, the move reports new scroll metrics but no scroll start,
  /// update or end notification. Indexes outside the loaded items are
  /// ignored, as are calls while no grid is bound.
  void reveal(int index) => _reveal?.call(index);

  void _attach(ValueChanged<int> reveal) {
    assert(_reveal == null || _reveal == reveal, 'A FrostWaterfallController can bind only one waterfall.');
    _reveal = reveal;
  }

  void _detach(ValueChanged<int> reveal) {
    if (_reveal == reveal) _reveal = null;
  }
}

/// Media columns: the count whose tiles come closest to
/// [preferredTileWidth], so a grid about 2.8 tiles wide shows three slightly
/// narrower tiles rather than two much wider ones. Tiles therefore range a
/// little either side of the preferred width instead of never going below
/// it. Grids narrower than 320 use one column, other grids at least two, and
/// very large text gives up a column.
int frostWaterfallColumnCount({
  required double width,
  required double preferredTileWidth,
  required double gap,
  required double textScale,
  int? columns,
  int? maxColumns,
}) {
  assert(columns == null || columns > 0);
  assert(maxColumns == null || maxColumns > 0);
  int cap(int count) => math.min(count, maxColumns ?? count);
  double tileWidth(int columns) => (width + gap) / columns - gap;
  // Large text widens the tile a column has to hold, as in every other grid.
  if (columns != null) {
    final count = cap(width < 320 ? 1 : columns);
    return textScale <= 1 ? count : math.max(1, (count / textScale).round());
  }
  // Sidebar interpolation may differ by a subpixel at an exact threshold.
  final fewer = math.max(1, ((width + gap) / (preferredTileWidth + gap) + 1e-9).floor());
  final nearest = tileWidth(fewer) - preferredTileWidth <= preferredTileWidth - tileWidth(fewer + 1) + 1e-9 ? fewer : fewer + 1;
  final count = cap(width < 320 ? 1 : math.max(2, nearest));
  if (textScale <= 1) return count;
  // Media keeps two columns on a phone until the text is plainly large.
  final floor = width >= 320 && textScale < _mediaFloorTextScale ? 2 : 1;
  return cap(math.max(floor, math.min(count, frostFittedColumnCount(width: width, minTileWidth: preferredTileWidth, gap: gap, textScale: textScale))));
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
    this.columns,
    this.maxColumns,
    this.minTileWidth,
    this.crossAxisSpacing = FrostGap.grid,
    this.mainAxisSpacing = FrostGap.grid,
    this.padding,
    this.physics,
    this.shrinkWrap = false,
    this.sliverHeader,
    this.controller,
    super.key,
  }) : assert(minTileWidth == null || minTileWidth > 0 && minTileWidth < double.infinity),
       assert(columns == null || minTileWidth == null, 'A waterfall takes either a fixed column count or a minimum tile width.');

  final List<T> items;
  final FrostWaterfallGridItemBuilder<T> itemBuilder;
  final double preferredTileWidth;

  /// Optional page-owned column preference and upper limit; layout, density
  /// and large-text adaptation remain shared with the paged waterfall.
  final int? columns, maxColumns;

  /// Columns for cards rather than media: as many as keep a tile at least this
  /// wide (scaled with the text), down to one column on a phone. [maxColumns]
  /// still caps the count; [preferredTileWidth] is not used. Not combined
  /// with [columns].
  final double? minTileWidth;
  final double crossAxisSpacing;
  final double mainAxisSpacing;

  /// Defaults to [frostBrowseGridPadding] for the grid's own width.
  final EdgeInsetsGeometry? padding;
  final ScrollPhysics? physics;
  final bool shrinkWrap;
  final Widget? sliverHeader;

  /// Brings an item into view by its index; see [FrostWaterfallController].
  final FrostWaterfallController? controller;

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
          columns: columns,
          maxColumns: maxColumns,
          minTileWidth: minTileWidth,
          crossAxisSpacing: crossAxisSpacing,
          mainAxisSpacing: mainAxisSpacing,
          padding: padding,
          controller: controller,
        ),
        // The last tiles end above a bar that lies over the page's bottom edge.
        SliverToBoxAdapter(child: SizedBox(height: MediaQuery.paddingOf(context).bottom)),
      ],
    );
  }
}

class FrostSliverWaterfallGrid<T> extends StatefulWidget {
  const FrostSliverWaterfallGrid({
    required this.items,
    required this.itemBuilder,
    this.preferredTileWidth = FrostMetrics.gridExtent,
    this.columns,
    this.maxColumns,
    this.minTileWidth,
    this.crossAxisSpacing = FrostGap.grid,
    this.mainAxisSpacing = FrostGap.grid,
    this.padding,
    this.controller,
    super.key,
  }) : assert(minTileWidth == null || minTileWidth > 0 && minTileWidth < double.infinity),
       assert(columns == null || minTileWidth == null, 'A waterfall takes either a fixed column count or a minimum tile width.');

  final List<T> items;
  final FrostWaterfallGridItemBuilder<T> itemBuilder;
  final double preferredTileWidth;

  /// Optional page-owned column preference and upper limit; layout, density
  /// and large-text adaptation remain shared with the paged waterfall.
  final int? columns, maxColumns;

  /// Columns for cards rather than media: as many as keep a tile at least this
  /// wide (scaled with the text), down to one column on a phone. [maxColumns]
  /// still caps the count; [preferredTileWidth] is not used. Not combined
  /// with [columns].
  final double? minTileWidth;
  final double crossAxisSpacing;
  final double mainAxisSpacing;

  /// Defaults to [frostBrowseGridPadding] for the grid's own width.
  final EdgeInsetsGeometry? padding;

  /// Brings an item into view by its index; see [FrostWaterfallController].
  final FrostWaterfallController? controller;

  @override
  State<FrostSliverWaterfallGrid<T>> createState() => _FrostSliverWaterfallGridState<T>();
}

class _FrostSliverWaterfallGridState<T> extends State<FrostSliverWaterfallGrid<T>> {
  final _keys = <int, GlobalKey>{};
  final _reveals = GlobalKey();
  bool _pruneQueued = false;
  void _pruneAfterLayout() {
    if (_pruneQueued) return;
    _pruneQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pruneQueued = false;
      if (mounted) _keys.removeWhere((index, key) => key.currentContext == null);
    });
  }

  @override
  void initState() {
    super.initState();
    widget.controller?._attach(_reveal);
  }

  @override
  void didUpdateWidget(FrostSliverWaterfallGrid<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._detach(_reveal);
      widget.controller?._attach(_reveal);
    }
  }

  @override
  void dispose() {
    widget.controller?._detach(_reveal);
    super.dispose();
  }

  void _reveal(int index) {
    if (index < 0 || index >= widget.items.length) return;
    (_reveals.currentContext?.findRenderObject() as _RenderWaterfallReveal?)?.reveal(index);
  }

  @override
  Widget build(BuildContext context) {
    _pruneAfterLayout();
    final items = widget.items, itemBuilder = widget.itemBuilder;
    final preferredTileWidth = widget.preferredTileWidth, crossAxisSpacing = widget.crossAxisSpacing, mainAxisSpacing = widget.mainAxisSpacing;
    // Paged and plain waterfalls share this renderer: padding is subtracted
    // once from the full width, so skeletons and results share column counts.
    return FrostCrossAxisSliverBuilder(
      builder: (context, crossAxisExtent) {
        final padding = widget.padding ?? frostBrowseGridPadding(crossAxisExtent);
        final inset = padding.resolve(Directionality.of(context)).horizontal;
        final width = FrostContentColumnBudget.columnWidth(context, crossAxisExtent - inset);
        final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
        final cardWidth = widget.minTileWidth, maxColumns = widget.maxColumns;
        final fitted = cardWidth == null ? null : frostFittedColumnCount(width: width, minTileWidth: cardWidth, gap: crossAxisSpacing, textScale: textScale);
        final readableCount = fitted != null
            ? math.min(fitted, maxColumns ?? fitted)
            : frostWaterfallColumnCount(
                width: width,
                preferredTileWidth: preferredTileWidth,
                gap: crossAxisSpacing,
                textScale: textScale,
                columns: widget.columns,
                maxColumns: maxColumns,
              );
        // Chrome pinned over the scroll view reserves its height as padding.
        final chrome = MediaQuery.paddingOf(context);
        return SliverPadding(
          padding: padding,
          sliver: _WaterfallReveal(
            key: _reveals,
            itemCount: items.length,
            topInset: chrome.top,
            bottomInset: chrome.bottom,
            sliver: SliverWaterfallFlow(
              gridDelegate: SliverWaterfallFlowDelegateWithFixedCrossAxisCount(
                crossAxisCount: readableCount,
                crossAxisSpacing: crossAxisSpacing,
                mainAxisSpacing: mainAxisSpacing,
              ),
              delegate: SliverChildBuilderDelegate((context, index) {
                _pruneAfterLayout();
                // waterfall_flow discards its render children whenever width
                // changes. Reattach still-visible item Elements in that same
                // frame so resize/sidebar animation retains State and decodes.
                // Pruning after finalization keeps this map bounded to live items.
                return KeyedSubtree(key: _keys.putIfAbsent(index, GlobalKey.new), child: itemBuilder(context, items[index], index));
              }, childCount: items.length),
            ),
          ),
        );
      },
    );
  }
}

/// Carries a reveal request into the waterfall's layout, where tiles before
/// the item can be placed and the scroll offset corrected before paint.
class _WaterfallReveal extends SingleChildRenderObjectWidget {
  const _WaterfallReveal({required this.itemCount, required this.topInset, required this.bottomInset, required Widget sliver, super.key})
    : super(child: sliver);
  final int itemCount;
  final double topInset, bottomInset;

  @override
  _RenderWaterfallReveal createRenderObject(BuildContext context) => _RenderWaterfallReveal()
    ..itemCount = itemCount
    ..topInset = topInset
    ..bottomInset = bottomInset;

  @override
  void updateRenderObject(BuildContext context, _RenderWaterfallReveal renderObject) => renderObject
    ..itemCount = itemCount
    ..topInset = topInset
    ..bottomInset = bottomInset;
}

class _RenderWaterfallReveal extends RenderProxySliver {
  int itemCount = 0;
  double topInset = 0, bottomInset = 0;
  int? _target;

  void reveal(int index) {
    _target = index;
    markNeedsLayout();
  }

  @override
  void performLayout() {
    final flow = child! as RenderSliverWaterfallFlow;
    final target = _target;
    _target = null;
    flow.layout(constraints, parentUsesSize: true);
    final viewport = RenderAbstractViewport.maybeOf(this);
    final correction = target == null || target >= itemCount || viewport is! RenderViewportBase || constraints.axis != Axis.vertical
        ? null
        : _correctionFor(flow, target, viewport.offset);
    if (correction == null || correction == 0) {
      geometry = flow.geometry;
      return;
    }
    // The viewport moves by the correction and lays out again in this frame;
    // the tiles around the item are already placed.
    geometry = SliverGeometry(scrollOffsetCorrection: correction);
  }

  /// How far the scroll offset moves to show [index] fully, or null when the
  /// tile could not be placed.
  double? _correctionFor(RenderSliverWaterfallFlow flow, int index, ViewportOffset offset) {
    final built = _extentOf(flow, index);
    final extent = built ?? _layOutTo(flow, index);
    double? settle(double? delta) {
      // Without a move, leave the waterfall as this frame's constraints lay
      // it out rather than at a probing window.
      if (built == null && (delta == null || delta == 0)) flow.layout(constraints, parentUsesSize: true);
      return delta;
    }

    if (extent == null) return settle(null);
    // The visible area in the waterfall's own scroll offsets.
    final top = offset.pixels - constraints.precedingScrollExtent + topInset + math.max(0.0, constraints.overlap);
    final bottom = offset.pixels - constraints.precedingScrollExtent + constraints.viewportMainAxisExtent - bottomInset;
    if (extent.start >= top - 1e-6 && extent.end <= bottom + 1e-6) return settle(0);
    var delta = extent.start < top || extent.end - extent.start > bottom - top ? extent.start - top : extent.end - bottom;
    if (offset case final ScrollPosition position when position.hasContentDimensions) {
      delta = math.max(delta, position.minScrollExtent - position.pixels);
      // The extent past the loaded tiles is an estimate; an offset beyond the
      // real end is pulled back without the spring once layout knows it.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (position.hasPixels && position.hasContentDimensions && position.pixels > position.maxScrollExtent) {
          position.jumpTo(position.maxScrollExtent);
        }
      });
    }
    return settle(delta);
  }

  /// The placed tiles, as scroll offsets within the waterfall. The waterfall
  /// records each tile's end, since only it may read the tile's size here.
  Iterable<({int index, int column, double start, double end})> _tiles(RenderSliverWaterfallFlow flow) sync* {
    for (var tile = flow.firstChild; tile != null; tile = flow.childAfter(tile)) {
      final data = tile.parentData! as SliverWaterfallFlowParentData;
      if (data.layoutOffset case final start?) yield (index: data.index!, column: data.crossAxisIndex ?? 0, start: start, end: data.trailingLayoutOffset);
    }
  }

  ({double start, double end})? _extentOf(RenderSliverWaterfallFlow flow, int index) {
    for (final tile in _tiles(flow)) {
      if (tile.index == index) return (start: tile.start, end: tile.end);
    }
    return null;
  }

  /// Lays the waterfall out a viewport at a time towards [index] until its
  /// tile is placed. Placement depends on every earlier tile's height, so the
  /// waterfall walks there exactly as scrolling would.
  ({double start, double end})? _layOutTo(RenderSliverWaterfallFlow flow, int index) {
    final step = math.max(constraints.viewportMainAxisExtent, 1.0);
    SliverConstraints window(double from, double extent) =>
        constraints.copyWith(scrollOffset: from, cacheOrigin: 0, overlap: 0, remainingPaintExtent: extent, remainingCacheExtent: extent);
    while (true) {
      final first = flow.firstChild, last = flow.lastChild;
      if (first == null || last == null) return null;
      final firstIndex = flow.indexOf(first), lastIndex = flow.indexOf(last);
      final columns = _columns(flow);
      if (index > lastIndex) {
        // A new tile goes below the shortest column, so a window from that
        // column's end keeps every tile placed after it.
        flow.layout(window(columns.ends.reduce(math.min), step), parentUsesSize: true);
        if (flow.lastChild == null || flow.indexOf(flow.lastChild!) <= lastIndex) return null;
      } else if (index < firstIndex) {
        // Every earlier tile ends above its column's first laid-out tile, so
        // a window down to the lowest of those keeps all of them in reach.
        final from = math.max(0.0, columns.starts.reduce(math.min) - step);
        flow.layout(window(from, columns.starts.reduce(math.max) - from + step), parentUsesSize: true);
        if (flow.firstChild == null || flow.indexOf(flow.firstChild!) >= firstIndex) return null;
      } else {
        return _extentOf(flow, index);
      }
      if (flow.geometry?.scrollOffsetCorrection != null) return null;
      if (_extentOf(flow, index) case final extent?) return extent;
    }
  }

  /// The start of each column's first laid-out tile and the end of its last.
  ({List<double> starts, List<double> ends}) _columns(RenderSliverWaterfallFlow flow) {
    final starts = <int, double>{}, ends = <int, double>{};
    for (final tile in _tiles(flow)) {
      starts[tile.column] = math.min(starts[tile.column] ?? double.infinity, tile.start);
      ends[tile.column] = math.max(ends[tile.column] ?? 0, tile.end);
    }
    return (starts: starts.isEmpty ? [0] : starts.values.toList(), ends: ends.isEmpty ? [0] : ends.values.toList());
  }
}

/// Grid padding that lines the outer columns up with the page's section
/// titles on both sides.
EdgeInsets frostBrowseGridPadding(double width) {
  final inset = FrostMetrics.browseInset(width);
  return EdgeInsets.fromLTRB(inset, FrostGap.inline, inset, inset);
}

// Below this text scale a phone still shows two media columns.
const _mediaFloorTextScale = 1.5;

/// Library-only: a sliver laid out from its cross-axis extent alone.
///
/// A SliverLayoutBuilder runs its builder again whenever its constraints
/// change, and the scroll offset changes them in every scroll frame. A
/// multi-child sliver built anew there builds every live child again. This
/// builder runs only when the cross-axis extent changes, when this widget is
/// rebuilt, or when an inherited widget the builder read changes, and returns
/// the same sliver otherwise, so scrolling builds only the children that come
/// into view.
///
/// The builder's context is this widget's, so inherited widgets it reads are
/// dependencies of this widget.
class FrostCrossAxisSliverBuilder extends StatefulWidget {
  const FrostCrossAxisSliverBuilder({required this.builder, super.key});
  final Widget Function(BuildContext context, double crossAxisExtent) builder;

  @override
  State<FrostCrossAxisSliverBuilder> createState() => _FrostCrossAxisSliverBuilderState();
}

class _FrostCrossAxisSliverBuilderState extends State<FrostCrossAxisSliverBuilder> {
  Widget? _sliver;
  double? _extent;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sliver = null;
  }

  @override
  void didUpdateWidget(FrostCrossAxisSliverBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sliver = null;
  }

  @override
  Widget build(BuildContext context) => SliverLayoutBuilder(
    builder: (_, constraints) {
      final extent = constraints.crossAxisExtent;
      if (_sliver == null || extent != _extent) {
        _extent = extent;
        _sliver = widget.builder(context, extent);
      }
      return _sliver!;
    },
  );
}
