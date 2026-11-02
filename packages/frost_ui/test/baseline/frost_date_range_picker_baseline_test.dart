import 'package:flutter/widgets.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/controls/_calendar.dart' show FrostDateClock;

import 'baseline.dart';

void _changed(DateTimeRange? _) {}

final _today = DateTime(2026, 3, 15);
final _value = DateTimeRange(start: DateTime(2026, 3, 10), end: DateTime(2026, 3, 18));

// The calendar marks today; a fixed clock keeps the open states reproducible.
Widget _picker({
  DateTimeRange? value,
  ValueChanged<DateTimeRange?>? onChanged,
  DateTime? firstDate,
  DateTime? lastDate,
  String? placeholder,
  String? help,
  String? error,
  FrostControlSize? size,
}) => FrostDateClock(
  today: _today,
  child: FrostDateRangePicker(
    value: value,
    onChanged: onChanged,
    label: 'Period',
    firstDate: firstDate,
    lastDate: lastDate,
    placeholder: placeholder,
    help: help,
    error: error,
    size: size,
  ),
);

void main() {
  baselineGroup('FrostDateRangePicker', [
    BaselineCase('FrostDateRangePicker/required', (_) => _picker(), envs: BaselineEnv.all),
    BaselineCase('FrostDateRangePicker/onChanged', (_) => _picker(onChanged: _changed), envs: BaselineEnv.themes),
    BaselineCase(
      'FrostDateRangePicker/value',
      (_) => _picker(value: _value, onChanged: _changed),
      envs: BaselineEnv.all,
    ),
    BaselineCase('FrostDateRangePicker/value+disabled', (_) => _picker(value: _value)),
    BaselineCase(
      'FrostDateRangePicker/firstDate+lastDate',
      (_) => _picker(value: _value, onChanged: _changed, firstDate: DateTime(2026, 3, 5), lastDate: DateTime(2026, 3, 25)),
    ),
    BaselineCase('FrostDateRangePicker/placeholder', (_) => _picker(onChanged: _changed, placeholder: 'Pick a period')),
    BaselineCase('FrostDateRangePicker/help', (_) => _picker(onChanged: _changed, help: 'Both days are included')),
    BaselineCase(
      'FrostDateRangePicker/error',
      (_) => _picker(onChanged: _changed, error: 'A period is required'),
      envs: BaselineEnv.themes,
    ),
    for (final size in FrostControlSize.values)
      BaselineCase(
        'FrostDateRangePicker/size=${size.name}',
        (_) => _picker(onChanged: _changed, size: size),
        envs: [BaselineEnv.standard, BaselineEnv.touch],
      ),
    BaselineCase('FrostDateRangePicker/onChanged#hover', (_) => _picker(onChanged: _changed), act: baselineHover),
    BaselineCase('FrostDateRangePicker/onChanged#press', (_) => _picker(onChanged: _changed), act: baselinePress),
    BaselineCase('FrostDateRangePicker/onChanged#focus', (_) => _picker(onChanged: _changed), act: baselineFocus),
    BaselineCase(
      'FrostDateRangePicker/onChanged#open',
      (_) => _picker(onChanged: _changed),
      act: baselineTap,
      envs: BaselineEnv.themes,
    ),
    BaselineCase(
      'FrostDateRangePicker/value#open',
      (_) => _picker(value: _value, onChanged: _changed),
      act: baselineTap,
    ),
    BaselineCase(
      'FrostDateRangePicker/firstDate+lastDate#open',
      (_) => _picker(value: _value, onChanged: _changed, firstDate: DateTime(2026, 3, 5), lastDate: DateTime(2026, 3, 25)),
      act: baselineTap,
    ),
  ]);
}
