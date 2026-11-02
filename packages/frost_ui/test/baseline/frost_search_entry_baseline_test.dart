import 'package:flutter/widgets.dart';
import 'package:frost_ui/frost_ui.dart';

import 'baseline.dart';
import 'controls_support.dart';

void _noop() {}

void main() {
  baselineGroup('FrostSearchEntry', [
    BaselineCase('FrostSearchEntry/required', (_) => const FrostSearchEntry(placeholder: 'Search', onPressed: null), envs: BaselineEnv.all),
    BaselineCase(
      'FrostSearchEntry/onPressed',
      (_) => const FrostSearchEntry(placeholder: 'Search', onPressed: _noop),
      envs: BaselineEnv.themes,
    ),
    BaselineCase('FrostSearchEntry/value', (_) => const FrostSearchEntry(placeholder: 'Search', value: 'sunset', onPressed: _noop)),
    BaselineCase(
      'FrostSearchEntry/shortcutLabel',
      (_) => const FrostSearchEntry(placeholder: 'Search', shortcutLabel: 'Ctrl+K', onPressed: _noop),
    ),
    for (final size in FrostControlSize.values)
      BaselineCase('FrostSearchEntry/size=${size.name}', (_) => FrostSearchEntry(placeholder: 'Search', size: size, onPressed: _noop)),
    BaselineCase(
      'FrostSearchEntry/focusNode',
      (_) => BaselineFocus(
        builder: (_, focus) => FrostSearchEntry(placeholder: 'Search', focusNode: focus, onPressed: _noop),
      ),
    ),
    BaselineCase(
      'FrostSearchEntry/onPressed+width=60',
      (_) => const SizedBox(
        width: 60,
        child: FrostSearchEntry(placeholder: 'Search', shortcutLabel: 'Ctrl+K', onPressed: _noop),
      ),
    ),
    BaselineCase(
      'FrostSearchEntry/onPressed#hover',
      (_) => const FrostSearchEntry(placeholder: 'Search', onPressed: _noop),
      act: baselineHover,
    ),
    BaselineCase(
      'FrostSearchEntry/onPressed#press',
      (_) => const FrostSearchEntry(placeholder: 'Search', onPressed: _noop),
      act: baselinePress,
    ),
    BaselineCase(
      'FrostSearchEntry/onPressed#focus',
      (_) => const FrostSearchEntry(placeholder: 'Search', onPressed: _noop),
      act: baselineFocus,
    ),
  ]);
}
