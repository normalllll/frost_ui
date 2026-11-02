import 'package:flutter/widgets.dart';
import 'package:frost_ui/frost_ui.dart';

import 'baseline.dart';
import 'nav_overlay_support.dart';

Widget _open({String? message, String? cancelLabel, bool destructive = true}) => launcher(
  (context) =>
      showFrostConfirm(context: context, title: 'Delete item?', message: message, confirmLabel: 'Delete', cancelLabel: cancelLabel, destructive: destructive),
);

void main() {
  baselineGroup('showFrostConfirm', [
    BaselineCase('showFrostConfirm/required#open', (_) => _open(), act: tapTrigger, envs: BaselineEnv.themes),
    BaselineCase('showFrostConfirm/message#open', (_) => _open(message: 'This cannot be undone.'), act: tapTrigger),
    BaselineCase('showFrostConfirm/cancelLabel#open', (_) => _open(cancelLabel: 'Keep'), act: tapTrigger),
    BaselineCase('showFrostConfirm/destructive=false#open', (_) => _open(destructive: false), act: tapTrigger),
    // A compact window presents the confirmation in a sheet.
    BaselineCase('showFrostConfirm/required#open-sheet', (_) => _open(), act: onPhone(tapTrigger), envs: [narrowTouch]),
    BaselineCase(
      'showFrostConfirm/message#open-sheet',
      (_) => _open(message: 'This cannot be undone.'),
      act: onPhone(tapTrigger),
      envs: [narrowTouch],
    ),
    BaselineCase('showFrostConfirm/destructive=false#open-sheet', (_) => _open(destructive: false), act: onPhone(tapTrigger), envs: [narrowTouch]),
  ]);
}
