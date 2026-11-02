import 'package:flutter/widgets.dart';
import 'package:frost_ui/frost_ui.dart';

import 'baseline.dart';

List<Widget> _chips() => [
  for (var i = 0; i < 14; i++)
    DecoratedBox(
      decoration: const BoxDecoration(color: Color(0x33888888)),
      child: SizedBox(
        width: 90.0 + (i % 3) * 20,
        height: 28,
        child: FrostText('Chip $i', tone: FrostTextTone.primary),
      ),
    ),
];

void main() {
  baselineGroup('FrostWrap', [
    BaselineCase('FrostWrap/required', (_) => FrostWrap(children: _chips()), envs: [BaselineEnv.standard, BaselineEnv.narrow, BaselineEnv.largeText]),
    BaselineCase('FrostWrap/compact', (_) => FrostWrap(compact: true, children: _chips()), envs: [BaselineEnv.standard, BaselineEnv.narrow]),
    BaselineCase('FrostWrap/children=empty', (_) => const FrostWrap(children: [])),
  ]);
}
