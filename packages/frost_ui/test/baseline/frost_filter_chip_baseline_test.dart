import 'package:frost_ui/frost_ui.dart';

import 'baseline.dart';

void _noop() {}

const _pointerAndTouch = [BaselineEnv.standard, BaselineEnv.touch];

void main() {
  baselineGroup('FrostFilterChip', [
    BaselineCase('FrostFilterChip/required', (_) => const FrostFilterChip(label: 'Rating'), envs: BaselineEnv.all),
    BaselineCase(
      'FrostFilterChip/value',
      (_) => const FrostFilterChip(label: 'Rating', value: 'Safe'),
      envs: BaselineEnv.themes,
    ),
    BaselineCase(
      'FrostFilterChip/onPressed',
      (_) => const FrostFilterChip(label: 'Rating', onPressed: _noop),
      envs: _pointerAndTouch,
    ),
    BaselineCase(
      'FrostFilterChip/onPressed#hover',
      (_) => const FrostFilterChip(label: 'Rating', onPressed: _noop),
      act: baselineHover,
    ),
    BaselineCase(
      'FrostFilterChip/onPressed#press',
      (_) => const FrostFilterChip(label: 'Rating', onPressed: _noop),
      act: baselinePress,
    ),
    BaselineCase(
      'FrostFilterChip/onPressed#focus',
      (_) => const FrostFilterChip(label: 'Rating', onPressed: _noop),
      act: baselineFocus,
    ),
    BaselineCase(
      'FrostFilterChip/onClear',
      (_) => const FrostFilterChip(label: 'Rating', onClear: _noop),
      envs: _pointerAndTouch,
    ),
    BaselineCase(
      'FrostFilterChip/onClear#focus',
      (_) => const FrostFilterChip(label: 'Rating', onClear: _noop),
      act: baselineFocus,
    ),
    BaselineCase(
      'FrostFilterChip/onPressed+onClear',
      (_) => const FrostFilterChip(label: 'Rating', value: 'Safe', onPressed: _noop, onClear: _noop),
      envs: BaselineEnv.all,
    ),
    BaselineCase(
      'FrostFilterChip/onPressed+onClear#hover',
      (_) => const FrostFilterChip(label: 'Rating', value: 'Safe', onPressed: _noop, onClear: _noop),
      act: baselineHover,
    ),
    BaselineCase(
      'FrostFilterChip/onPressed+onClear#focus',
      (_) => const FrostFilterChip(label: 'Rating', value: 'Safe', onPressed: _noop, onClear: _noop),
      act: baselineFocus,
    ),
  ]);
}
