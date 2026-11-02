import 'package:frost_ui/frost_ui.dart';

import 'baseline.dart';

void _noop() {}

void main() {
  baselineGroup('FrostCompactBackButton', [
    BaselineCase('FrostCompactBackButton/required', (_) => const FrostCompactBackButton(onPressed: _noop), envs: BaselineEnv.all),
    BaselineCase('FrostCompactBackButton/required#hover', (_) => const FrostCompactBackButton(onPressed: _noop), act: baselineHover),
    BaselineCase('FrostCompactBackButton/required#press', (_) => const FrostCompactBackButton(onPressed: _noop), act: baselinePress),
    BaselineCase('FrostCompactBackButton/required#focus', (_) => const FrostCompactBackButton(onPressed: _noop), act: baselineFocus),
    BaselineCase('FrostCompactBackButton/onPressed=null', (_) => const FrostCompactBackButton(onPressed: null)),
  ]);
}
