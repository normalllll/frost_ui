import 'package:flutter/widgets.dart';
import 'package:frost_ui/frost_ui.dart';

import 'baseline.dart';
import 'feedback_baseline_support.dart';

const _panel = SizedBox(
  width: 240,
  height: 120,
  child: DecoratedBox(
    decoration: BoxDecoration(color: Color(0xff334466)),
    child: Center(child: FrostText('Panel')),
  ),
);

// Reveals or hides the panel when toggled; it starts hidden.
Widget _toggling({bool startShown = false}) => BaselineToggle(
  builder: (_, toggled) => FrostSpringReveal(shown: startShown ? !toggled : toggled, child: _panel),
);

void main() {
  baselineGroup('FrostSpringReveal', [
    BaselineCase('FrostSpringReveal/required', (_) => const FrostSpringReveal(shown: true, child: _panel), envs: BaselineEnv.all),
    BaselineCase('FrostSpringReveal/required#hidden', (_) => const FrostSpringReveal(shown: false, child: _panel), envs: BaselineEnv.themes),
    BaselineCase('FrostSpringReveal/required#shown', (_) => _toggling(), act: baselineToggle, envs: BaselineEnv.themes),
    BaselineCase('FrostSpringReveal/required#hiding', (_) => _toggling(startShown: true), act: baselineToggle, envs: BaselineEnv.themes),
  ]);
}
