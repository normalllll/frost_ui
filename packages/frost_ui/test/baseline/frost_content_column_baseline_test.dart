import 'package:flutter/widgets.dart';
import 'package:frost_ui/frost_ui.dart';

import 'baseline.dart';

const _child = ColoredBox(
  color: Color(0x33888888),
  child: SizedBox(height: 48, child: FrostText('Column content', tone: FrostTextTone.primary)),
);

Widget _required(BuildContext context) => const FrostContentColumn(child: _child);
Widget _maxWidth(BuildContext context) => const FrostContentColumn(maxWidth: 480, child: _child);
Widget _unbounded(BuildContext context) => const FrostContentColumn(maxWidth: double.infinity, child: _child);

final _wide = BaselineEnv.standard.copyWith(width: 1280);

void main() {
  baselineGroup('FrostContentColumn', [
    BaselineCase('FrostContentColumn/required', _required, envs: [_wide, BaselineEnv.standard, BaselineEnv.narrow]),
    BaselineCase('FrostContentColumn/maxWidth', _maxWidth, envs: [_wide, BaselineEnv.narrow]),
    BaselineCase('FrostContentColumn/maxWidth=infinity', _unbounded, envs: [_wide]),
  ]);
}
