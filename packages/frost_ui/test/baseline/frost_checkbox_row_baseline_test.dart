import 'package:frost_ui/frost_ui.dart';

import 'baseline.dart';

void _changed(bool? _) {}

void main() {
  baselineGroup('FrostCheckboxRow', [
    BaselineCase(
      'FrostCheckboxRow/required',
      (_) => const FrostCheckboxRow(title: 'Remember me', value: false, onChanged: null),
      envs: BaselineEnv.all,
    ),
    BaselineCase(
      'FrostCheckboxRow/onChanged',
      (_) => const FrostCheckboxRow(title: 'Remember me', value: false, onChanged: _changed),
      envs: BaselineEnv.themes,
    ),
    BaselineCase(
      'FrostCheckboxRow/value=true',
      (_) => const FrostCheckboxRow(title: 'Remember me', value: true, onChanged: _changed),
      envs: BaselineEnv.themes,
    ),
    BaselineCase(
      'FrostCheckboxRow/subtitle',
      (_) => const FrostCheckboxRow(title: 'Remember me', subtitle: 'Stay signed in on this device', value: false, onChanged: _changed),
      envs: BaselineEnv.all,
    ),
    BaselineCase(
      'FrostCheckboxRow/tristate',
      (_) => const FrostCheckboxRow(title: 'Select all', value: null, tristate: true, onChanged: _changed),
    ),
    BaselineCase(
      'FrostCheckboxRow/tristate=true+value=true',
      (_) => const FrostCheckboxRow(title: 'Select all', value: true, tristate: true, onChanged: _changed),
    ),
    BaselineCase(
      'FrostCheckboxRow/onChanged#hover',
      (_) => const FrostCheckboxRow(title: 'Remember me', value: false, onChanged: _changed),
      act: baselineHover,
    ),
    BaselineCase(
      'FrostCheckboxRow/onChanged#press',
      (_) => const FrostCheckboxRow(title: 'Remember me', value: false, onChanged: _changed),
      act: baselinePress,
    ),
    BaselineCase(
      'FrostCheckboxRow/onChanged#focus',
      (_) => const FrostCheckboxRow(title: 'Remember me', value: false, onChanged: _changed),
      act: baselineFocus,
    ),
  ]);
}
