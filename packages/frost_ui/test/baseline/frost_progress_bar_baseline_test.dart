import 'package:frost_ui/frost_ui.dart';

import 'baseline.dart';
import 'feedback_baseline_support.dart';

void main() {
  baselineGroup('FrostProgressBar', [
    BaselineCase('FrostProgressBar/required', (_) => const FrostProgressBar(value: .4, semanticLabel: 'Upload'), envs: BaselineEnv.all),
    for (final value in [0.0, 1.0])
      BaselineCase(
        'FrostProgressBar/value=$value',
        (_) => FrostProgressBar(value: value, semanticLabel: 'Upload'),
        envs: BaselineEnv.themes,
      ),
    // Values outside 0–1 are clamped.
    BaselineCase('FrostProgressBar/value=1.5', (_) => const FrostProgressBar(value: 1.5, semanticLabel: 'Upload')),
    BaselineCase('FrostProgressBar/value=-0.5', (_) => const FrostProgressBar(value: -.5, semanticLabel: 'Upload')),
    BaselineCase(
      'FrostProgressBar/value#changed',
      (_) => BaselineToggle(
        builder: (_, toggled) => FrostProgressBar(value: toggled ? .8 : .2, semanticLabel: 'Upload'),
      ),
      act: baselineToggle,
    ),
  ]);
}
