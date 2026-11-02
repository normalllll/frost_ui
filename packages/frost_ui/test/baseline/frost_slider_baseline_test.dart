import 'package:frost_ui/frost_ui.dart';

import 'baseline.dart';

void _changed(double _) {}

String _label(double value) => '${value.round()} of 10';

void main() {
  baselineGroup('FrostSlider', [
    BaselineCase('FrostSlider/required', (_) => const FrostSlider(value: .5, onChanged: null, semanticLabel: 'Volume'), envs: BaselineEnv.all),
    BaselineCase(
      'FrostSlider/onChanged',
      (_) => const FrostSlider(value: .5, onChanged: _changed, semanticLabel: 'Volume'),
      envs: BaselineEnv.themes,
    ),
    BaselineCase('FrostSlider/value=0', (_) => const FrostSlider(value: 0, onChanged: _changed, semanticLabel: 'Volume')),
    BaselineCase('FrostSlider/value=1', (_) => const FrostSlider(value: 1, onChanged: _changed, semanticLabel: 'Volume')),
    BaselineCase('FrostSlider/min+max', (_) => const FrostSlider(value: 15, min: 10, max: 20, onChanged: _changed, semanticLabel: 'Volume')),
    BaselineCase('FrostSlider/divisions', (_) => const FrostSlider(value: .5, divisions: 4, onChanged: _changed, semanticLabel: 'Volume')),
    BaselineCase('FrostSlider/onChangeEnd', (_) => FrostSlider(value: .5, onChanged: _changed, onChangeEnd: _changed, semanticLabel: 'Volume')),
    BaselineCase('FrostSlider/valueLabel', (_) => FrostSlider(value: 5, min: 0, max: 10, onChanged: _changed, semanticLabel: 'Volume', valueLabel: _label)),
    BaselineCase(
      'FrostSlider/onChanged+touch',
      (_) => const FrostSlider(value: .5, onChanged: _changed, semanticLabel: 'Volume'),
      envs: [BaselineEnv.touch],
    ),
    BaselineCase(
      'FrostSlider/onChanged#hover',
      (_) => const FrostSlider(value: .5, onChanged: _changed, semanticLabel: 'Volume'),
      act: baselineHover,
    ),
    BaselineCase(
      'FrostSlider/onChanged#press',
      (_) => const FrostSlider(value: .5, onChanged: _changed, semanticLabel: 'Volume'),
      act: baselinePress,
    ),
    BaselineCase(
      'FrostSlider/onChanged#focus',
      (_) => const FrostSlider(value: .5, onChanged: _changed, semanticLabel: 'Volume'),
      act: baselineFocus,
    ),
  ]);
}
