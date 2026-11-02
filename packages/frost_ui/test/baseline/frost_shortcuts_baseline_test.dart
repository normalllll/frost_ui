import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/controls/shortcuts.dart' show FrostShortcutX;

import 'baseline.dart';

void _noop() {}

const _child = FrostButton(label: 'Save', onPressed: _noop);
const _save = FrostShortcut(LogicalKeyboardKey.keyS, primary: true);

void main() {
  baselineGroup('FrostShortcuts', [
    BaselineCase(
      'FrostShortcuts/required',
      (_) => const FrostShortcuts(bindings: {}, child: _child),
      envs: BaselineEnv.all,
    ),
    BaselineCase('FrostShortcuts/bindings', (_) => FrostShortcuts(bindings: {_save: _noop}, child: _child)),
    BaselineCase(
      'FrostShortcuts/bindings=modifiers',
      (_) => FrostShortcuts(
        bindings: {
          const FrostShortcut(LogicalKeyboardKey.keyS, primary: true, shift: true): _noop,
          const FrostShortcut(LogicalKeyboardKey.keyN, alt: true): _noop,
          const FrostShortcut(LogicalKeyboardKey.slash): _noop,
        },
        child: _child,
      ),
    ),
    BaselineCase('FrostShortcutX.frostShortcut/required', (_) => _child.frostShortcut(_save, _noop)),
    BaselineCase(
      'FrostShortcuts/bindings#focus',
      (_) => FrostShortcuts(bindings: {_save: _noop}, child: _child),
      act: baselineFocus,
    ),
  ]);
}
