import 'package:frost_ui/frost_ui.dart';

import 'baseline.dart';

void main() {
  baselineGroup('FrostDataDot', [
    BaselineCase('FrostDataDot/required', (_) => const FrostDataDot(0), envs: BaselineEnv.all),
    for (final index in [1, 2, 3, 4, 5, 6, 7]) BaselineCase('FrostDataDot/index=$index', (_) => FrostDataDot(index), envs: BaselineEnv.themes),
    BaselineCase('FrostDataDot/index=wrapped', (_) => const FrostDataDot(100)),
  ]);
}
