import 'package:flutter/widgets.dart';
import 'package:frost_ui/frost_ui.dart';

import 'baseline.dart';
import 'nav_overlay_support.dart';

// FrostAlert lives in a modal route, so every case opens it from a button.
Widget _alert(FrostAlert Function() build) => launcher((context) => showFrostDialog<Object?>(context: context, builder: (_) => build()));

const _ok = [FrostDialogAction<Object?>(label: 'OK', isDefault: true)];

void main() {
  baselineGroup('FrostAlert', [
    BaselineCase(
      'FrostAlert/required#open',
      (_) => _alert(() => FrostAlert(title: 'Saved', actions: _ok)),
      act: tapTrigger,
      envs: [...BaselineEnv.themes, BaselineEnv.largeText, BaselineEnv.touch, BaselineEnv.narrow],
    ),
    BaselineCase(
      'FrostAlert/message#open',
      (_) => _alert(() => FrostAlert(title: 'Saved', message: 'The item was saved.', actions: _ok)),
      act: tapTrigger,
      envs: BaselineEnv.themes,
    ),
    BaselineCase(
      'FrostAlert/message=long#open',
      (_) => _alert(() => FrostAlert(title: 'Saved', message: List.filled(30, 'A long message').join(' '), actions: _ok)),
      act: tapTrigger,
    ),
    BaselineCase(
      'FrostAlert/actions=two#open',
      (_) => _alert(() => FrostAlert(title: 'Discard changes?', message: 'This cannot be undone.', actions: dialogActions)),
      act: tapTrigger,
      envs: BaselineEnv.themes,
    ),
    BaselineCase(
      'FrostAlert/actions=destructive#open',
      (_) => _alert(
        () => FrostAlert(
          title: 'Delete item?',
          actions: const [
            FrostDialogAction(label: 'Cancel', role: FrostButtonRole.cancel),
            FrostDialogAction(label: 'Delete', role: FrostButtonRole.destructive, isDefault: true),
          ],
        ),
      ),
      act: tapTrigger,
    ),
    BaselineCase(
      'FrostAlert/actions=three#open',
      (_) => _alert(
        () => FrostAlert(
          title: 'Save changes?',
          actions: const [
            FrostDialogAction(label: 'Cancel', role: FrostButtonRole.cancel),
            FrostDialogAction(label: 'Do not save'),
            FrostDialogAction(label: 'Save', isDefault: true),
          ],
        ),
      ),
      act: tapTrigger,
    ),
    BaselineCase(
      'FrostAlert/actions=disabled#open',
      (_) => _alert(
        () => FrostAlert(
          title: 'Saved',
          actions: const [
            FrostDialogAction(label: 'Cancel', role: FrostButtonRole.cancel),
            FrostDialogAction(label: 'OK', isDefault: true, enabled: false),
          ],
        ),
      ),
      act: tapTrigger,
    ),
  ]);
}
