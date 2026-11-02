import 'package:flutter/widgets.dart';
import 'package:frost_ui/frost_ui.dart';

import 'baseline.dart';
import 'nav_overlay_support.dart';

Widget _open({bool barrierDismissible = true, List<FrostSheetDetent>? sheetDetents}) => launcher((context) {
  Widget builder(BuildContext context) => FrostDialog(title: 'Edit item', content: body(), actions: dialogActions);
  return sheetDetents == null
      ? showFrostAdaptiveDialog<Object?>(context: context, builder: builder, barrierDismissible: barrierDismissible)
      : showFrostAdaptiveDialog<Object?>(context: context, builder: builder, barrierDismissible: barrierDismissible, sheetDetents: sheetDetents);
});

void main() {
  // Wide windows open a dialog, a 360-wide window opens a sheet.
  baselineGroup('showFrostAdaptiveDialog', [
    BaselineCase('showFrostAdaptiveDialog/required#open', (_) => _open(), act: tapTrigger, envs: BaselineEnv.themes),
    BaselineCase('showFrostAdaptiveDialog/required#open-phone', (_) => _open(), act: onPhone(tapTrigger), envs: [narrowTouch]),
    BaselineCase('showFrostAdaptiveDialog/barrierDismissible=false#open', (_) => _open(barrierDismissible: false), act: tapTrigger),
    BaselineCase(
      'showFrostAdaptiveDialog/barrierDismissible=false#open-phone',
      (_) => _open(barrierDismissible: false),
      act: onPhone(tapTrigger),
      envs: [narrowTouch],
    ),
    BaselineCase(
      'showFrostAdaptiveDialog/sheetDetents=large#open-phone',
      (_) => _open(sheetDetents: const [FrostSheetDetent.large]),
      act: onPhone(tapTrigger),
      envs: [narrowTouch],
    ),
    BaselineCase(
      'showFrostAdaptiveDialog/sheetDetents=medium#open-phone',
      (_) => _open(sheetDetents: const [FrostSheetDetent.medium]),
      act: onPhone(tapTrigger),
      envs: [narrowTouch],
    ),
  ]);
}
