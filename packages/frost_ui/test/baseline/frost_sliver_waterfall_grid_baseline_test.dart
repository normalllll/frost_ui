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

Widget _grid({double? preferredTileWidth, int? columns, int? maxColumns, double? crossAxisSpacing, double? mainAxisSpacing, EdgeInsetsGeometry? padding}) =>
    CustomScrollView(
      slivers: [
        FrostSliverWaterfallGrid<int>(
          items: _items,
          itemBuilder: _tile,
          preferredTileWidth: preferredTileWidth ?? FrostMetrics.gridExtent,
          columns: columns,
          maxColumns: maxColumns,
          crossAxisSpacing: crossAxisSpacing ?? FrostGap.grid,
          mainAxisSpacing: mainAxisSpacing ?? FrostGap.grid,
          padding: padding,
        ),
      ],
    );

final _wide = BaselineEnv.standard.copyWith(width: 1280);

void main() {
  baselineGroup('FrostSliverWaterfallGrid', [
    BaselineCase(
      'FrostSliverWaterfallGrid/required',
      (_) => _grid(),
      height: 600,
      envs: [BaselineEnv.standard, BaselineEnv.narrow, _wide, BaselineEnv.largeText],
    ),
    BaselineCase('FrostSliverWaterfallGrid/preferredTileWidth=140', (_) => _grid(preferredTileWidth: 140), height: 600),
    BaselineCase('FrostSliverWaterfallGrid/columns=3', (_) => _grid(columns: 3), height: 600, envs: [BaselineEnv.standard, BaselineEnv.narrow]),
    BaselineCase('FrostSliverWaterfallGrid/maxColumns=2', (_) => _grid(maxColumns: 2), height: 600, envs: [_wide]),
    BaselineCase('FrostSliverWaterfallGrid/crossAxisSpacing=20', (_) => _grid(crossAxisSpacing: 20), height: 600),
    BaselineCase('FrostSliverWaterfallGrid/mainAxisSpacing=20', (_) => _grid(mainAxisSpacing: 20), height: 600),
    BaselineCase('FrostSliverWaterfallGrid/padding', (_) => _grid(padding: const EdgeInsets.all(32)), height: 600),
  ]);
}
