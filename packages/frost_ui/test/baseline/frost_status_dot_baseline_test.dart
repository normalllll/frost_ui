import 'package:frost_ui/frost_ui.dart';

import 'baseline.dart';

void main() {
  baselineGroup('FrostStatusDot', [
    BaselineCase('FrostStatusDot/required', (_) => const FrostStatusDot(tone: FrostStatusTone.neutral), envs: BaselineEnv.all),
    for (final tone in FrostStatusTone.values) ...[
      BaselineCase('FrostStatusDot/tone=${tone.name}', (_) => FrostStatusDot(tone: tone), envs: BaselineEnv.themes),
      BaselineCase(
        'FrostStatusDot/tone=${tone.name}+label',
        (_) => FrostStatusDot(tone: tone, label: 'Status'),
        envs: BaselineEnv.themes,
      ),
    ],
    BaselineCase(
      'FrostStatusDot/label',
      (_) => const FrostStatusDot(tone: FrostStatusTone.neutral, label: 'Status'),
      envs: [BaselineEnv.standard, BaselineEnv.largeText, BaselineEnv.narrow],
    ),
  ]);
}
