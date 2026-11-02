import 'package:flutter/widgets.dart';
import 'package:frost_ui/frost_ui.dart';

import 'baseline.dart';

const _sliver = SliverToBoxAdapter(
  child: ColoredBox(
    color: Color(0x33888888),
    child: SizedBox(height: 48, child: FrostText('Column content', tone: FrostTextTone.primary)),
  ),
);

Widget _required(BuildContext context) => const SizedBox(
  height: 200,
  child: CustomScrollView(slivers: [FrostSliverContentColumn(sliver: _sliver)]),
);
Widget _maxWidth(BuildContext context) => const SizedBox(
  height: 200,
  child: CustomScrollView(slivers: [FrostSliverContentColumn(maxWidth: 480, sliver: _sliver)]),
);

final _wide = BaselineEnv.standard.copyWith(width: 1280);

void main() {
  baselineGroup('FrostSliverContentColumn', [
    BaselineCase('FrostSliverContentColumn/required', _required, envs: [_wide, BaselineEnv.standard, BaselineEnv.narrow]),
    BaselineCase('FrostSliverContentColumn/maxWidth', _maxWidth, envs: [_wide, BaselineEnv.narrow]),
  ]);
}
