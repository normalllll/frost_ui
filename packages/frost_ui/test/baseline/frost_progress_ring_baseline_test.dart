import 'package:frost_ui/frost_ui.dart';

import 'baseline.dart';
import 'feedback_baseline_support.dart';

void main() {
  baselineGroup('FrostProgressRing', [
    BaselineCase('FrostProgressRing/required', (_) => const FrostProgressRing(value: .4, semanticLabel: 'Upload'), envs: BaselineEnv.all),
    for (final value in [0.0, 1.0])
      BaselineCase(
        'FrostProgressRing/value=$value',
        (_) => FrostProgressRing(value: value, semanticLabel: 'Upload'),
        envs: BaselineEnv.themes,
      ),
    // Values outside 0–1 are clamped.
    BaselineCase('FrostProgressRing/value=1.5', (_) => const FrostProgressRing(value: 1.5, semanticLabel: 'Upload')),
    BaselineCase('FrostProgressRing/value=-0.5', (_) => const FrostProgressRing(value: -.5, semanticLabel: 'Upload')),
    for (final size in FrostControlSize.values)
      BaselineCase(
        'FrostProgressRing/size=${size.name}',
        (_) => FrostProgressRing(value: .4, size: size, semanticLabel: 'Upload'),
        envs: BaselineEnv.themes,
      ),
    BaselineCase(
      'FrostProgressRing/value#changed',
      (_) => BaselineToggle(
        builder: (_, toggled) => FrostProgressRing(value: toggled ? .8 : .2, semanticLabel: 'Upload'),
      ),
      act: baselineToggle,
    ),
  ]);
}
