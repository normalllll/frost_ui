import 'package:frost_ui/frost_ui.dart';
import 'package:material_ui/material_ui.dart' show Color;

import 'baseline.dart';
import 'controls_support.dart';

void _noop() {}

const _pink = Color(0xFFE5487A);

void main() {
  baselineGroup('FrostColorSwatch', [
    BaselineCase(
      'FrostColorSwatch/required',
      (_) => const FrostColorSwatch(color: _pink, label: 'Pink'),
      envs: BaselineEnv.all,
    ),
    BaselineCase(
      'FrostColorSwatch/onPressed',
      (_) => const FrostColorSwatch(color: _pink, label: 'Pink', onPressed: _noop),
      envs: BaselineEnv.themes,
    ),
    BaselineCase(
      'FrostColorSwatch/selected',
      (_) => const FrostColorSwatch(color: _pink, label: 'Pink', selected: true, onPressed: _noop),
      envs: BaselineEnv.themes,
    ),
    BaselineCase('FrostColorSwatch/selected+disabled', (_) => const FrostColorSwatch(color: _pink, label: 'Pink', selected: true)),
    BaselineCase(
      'FrostColorSwatch/icon',
      (_) => const FrostColorSwatch(color: _pink, label: 'Custom', icon: baselineIcon, onPressed: _noop),
      envs: BaselineEnv.themes,
    ),
    BaselineCase(
      'FrostColorSwatch/icon+selected',
      (_) => const FrostColorSwatch(color: _pink, label: 'Custom', icon: baselineIcon, selected: true, onPressed: _noop),
    ),
    BaselineCase(
      'FrostColorSwatch/focusNode',
      (_) => BaselineFocus(
        builder: (_, focus) => FrostColorSwatch(color: _pink, label: 'Pink', focusNode: focus, onPressed: _noop),
      ),
    ),
    BaselineCase(
      'FrostColorSwatch/onPressed#hover',
      (_) => const FrostColorSwatch(color: _pink, label: 'Pink', onPressed: _noop),
      act: baselineHover,
    ),
    BaselineCase(
      'FrostColorSwatch/onPressed#press',
      (_) => const FrostColorSwatch(color: _pink, label: 'Pink', onPressed: _noop),
      act: baselinePress,
    ),
    BaselineCase(
      'FrostColorSwatch/onPressed#focus',
      (_) => const FrostColorSwatch(color: _pink, label: 'Pink', onPressed: _noop),
      act: baselineFocus,
    ),
  ]);
}
