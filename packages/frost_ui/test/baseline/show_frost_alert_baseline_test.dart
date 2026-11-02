import 'package:flutter/widgets.dart';
import 'package:frost_ui/frost_ui.dart';

import 'baseline.dart';
import 'nav_overlay_support.dart';

Widget _open({String? message, bool barrierDismissible = true, List<FrostDialogAction<Object?>> actions = dialogActions}) => launcher(
  (context) => showFrostAlert<Object?>(context: context, title: 'Discard changes?', message: message, actions: actions, barrierDismissible: barrierDismissible),
);

void main() {
  baselineGroup('showFrostAlert', [
    BaselineCase('showFrostAlert/required#open', (_) => _open(), act: tapTrigger, envs: BaselineEnv.themes),
    BaselineCase('showFrostAlert/message#open', (_) => _open(message: 'This cannot be undone.'), act: tapTrigger),
    BaselineCase('showFrostAlert/barrierDismissible=false#open', (_) => _open(barrierDismissible: false), act: tapTrigger),
    BaselineCase(
      'showFrostAlert/required#open-phone',
      (_) => _open(message: 'This cannot be undone.'),
      act: onPhone(tapTrigger),
      envs: [narrowTouch],
    ),
  ]);
}
