import 'package:frost_ui/frost_ui.dart';

import 'baseline.dart';

void _noop() {}

final _op = Object();

void main() {
  baselineGroup('FrostButton', [
    BaselineCase('FrostButton/required', (_) => const FrostButton(label: 'Save'), envs: BaselineEnv.all),
    BaselineCase(
      'FrostButton/onPressed',
      (_) => const FrostButton(label: 'Save', onPressed: _noop),
      envs: BaselineEnv.themes,
    ),
    BaselineCase(
      'FrostButton/onPressed#hover',
      (_) => const FrostButton(label: 'Save', onPressed: _noop),
      act: baselineHover,
    ),
    BaselineCase(
      'FrostButton/onPressed#press',
      (_) => const FrostButton(label: 'Save', onPressed: _noop),
      act: baselinePress,
    ),
    BaselineCase('FrostButton/icon', (_) => const FrostButton(label: 'Save', icon: baselineIcon, onPressed: _noop)),
    // The old `variant:` argument is now one constructor per kind. The ids are
    // the ones the loop over FrostButtonVariant.values generated.
    BaselineCase(
      'FrostButton/variant=prominent',
      (_) => const FrostButton.prominent(label: 'Save', onPressed: _noop),
      envs: BaselineEnv.themes,
    ),
    BaselineCase(
      'FrostButton/variant=standard',
      (_) => const FrostButton(label: 'Save', onPressed: _noop),
      envs: BaselineEnv.themes,
    ),
    BaselineCase(
      'FrostButton/variant=plain',
      (_) => const FrostButton.plain(label: 'Save', onPressed: _noop),
      envs: BaselineEnv.themes,
    ),
    BaselineCase(
      'FrostButton/variant=tinted',
      (_) => const FrostButton.tinted(label: 'Save', onPressed: _noop),
      envs: BaselineEnv.themes,
    ),
    BaselineCase(
      'FrostButton/variant=outlined',
      (_) => const FrostButton.outlined(label: 'Save', onPressed: _noop),
      envs: BaselineEnv.themes,
    ),
    BaselineCase('FrostButton/loading', (_) => const FrostButton(label: 'Save', state: FrostActionState.running(), onPressed: _noop)),
    BaselineCase('FrostButton/selected', (_) => const FrostButton(label: 'Save', selected: true, onPressed: _noop)),
    BaselineCase(
      'FrostButton.quiet/required',
      (_) => const FrostButton.quiet(label: 'Show all', onPressed: _noop),
      envs: BaselineEnv.all,
    ),
    BaselineCase(
      'FrostButton.icon/required',
      (_) => const FrostButton.icon(icon: baselineIcon, label: 'Add'),
      envs: BaselineEnv.all,
    ),
    // The old `style:` argument is now one constructor per kind, with the ids
    // the loop over FrostIconButtonStyle.values generated.
    BaselineCase('FrostButton.icon/style=plain', (_) => const FrostButton.icon(icon: baselineIcon, label: 'Add', onPressed: _noop)),
    BaselineCase('FrostButton.icon/style=standard', (_) => const FrostButton.iconFilled(icon: baselineIcon, label: 'Add', onPressed: _noop)),
    BaselineCase('FrostButton.icon/style=onMedia', (_) => const FrostButton.iconOnMedia(icon: baselineIcon, label: 'Add', onPressed: _noop)),
    BaselineCase(
      'FrostButton.icon/loading+onCancel',
      (_) => const FrostButton.icon(
        icon: baselineIcon,
        label: 'Add',
        state: FrostActionState.running(onCancel: _noop),
      ),
    ),
    // New API: a finished operation draws its result once, then holds it.
    BaselineCase(
      'FrostButton/state=succeeded',
      (_) => FrostButton(
        label: 'Save',
        state: FrostActionState.succeeded(operation: _op),
        onPressed: _noop,
      ),
      envs: BaselineEnv.themes,
    ),
    BaselineCase(
      'FrostButton/state=failed',
      (_) => FrostButton(
        label: 'Save',
        state: FrostActionState.failed(operation: _op),
        onPressed: _noop,
      ),
      envs: BaselineEnv.themes,
    ),
  ]);
}
