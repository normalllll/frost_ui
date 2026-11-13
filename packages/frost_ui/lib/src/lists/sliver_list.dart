import 'package:flutter/widgets.dart';

import '../foundation/spacing.dart';
import '../layout/content_viewport.dart';
import '../layout/waterfall_grid.dart';
import '../primitives/_measured_keyline.dart';
import '../primitives/divider.dart';
import '_row_scope.dart';

/// A lazy sliver of [FrostListRow]s for a page that owns one scroll view,
/// where a [FrostList] would nest a second one. With [dividers], a hairline
/// between rows starts at each row's text column, as in [FrostList].
///
/// Rows keep their own actions, highlight bleed and focus; keyboard row
/// navigation and list-owned selection remain [FrostList]'s.
class FrostSliverList extends StatefulWidget {
  const FrostSliverList({required this.itemCount, required this.itemBuilder, this.itemKey, this.dividers = false, super.key})
    : minColumnWidth = null,
      maxColumns = null;

  /// Rows of variable height, several to a line while the sliver is wide
  /// enough. The column count is how many [minColumnWidth]s (scaled up with
  /// text) fit with the page's section gap between them, at most [maxColumns].
  /// Each line is as tall as its tallest row, with rows centred in it, and
  /// [dividers] draw one hairline under each line from its first row's text
  /// column. With [itemKey], row state follows an item within its line.
  const FrostSliverList.columns({
    required this.itemCount,
    required this.itemBuilder,
    required double this.minColumnWidth,
    this.maxColumns,
    this.itemKey,
    this.dividers = false,
    super.key,
  }) : assert(minColumnWidth > 0 && minColumnWidth < double.infinity),
       assert(maxColumns == null || maxColumns > 0);
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  /// A stable identity for the item at an index, such as its id. Row state
  /// (hover, focus, the divider's text column) then follows the item when the
  /// order changes; without it, state stays with the index.
  final Object Function(int index)? itemKey;
  final bool dividers;
  final double? minColumnWidth;
  final int? maxColumns;
  @override
  State<FrostSliverList> createState() => _FrostSliverListState();
}

class _FrostSliverListState extends State<FrostSliverList> {
  final _anchors = <Object, GlobalKey>{};
  // Index of each item key, built on the first lookup after a change.
  Map<Object, int>? _indexes;

  Object _keyOf(int index) => widget.itemKey?.call(index) ?? index;

  Map<Object, int> get _indexOfKey => _indexes ??= {for (var index = 0; index < widget.itemCount; index++) _keyOf(index): index};

  @override
  void didUpdateWidget(FrostSliverList oldWidget) {
    super.didUpdateWidget(oldWidget);
    _indexes = null;
    if (widget.itemKey == null) {
      _anchors.removeWhere((key, _) => key is! int || key >= widget.itemCount);
    } else {
      final live = _indexOfKey;
      _anchors.removeWhere((key, _) => !live.containsKey(key));
    }
  }

  GlobalKey _anchorOf(int index) => _anchors.putIfAbsent(_keyOf(index), GlobalKey.new);

  Widget _cell(BuildContext context, int index) => KeyedSubtree(
    key: widget.itemKey == null ? null : ValueKey(_keyOf(index)),
    child: FrostRowPlacement(textAnchor: _anchorOf(index), corners: null, child: widget.itemBuilder(context, index)),
  );

  Widget _divided({required Widget child, required int first, required bool last}) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      child,
      if (widget.dividers && !last)
        FrostMeasuredKeyline(
          target: _anchorOf(first),
          child: const FrostDivider(inset: FrostDividerInset.keyline),
        ),
    ],
  );

  Widget _item(BuildContext context, int index) => _divided(first: index, last: index == widget.itemCount - 1, child: _cell(context, index));

  int? _findIndex(Key key) => key is ValueKey<Object> ? _indexOfKey[key.value] : null;

  Widget _rows() => SliverList.builder(itemCount: widget.itemCount, itemBuilder: _item, findChildIndexCallback: widget.itemKey == null ? null : _findIndex);

  Widget _lines(BuildContext context, int columns) {
    final gap = FrostGap.of(context).section;
    final lines = (widget.itemCount / columns).ceil();
    Widget line(BuildContext context, int line) {
      final first = line * columns;
      return KeyedSubtree(
        key: widget.itemKey == null ? null : ValueKey(_keyOf(first)),
        child: _divided(
          first: first,
          last: line == lines - 1,
          child: Row(
            children: [
              for (var column = 0; column < columns; column++) ...[
                if (column > 0) SizedBox(width: gap),
                Expanded(child: first + column < widget.itemCount ? _cell(context, first + column) : const SizedBox.shrink()),
              ],
            ],
          ),
        ),
      );
    }

    // A line is found again by its first item, when that item still opens a line.
    int? findLine(Key key) => switch (_findIndex(key)) {
      final index? when index % columns == 0 => index ~/ columns,
      _ => null,
    };
    return SliverList.builder(itemCount: lines, itemBuilder: line, findChildIndexCallback: widget.itemKey == null ? null : findLine);
  }

  @override
  Widget build(BuildContext context) {
    final minimum = widget.minColumnWidth;
    if (minimum == null) return _rows();
    return FrostCrossAxisSliverBuilder(
      builder: (context, crossAxisExtent) {
        final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
        final fitted = frostFittedColumnCount(
          width: FrostContentColumnBudget.columnWidth(context, crossAxisExtent),
          minTileWidth: minimum,
          // Scaled up, counts follow the grids so every list of tiles agrees.
          gap: textScale > 1 ? FrostGap.of(context).grid : FrostGap.of(context).section,
          textScale: textScale,
        );
        final columns = widget.maxColumns == null ? fitted : fitted.clamp(1, widget.maxColumns!);
        return columns == 1 ? _rows() : _lines(context, columns);
      },
    );
  }
}
