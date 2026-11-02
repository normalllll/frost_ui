import 'package:flutter/widgets.dart';
import 'package:frost_ui/frost_ui.dart';

import 'baseline.dart';

Widget _wide(BuildContext context) => const SizedBox(
  width: 500,
  height: 40,
  child: ColoredBox(
    color: Color(0x33888888),
    child: FrostText('Wide candidate', tone: FrostTextTone.primary),
  ),
);
Widget _medium(BuildContext context) => const SizedBox(
  width: 300,
  height: 40,
  child: ColoredBox(
    color: Color(0x33888888),
    child: FrostText('Medium candidate', tone: FrostTextTone.primary),
  ),
);
Widget _small(BuildContext context) => const SizedBox(
  width: 120,
  height: 40,
  child: ColoredBox(
    color: Color(0x33888888),
    child: FrostText('Small', tone: FrostTextTone.primary),
  ),
);

Widget _required(BuildContext context) => FrostFit(candidates: [_wide]);
Widget _candidates(BuildContext context) => FrostFit(candidates: [_wide, _medium, _small]);

// The first candidate that fits wins: 500 fits from 500 up, 300 from 300 up.
final _threshold = [
  BaselineEnv.standard.copyWith(width: 499),
  BaselineEnv.standard.copyWith(width: 500),
  BaselineEnv.standard.copyWith(width: 299),
  BaselineEnv.standard.copyWith(width: 300),
  BaselineEnv.standard.copyWith(width: 119),
];

void main() {
  baselineGroup('FrostFit', [
    BaselineCase('FrostFit/required', _required, envs: [BaselineEnv.standard, BaselineEnv.narrow]),
    BaselineCase('FrostFit/candidates', _candidates, envs: [BaselineEnv.standard, BaselineEnv.narrow, BaselineEnv.light, ..._threshold]),
  ]);
}
