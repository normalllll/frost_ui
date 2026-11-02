import 'package:frost_ui/frost_ui.dart';

import 'baseline.dart';

void main() {
  baselineGroup('FrostMeter', [
    BaselineCase('FrostMeter/required', (_) => const FrostMeter(value: .6, semanticLabel: 'Storage'), envs: BaselineEnv.all),
    BaselineCase('FrostMeter/value=0', (_) => const FrostMeter(value: 0, semanticLabel: 'Storage')),
    BaselineCase('FrostMeter/value=1', (_) => const FrostMeter(value: 1, semanticLabel: 'Storage')),
    BaselineCase('FrostMeter/value=clamped', (_) => const FrostMeter(value: 4, semanticLabel: 'Storage')),
    BaselineCase('FrostMeter/min+max', (_) => const FrostMeter(value: 60, min: 20, max: 100, semanticLabel: 'Temperature')),
    BaselineCase(
      'FrostMeter/marks',
      (_) => const FrostMeter(value: .6, marks: [.25, .5, .75], semanticLabel: 'Storage'),
      envs: [BaselineEnv.standard, BaselineEnv.light, BaselineEnv.largeText],
    ),
    BaselineCase('FrostMeter/dataColor', (_) => const FrostMeter(value: .6, dataColor: 3, semanticLabel: 'Storage'), envs: BaselineEnv.themes),
    BaselineCase('FrostMeter/min+max+marks', (_) => const FrostMeter(value: 60, min: 20, max: 100, marks: [40, 80, 120], semanticLabel: 'Temperature')),
  ]);
}
