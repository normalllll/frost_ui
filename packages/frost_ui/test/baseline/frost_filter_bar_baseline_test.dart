import 'package:frost_ui/frost_ui.dart';

import 'baseline.dart';

void _noop() {}

const _chips = [
  FrostFilterChip(label: 'Rating', value: 'Safe', onPressed: _noop, onClear: _noop),
  FrostFilterChip(label: 'Tag', value: 'Landscape', onPressed: _noop, onClear: _noop),
  FrostFilterChip(label: 'Size', value: 'Large', onPressed: _noop, onClear: _noop),
];

const _manyChips = [
  ..._chips,
  FrostFilterChip(label: 'Artist', value: 'Somebody With A Long Name', onPressed: _noop, onClear: _noop),
  FrostFilterChip(label: 'Date', value: '2024-01-01 to 2024-12-31', onPressed: _noop, onClear: _noop),
  FrostFilterChip(label: 'Source', value: 'Everywhere', onPressed: _noop, onClear: _noop),
];

void main() {
  baselineGroup('FrostFilterBar', [
    BaselineCase('FrostFilterBar/required', (_) => const FrostFilterBar(chips: _chips), envs: BaselineEnv.all),
    BaselineCase(
      'FrostFilterBar/chips=single',
      (_) => const FrostFilterBar(
        chips: [FrostFilterChip(label: 'Rating', value: 'Safe', onClear: _noop)],
      ),
    ),
    BaselineCase('FrostFilterBar/chips=overflowing', (_) => const FrostFilterBar(chips: _manyChips), envs: [BaselineEnv.standard, BaselineEnv.narrow]),
    BaselineCase('FrostFilterBar/chips=empty', (_) => const FrostFilterBar(chips: [])),
    BaselineCase(
      'FrostFilterBar/onClearAll',
      (_) => const FrostFilterBar(chips: _chips, onClearAll: _noop),
      envs: [BaselineEnv.standard, BaselineEnv.light, BaselineEnv.touch, BaselineEnv.narrow],
    ),
    BaselineCase(
      'FrostFilterBar/onClearAll#focus',
      (_) => const FrostFilterBar(chips: _chips, onClearAll: _noop),
      act: baselineFocus,
    ),
    BaselineCase('FrostFilterBar/chips=empty+onClearAll', (_) => const FrostFilterBar(chips: [], onClearAll: _noop)),
  ]);
}
