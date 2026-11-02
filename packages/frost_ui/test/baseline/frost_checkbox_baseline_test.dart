import 'package:frost_ui/frost_ui.dart';

import 'baseline.dart';

void _changed(bool? _) {}

void main() {
  baselineGroup('FrostCheckbox', [
    BaselineCase(
      'FrostCheckbox/required',
      (_) => const FrostCheckbox(value: false, onChanged: null, semanticLabel: 'Agree'),
      envs: BaselineEnv.all,
    ),
    BaselineCase(
      'FrostCheckbox/onChanged',
      (_) => const FrostCheckbox(value: false, onChanged: _changed, semanticLabel: 'Agree'),
      envs: BaselineEnv.themes,
    ),
    BaselineCase(
      'FrostCheckbox/value=true',
      (_) => const FrostCheckbox(value: true, onChanged: _changed, semanticLabel: 'Agree'),
      envs: BaselineEnv.themes,
    ),
    BaselineCase('FrostCheckbox/value=true+disabled', (_) => const FrostCheckbox(value: true, onChanged: null, semanticLabel: 'Agree')),
    BaselineCase(
      'FrostCheckbox/tristate',
      (_) => const FrostCheckbox(value: null, tristate: true, onChanged: _changed, semanticLabel: 'Agree'),
      envs: BaselineEnv.themes,
    ),
    BaselineCase(
      'FrostCheckbox/tristate=true+value=false',
      (_) => const FrostCheckbox(value: false, tristate: true, onChanged: _changed, semanticLabel: 'Agree'),
    ),
    BaselineCase('FrostCheckbox/semanticLabel=null', (_) => const FrostCheckbox(value: false, onChanged: _changed, semanticLabel: null)),
    BaselineCase(
      'FrostCheckbox/value=true+touch',
      (_) => const FrostCheckbox(value: true, onChanged: _changed, semanticLabel: 'Agree'),
      envs: [BaselineEnv.touch],
    ),
    BaselineCase(
      'FrostCheckbox/onChanged#hover',
      (_) => const FrostCheckbox(value: false, onChanged: _changed, semanticLabel: 'Agree'),
      act: baselineHover,
    ),
    BaselineCase(
      'FrostCheckbox/onChanged#press',
      (_) => const FrostCheckbox(value: false, onChanged: _changed, semanticLabel: 'Agree'),
      act: baselinePress,
    ),
    BaselineCase(
      'FrostCheckbox/onChanged#focus',
      (_) => const FrostCheckbox(value: false, onChanged: _changed, semanticLabel: 'Agree'),
      act: baselineFocus,
    ),
  ]);
}
