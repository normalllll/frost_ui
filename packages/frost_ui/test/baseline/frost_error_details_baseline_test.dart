import 'package:frost_ui/frost_ui.dart';

import 'baseline.dart';
import 'feedback_baseline_support.dart';

void main() {
  const details = 'status=500\nendpoint=/api/v1/items';
  baselineGroup('FrostErrorDetails', [
    BaselineCase('FrostErrorDetails/required', (_) => const FrostErrorDetails(details: details), envs: BaselineEnv.all),
    BaselineCase(
      'FrostErrorDetails/required#open',
      (_) => const FrostErrorDetails(details: details),
      act: baselineTapText('L.errorDetails'),
      envs: BaselineEnv.themes,
    ),
    BaselineCase('FrostErrorDetails/initiallyExpanded', (_) => const FrostErrorDetails(details: details, initiallyExpanded: true), envs: BaselineEnv.themes),
    BaselineCase('FrostErrorDetails/details=long', (_) => FrostErrorDetails(details: List.generate(30, (i) => 'line $i').join('\n'), initiallyExpanded: true)),
  ]);
}
