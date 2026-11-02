import 'package:flutter/widgets.dart';
import 'package:frost_ui/frost_ui.dart';

import 'baseline.dart';
import 'nav_overlay_support.dart';

// FrostDialog lives in a modal route, so every case opens it from a button.
Widget _dialog(FrostDialog Function() build) => launcher((context) => showFrostDialog<Object?>(context: context, builder: (_) => build()));

void main() {
  baselineGroup('FrostDialog', [
    BaselineCase(
      'FrostDialog/required#open',
      (_) => _dialog(() => FrostDialog(title: 'Edit item', content: body())),
      act: tapTrigger,
      envs: [...BaselineEnv.themes, BaselineEnv.largeText, BaselineEnv.touch],
    ),
    BaselineCase(
      'FrostDialog/required#open-sheet',
      (_) => _dialog(() => FrostDialog(title: 'Edit item', content: body())),
      act: onPhone(tapTrigger),
      envs: [narrowTouch],
    ),
    BaselineCase(
      'FrostDialog/actions#open',
      (_) => _dialog(() => FrostDialog(title: 'Edit item', content: body(), actions: dialogActions)),
      act: tapTrigger,
      envs: BaselineEnv.themes,
    ),
    BaselineCase(
      'FrostDialog/actions#open-sheet',
      (_) => _dialog(() => FrostDialog(title: 'Edit item', content: body(), actions: dialogActions)),
      act: onPhone(tapTrigger),
      envs: [narrowTouch],
    ),
    BaselineCase(
      'FrostDialog/actions=roles#open',
      (_) => _dialog(
        () => FrostDialog(
          title: 'Remove item',
          content: body(),
          actions: const [
            FrostDialogAction(label: 'Cancel', role: FrostButtonRole.cancel),
            FrostDialogAction(label: 'Archive'),
            FrostDialogAction(label: 'Remove', role: FrostButtonRole.destructive, isDefault: true),
          ],
        ),
      ),
      act: tapTrigger,
    ),
    BaselineCase(
      'FrostDialog/actions=disabled#open',
      (_) => _dialog(
        () => FrostDialog(
          title: 'Edit item',
          content: body(),
          actions: const [
            FrostDialogAction(label: 'Cancel', role: FrostButtonRole.cancel),
            FrostDialogAction(label: 'Save', isDefault: true, enabled: false),
          ],
        ),
      ),
      act: tapTrigger,
    ),
    BaselineCase(
      'FrostDialog/size=wide#open',
      (_) => _dialog(() => FrostDialog(title: 'Edit item', content: body(), actions: dialogActions, size: FrostDialogSize.wide)),
      act: tapTrigger,
    ),
    BaselineCase(
      'FrostDialog/showsCloseButton#open',
      (_) => _dialog(() => FrostDialog(title: 'Edit item', content: body(), showsCloseButton: true)),
      act: tapTrigger,
    ),
    BaselineCase(
      'FrostDialog/scrollable=false#open',
      (_) => _dialog(
        () => FrostDialog(
          title: 'Edit item',
          content: SizedBox(height: 120, child: ListView(children: const [Text('One'), Text('Two')])),
          scrollable: false,
        ),
      ),
      act: tapTrigger,
    ),
    BaselineCase(
      'FrostDialog/content=long#open',
      (_) => _dialog(
        () => FrostDialog(
          title: 'Edit item',
          content: Column(children: [for (var i = 0; i < 40; i++) Text('Line $i')]),
          actions: dialogActions,
        ),
      ),
      act: tapTrigger,
    ),
    BaselineCase(
      'FrostDialog/leadingAction#open',
      (_) => _dialog(
        () => FrostDialog(
          title: 'Edit item',
          content: body(),
          actions: dialogActions,
          leadingAction: const FrostDialogAction(label: 'Delete', role: FrostButtonRole.destructive),
        ),
      ),
      act: tapTrigger,
      envs: BaselineEnv.themes,
    ),
    BaselineCase(
      'FrostDialog/leadingAction#open-sheet',
      (_) => _dialog(
        () => FrostDialog(
          title: 'Edit item',
          content: body(),
          actions: dialogActions,
          leadingAction: const FrostDialogAction(label: 'Delete', role: FrostButtonRole.destructive),
        ),
      ),
      act: onPhone(tapTrigger),
      envs: [narrowTouch],
    ),
  ]);
}
