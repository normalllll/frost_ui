import 'package:flutter/widgets.dart';
import 'package:frost_data/frost_data.dart';
import 'package:frost_ui/frost_ui.dart';

import '../../../frost_ui/test/baseline/baseline.dart';
import '../../../frost_ui/test/baseline/feedback_baseline_support.dart';

void main() {
  baselineGroup('FrostLoadStateSwitcher', [
    BaselineCase('FrostLoadStateSwitcher/required', (_) => const FrostLoadStateSwitcher(child: FrostText('Content')), envs: BaselineEnv.all),
    BaselineCase('FrostLoadStateSwitcher/phase', (_) => const FrostLoadStateSwitcher(phase: 'content', child: FrostText('Content'))),
    BaselineCase(
      'FrostLoadStateSwitcher/animateSize',
      (_) => const FrostLoadStateSwitcher(animateSize: true, child: SizedBox(height: 80, child: FrostText('Content'))),
    ),
    BaselineCase(
      'FrostLoadStateSwitcher/phase#switched',
      (_) => BaselineToggle(
        builder: (_, toggled) => FrostLoadStateSwitcher(
          phase: toggled ? 'content' : 'loading',
          child: toggled ? const SizedBox(height: 80, child: FrostText('Content')) : const SizedBox(height: 40, child: FrostText('Loading')),
        ),
      ),
      act: baselineToggle,
    ),
    BaselineCase(
      'FrostLoadStateSwitcher/phase+animateSize#switched',
      (_) => BaselineToggle(
        builder: (_, toggled) => FrostLoadStateSwitcher(
          phase: toggled ? 'content' : 'loading',
          animateSize: true,
          child: toggled ? const SizedBox(height: 80, child: FrostText('Content')) : const SizedBox(height: 40, child: FrostText('Loading')),
        ),
      ),
      act: baselineToggle,
    ),
    // Without a phase, a different child type is a different phase.
    BaselineCase(
      'FrostLoadStateSwitcher/required#switched',
      (_) => BaselineToggle(
        builder: (_, toggled) => FrostLoadStateSwitcher(child: toggled ? const SizedBox(height: 80, child: FrostText('Content')) : const FrostText('Loading')),
      ),
      act: baselineToggle,
    ),
  ]);
}
