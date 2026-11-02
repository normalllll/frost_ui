import 'package:frost_ui/frost_ui.dart';

import 'baseline.dart';

void _changed(bool _) {}

void main() {
  baselineGroup('FrostSwitch', [
    BaselineCase(
      'FrostSwitch/required',
      (_) => const FrostSwitch(value: false, onChanged: null, semanticLabel: 'Notifications'),
      envs: BaselineEnv.all,
    ),
    BaselineCase(
      'FrostSwitch/onChanged',
      (_) => const FrostSwitch(value: false, onChanged: _changed, semanticLabel: 'Notifications'),
      envs: BaselineEnv.themes,
    ),
    BaselineCase(
      'FrostSwitch/value=true',
      (_) => const FrostSwitch(value: true, onChanged: _changed, semanticLabel: 'Notifications'),
      envs: BaselineEnv.themes,
    ),
    BaselineCase('FrostSwitch/value=true+disabled', (_) => const FrostSwitch(value: true, onChanged: null, semanticLabel: 'Notifications')),
    BaselineCase(
      'FrostSwitch/value=true+touch',
      (_) => const FrostSwitch(value: true, onChanged: _changed, semanticLabel: 'Notifications'),
      envs: [BaselineEnv.touch],
    ),
    BaselineCase('FrostSwitch/semanticLabel=null', (_) => const FrostSwitch(value: false, onChanged: _changed, semanticLabel: null)),
    BaselineCase(
      'FrostSwitch/onChanged#hover',
      (_) => const FrostSwitch(value: false, onChanged: _changed, semanticLabel: 'Notifications'),
      act: baselineHover,
    ),
    BaselineCase(
      'FrostSwitch/onChanged#press',
      (_) => const FrostSwitch(value: false, onChanged: _changed, semanticLabel: 'Notifications'),
      act: baselinePress,
    ),
    BaselineCase(
      'FrostSwitch/onChanged#focus',
      (_) => const FrostSwitch(value: false, onChanged: _changed, semanticLabel: 'Notifications'),
      act: baselineFocus,
    ),
  ]);
}
