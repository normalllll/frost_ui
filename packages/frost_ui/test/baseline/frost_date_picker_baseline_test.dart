import 'package:flutter/widgets.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/controls/_calendar.dart' show FrostDateClock;

import 'baseline.dart';

void _changed(DateTime? _) {}

final _today = DateTime(2026, 3, 15);
final _value = DateTime(2026, 3, 12);

// The calendar marks today; a fixed clock keeps the open states reproducible.
Widget _picker({
  DateTime? value,
  ValueChanged<DateTime?>? onChanged,
  DateTime? firstDate,
  DateTime? lastDate,
  String? placeholder,
  String? help,
  String? error,
  bool clearable = false,
  FrostControlSize? size,
}) => FrostDateClock(
  today: _today,
  child: FrostDatePicker(
    value: value,
    onChanged: onChanged,
    label: 'Due date',
    firstDate: firstDate,
    lastDate: lastDate,
    placeholder: placeholder,
    help: help,
    error: error,
    clearable: clearable,
    size: size,
  ),
);

void main() {
  baselineGroup('FrostDatePicker', [
    BaselineCase('FrostDatePicker/required', (_) => _picker(), envs: BaselineEnv.all),
    BaselineCase('FrostDatePicker/onChanged', (_) => _picker(onChanged: _changed), envs: BaselineEnv.themes),
    BaselineCase(
      'FrostDatePicker/value',
      (_) => _picker(value: _value, onChanged: _changed),
      envs: BaselineEnv.themes,
    ),
    BaselineCase('FrostDatePicker/value+disabled', (_) => _picker(value: _value)),
    BaselineCase(
      'FrostDatePicker/firstDate+lastDate',
      (_) => _picker(value: _value, onChanged: _changed, firstDate: DateTime(2026, 3, 5), lastDate: DateTime(2026, 3, 25)),
    ),
    BaselineCase('FrostDatePicker/placeholder', (_) => _picker(onChanged: _changed, placeholder: 'Pick a date')),
    BaselineCase('FrostDatePicker/help', (_) => _picker(onChanged: _changed, help: 'Shown on the card')),
    BaselineCase(
      'FrostDatePicker/error',
      (_) => _picker(onChanged: _changed, error: 'A date is required'),
      envs: BaselineEnv.themes,
    ),
    BaselineCase('FrostDatePicker/clearable', (_) => _picker(value: _value, onChanged: _changed, clearable: true)),
    for (final size in FrostControlSize.values)
      BaselineCase(
        'FrostDatePicker/size=${size.name}',
        (_) => _picker(onChanged: _changed, size: size),
        envs: [BaselineEnv.standard, BaselineEnv.touch],
      ),
    BaselineCase('FrostDatePicker/onChanged#hover', (_) => _picker(onChanged: _changed), act: baselineHover),
    BaselineCase('FrostDatePicker/onChanged#press', (_) => _picker(onChanged: _changed), act: baselinePress),
    BaselineCase('FrostDatePicker/onChanged#focus', (_) => _picker(onChanged: _changed), act: baselineFocus),
    BaselineCase(
      'FrostDatePicker/onChanged#open',
      (_) => _picker(onChanged: _changed),
      act: baselineTap,
      envs: BaselineEnv.themes,
    ),
    BaselineCase(
      'FrostDatePicker/value#open',
      (_) => _picker(value: _value, onChanged: _changed),
      act: baselineTap,
    ),
    BaselineCase(
      'FrostDatePicker/firstDate+lastDate#open',
      (_) => _picker(value: _value, onChanged: _changed, firstDate: DateTime(2026, 3, 5), lastDate: DateTime(2026, 3, 25)),
      act: baselineTap,
    ),
    BaselineCase(
      'FrostDatePicker/clearable#open',
      (_) => _picker(value: _value, onChanged: _changed, clearable: true),
      act: baselineTap,
    ),
  ]);
}
