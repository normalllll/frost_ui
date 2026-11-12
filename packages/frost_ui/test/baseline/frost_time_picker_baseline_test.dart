import 'package:frost_ui/frost_ui.dart';

import 'baseline.dart';

void _changed(FrostTimeOfDay? _) {}

const _value = (hour: 15, minute: 45);

void main() {
  baselineGroup('FrostTimePicker', [
    BaselineCase('FrostTimePicker/required', (_) => const FrostTimePicker(value: null, onChanged: null, label: 'Start time'), envs: BaselineEnv.all),
    BaselineCase(
      'FrostTimePicker/onChanged',
      (_) => const FrostTimePicker(value: null, onChanged: _changed, label: 'Start time'),
      envs: BaselineEnv.themes,
    ),
    BaselineCase(
      'FrostTimePicker/value',
      (_) => const FrostTimePicker(value: _value, onChanged: _changed, label: 'Start time'),
      envs: BaselineEnv.all,
    ),
    BaselineCase('FrostTimePicker/value+disabled', (_) => const FrostTimePicker(value: _value, onChanged: null, label: 'Start time')),
    BaselineCase(
      'FrostTimePicker/value=midnight',
      (_) => const FrostTimePicker(value: (hour: 0, minute: 5), onChanged: _changed, label: 'Start time'),
    ),
    BaselineCase('FrostTimePicker/help', (_) => const FrostTimePicker(value: _value, onChanged: _changed, label: 'Start time', help: 'In your time zone')),
    BaselineCase(
      'FrostTimePicker/error',
      (_) => const FrostTimePicker(value: null, onChanged: _changed, label: 'Start time', error: 'A time is required'),
      envs: BaselineEnv.themes,
    ),
    BaselineCase('FrostTimePicker/minuteStep', (_) => const FrostTimePicker(value: _value, onChanged: _changed, label: 'Start time', minuteStep: 15)),
    for (final size in FrostControlSize.values)
      BaselineCase(
        'FrostTimePicker/size=${size.name}',
        (_) => FrostTimePicker(value: _value, onChanged: _changed, label: 'Start time', size: size),
        envs: [BaselineEnv.standard, BaselineEnv.touch],
      ),
    BaselineCase(
      'FrostTimePicker/onChanged#hover',
      (_) => const FrostTimePicker(value: _value, onChanged: _changed, label: 'Start time'),
      act: baselineHover,
    ),
    BaselineCase(
      'FrostTimePicker/onChanged#focus',
      (_) => const FrostTimePicker(value: _value, onChanged: _changed, label: 'Start time'),
      act: baselineFocus,
    ),
    BaselineCase(
      'FrostTimePicker/empty#focus',
      (_) => const FrostTimePicker(value: null, onChanged: _changed, label: 'Start time'),
      act: baselineFocus,
    ),
  ]);
}
