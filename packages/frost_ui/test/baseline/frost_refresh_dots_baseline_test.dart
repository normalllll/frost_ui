import 'package:frost_ui/frost_ui.dart';

import 'baseline.dart';

void main() {
  baselineGroup('FrostRefreshDots', [BaselineCase('FrostRefreshDots/required', (_) => const FrostRefreshDots(), envs: BaselineEnv.all)]);
}
