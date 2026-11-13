import 'package:frost_ui/frost_ui.dart';
import 'package:material_ui/material_ui.dart';

import 'baseline.dart';
import 'nav_overlay_support.dart';

Widget _open({bool barrierDismissible = true, Color? barrierColor, bool useRootNavigator = true}) => launcher(
  (context) => showFrostDialog<Object?>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierColor: barrierColor,
    useRootNavigator: useRootNavigator,
    builder: (_) => FrostDialog(title: 'Edit item', content: body(), actions: dialogActions),
  ),
);

void main() {
  baselineGroup('showFrostDialog', [
    BaselineCase('showFrostDialog/required#open', (_) => _open(), act: tapTrigger, envs: BaselineEnv.themes),
    BaselineCase('showFrostDialog/barrierDismissible=false#open', (_) => _open(barrierDismissible: false), act: tapTrigger),
    BaselineCase('showFrostDialog/barrierColor#open', (_) => _open(barrierColor: const Color(0x80FF0000)), act: tapTrigger),
    BaselineCase('showFrostDialog/useRootNavigator=false#open', (_) => _open(useRootNavigator: false), act: tapTrigger),
  ]);
}
