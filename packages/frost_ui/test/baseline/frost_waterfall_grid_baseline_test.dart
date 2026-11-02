import 'package:flutter/widgets.dart';
import 'package:frost_ui/frost_ui.dart';

import 'baseline.dart';

final _items = List<int>.generate(24, (i) => i);

Widget _tile(BuildContext context, int item, int index) => ColoredBox(
  color: const Color(0x33888888),
  child: SizedBox(
    height: 80.0 + (item % 4) * 30,
    child: FrostText('Tile $item', tone: FrostTextTone.primary),
  ),
);

Widget _header() => const SliverToBoxAdapter(
  child: SizedBox(height: 48, child: FrostText('Grid header', tone: FrostTextTone.primary)),
);

FrostWaterfallGrid<int> _grid({
  double? preferredTileWidth,
  int? columns,
  int? maxColumns,
  double? crossAxisSpacing,
  double? mainAxisSpacing,
  EdgeInsetsGeometry? padding,
  ScrollPhysics? physics,
  bool shrinkWrap = false,
  Widget? sliverHeader,
}) => FrostWaterfallGrid<int>(
  items: _items,
  itemBuilder: _tile,
  preferredTileWidth: preferredTileWidth ?? FrostMetrics.gridExtent,
  columns: columns,
  maxColumns: maxColumns,
  crossAxisSpacing: crossAxisSpacing ?? FrostGap.grid,
  mainAxisSpacing: mainAxisSpacing ?? FrostGap.grid,
  padding: padding,
  physics: physics,
  shrinkWrap: shrinkWrap,
  sliverHeader: sliverHeader,
);

final _wide = BaselineEnv.standard.copyWith(width: 1280);
// Narrow grids (< 320 of content) use one column; 360 minus the 16 page insets is 328.
final _oneColumnLimit = [BaselineEnv.standard.copyWith(width: 335), BaselineEnv.standard.copyWith(width: 351)];

void main() {
  baselineGroup('FrostWaterfallGrid', [
    BaselineCase(
      'FrostWaterfallGrid/required',
      (_) => _grid(),
      height: 600,
      envs: [BaselineEnv.standard, BaselineEnv.narrow, _wide, BaselineEnv.largeText, ..._oneColumnLimit],
    ),
    BaselineCase('FrostWaterfallGrid/preferredTileWidth=140', (_) => _grid(preferredTileWidth: 140), height: 600),
    BaselineCase('FrostWaterfallGrid/columns=3', (_) => _grid(columns: 3), height: 600, envs: [BaselineEnv.standard, BaselineEnv.narrow]),
    BaselineCase('FrostWaterfallGrid/maxColumns=2', (_) => _grid(maxColumns: 2), height: 600, envs: [_wide]),
    BaselineCase('FrostWaterfallGrid/crossAxisSpacing=20', (_) => _grid(crossAxisSpacing: 20), height: 600),
    BaselineCase('FrostWaterfallGrid/mainAxisSpacing=20', (_) => _grid(mainAxisSpacing: 20), height: 600),
    BaselineCase('FrostWaterfallGrid/padding', (_) => _grid(padding: const EdgeInsets.all(32)), height: 600),
    BaselineCase('FrostWaterfallGrid/physics', (_) => _grid(physics: const NeverScrollableScrollPhysics()), height: 600),
    BaselineCase('FrostWaterfallGrid/shrinkWrap', (_) => _grid(shrinkWrap: true), height: 600),
    BaselineCase('FrostWaterfallGrid/sliverHeader', (_) => _grid(sliverHeader: _header()), height: 600, envs: [BaselineEnv.standard, BaselineEnv.narrow]),
    BaselineCase('FrostWaterfallGrid/items=empty', (_) => FrostWaterfallGrid<int>(items: const [], itemBuilder: _tile), height: 300),
  ]);
}
