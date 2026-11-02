import 'package:frost_ui/frost_ui.dart';

import 'baseline.dart';

void _changed(num _) {}

void main() {
  baselineGroup('FrostNumberField', [
    BaselineCase('FrostNumberField/required', (_) => const FrostNumberField(value: 5, onChanged: null), envs: BaselineEnv.all),
    BaselineCase('FrostNumberField/onChanged', (_) => const FrostNumberField(value: 5, onChanged: _changed), envs: BaselineEnv.themes),
    BaselineCase('FrostNumberField/min+max', (_) => const FrostNumberField(value: 10, min: 10, max: 20, onChanged: _changed)),
    BaselineCase('FrostNumberField/step', (_) => const FrostNumberField(value: 10, step: 5, onChanged: _changed)),
    BaselineCase(
      'FrostNumberField/unit',
      (_) => const FrostNumberField(value: 5, unit: 'px', onChanged: _changed),
      envs: BaselineEnv.themes,
    ),
    BaselineCase(
      'FrostNumberField/label',
      (_) => const FrostNumberField(value: 5, label: 'Width', onChanged: _changed),
      envs: BaselineEnv.all,
    ),
    BaselineCase('FrostNumberField/help', (_) => const FrostNumberField(value: 5, label: 'Width', help: 'In pixels', onChanged: _changed)),
    BaselineCase(
      'FrostNumberField/error',
      (_) => const FrostNumberField(value: 5, label: 'Width', error: 'Too narrow', onChanged: _changed),
      envs: BaselineEnv.themes,
    ),
    for (final size in FrostControlSize.values)
      BaselineCase(
        'FrostNumberField/size=${size.name}',
        (_) => FrostNumberField(value: 5, size: size, onChanged: _changed),
        envs: [BaselineEnv.standard, BaselineEnv.touch],
      ),
    BaselineCase('FrostNumberField/decimals', (_) => const FrostNumberField(value: 1.5, decimals: 2, step: .25, onChanged: _changed)),
    BaselineCase('FrostNumberField/onChanged#hover', (_) => const FrostNumberField(value: 5, onChanged: _changed), act: baselineHover),
    BaselineCase('FrostNumberField/onChanged#focus', (_) => const FrostNumberField(value: 5, onChanged: _changed), act: baselineFocus),
    BaselineCase('FrostNumberField/min#focus', (_) => const FrostNumberField(value: 0, onChanged: _changed), act: baselineFocus),
  ]);
}
