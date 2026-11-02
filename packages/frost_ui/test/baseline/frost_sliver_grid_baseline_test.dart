import 'package:flutter/widgets.dart';
import 'package:frost_ui/frost_ui.dart';

import 'baseline.dart';

Widget _cell(BuildContext context, int index) => ColoredBox(
  color: const Color(0x33888888),
  child: FrostText('Cell $index', tone: FrostTextTone.primary),
);

Widget _grid({int itemCount = 9, double aspectRatio = 1.5}) => SizedBox(
  height: 500,
  child: CustomScrollView(
    slivers: [FrostSliverGrid(minItemWidth: 160, itemCount: itemCount, itemBuilder: _cell, aspectRatio: aspectRatio)],
  ),
);

final _wide = BaselineEnv.standard.copyWith(width: 1280);
final _around = [BaselineEnv.standard.copyWith(width: 335), BaselineEnv.standard.copyWith(width: 336)];

void main() {
  baselineGroup('FrostSliverGrid', [
    // aspectRatio is required in practice: a lazy grid needs known geometry.
    BaselineCase('FrostSliverGrid/required', (_) => _grid(), envs: [BaselineEnv.standard, BaselineEnv.narrow, _wide, ..._around]),
    BaselineCase('FrostSliverGrid/aspectRatio=0.75', (_) => _grid(aspectRatio: .75)),
    BaselineCase('FrostSliverGrid/itemCount=0', (_) => _grid(itemCount: 0)),
  ]);
}
