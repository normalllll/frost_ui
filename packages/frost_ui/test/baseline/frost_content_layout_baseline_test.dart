import 'package:flutter/widgets.dart';
import 'package:frost_ui/frost_ui.dart';

import 'baseline.dart';

Widget _primaryItem(BuildContext context, int index) => SizedBox(height: 60, child: FrostText('Primary $index', tone: FrostTextTone.primary));
Widget _auxiliaryItem(BuildContext context, int index) => SizedBox(height: 60, child: FrostText('Auxiliary $index', tone: FrostTextTone.primary));

List<Widget> _primary() => [SliverList.builder(itemCount: 14, itemBuilder: _primaryItem)];
List<Widget> _auxiliary() => [SliverList.builder(itemCount: 6, itemBuilder: _auxiliaryItem)];

// The auxiliary flow sits beside the primary one only when the column offers
// the reading measure plus 320 (about 1104 points at the full column cap);
// 900 stacks it, 1280 puts it beside, 1100 and 1150 straddle the limit.
final _wide = BaselineEnv.standard.copyWith(width: 1280);
final _stacked = BaselineEnv.standard.copyWith(width: 900);
final _around = [BaselineEnv.standard.copyWith(width: 1150), BaselineEnv.standard.copyWith(width: 1100)];

void main() {
  baselineGroup('FrostContentLayout', [
    BaselineCase('FrostContentLayout/required', (_) => FrostContentLayout(slivers: _primary()), height: 800, envs: [_wide, BaselineEnv.narrow]),
    BaselineCase(
      'FrostContentLayout/auxiliarySlivers',
      (_) => FrostContentLayout(slivers: _primary(), auxiliarySlivers: _auxiliary()),
      height: 800,
      envs: [_wide, _stacked, BaselineEnv.narrow, ..._around, BaselineEnv.largeText.copyWith(width: 1280)],
    ),
    BaselineCase(
      'FrostContentLayout/controller',
      (_) => FrostContentLayout(slivers: _primary(), controller: ScrollController()),
      height: 800,
      envs: [_wide],
    ),
  ]);
}
