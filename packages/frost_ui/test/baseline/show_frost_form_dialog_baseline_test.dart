import 'package:flutter/widgets.dart';
import 'package:frost_ui/frost_ui.dart';

import 'baseline.dart';
import 'nav_overlay_support.dart';

Future<bool> _submit() async => true;

const _sections = <Widget>[Text('Name field'), Text('Notes field')];

Widget _open({
  String? cancelLabel,
  String? errorSummary,
  FrostDialogSize size = FrostDialogSize.regular,
  FrostFormDialogController? controller,
  FrostDialogAction<bool>? leadingAction,
  bool showsCloseButton = false,
}) => launcher(
  (context) => showFrostFormDialog(
    context: context,
    title: 'New item',
    sections: _sections,
    onSubmit: _submit,
    submitLabel: 'Create',
    cancelLabel: cancelLabel,
    errorSummary: errorSummary,
    size: size,
    controller: controller,
    leadingAction: leadingAction,
    showsCloseButton: showsCloseButton,
  ),
);

void main() {
  baselineGroup('showFrostFormDialog', [
    BaselineCase('showFrostFormDialog/required#open', (_) => _open(), act: tapTrigger, envs: BaselineEnv.themes),
    BaselineCase('showFrostFormDialog/required#open-phone', (_) => _open(), act: onPhone(tapTrigger), envs: [narrowTouch]),
    BaselineCase('showFrostFormDialog/cancelLabel#open', (_) => _open(cancelLabel: 'Back'), act: tapTrigger),
    BaselineCase('showFrostFormDialog/errorSummary#open', (_) => _open(errorSummary: 'Fix the highlighted fields.'), act: tapTrigger),
    BaselineCase('showFrostFormDialog/size=wide#open', (_) => _open(size: FrostDialogSize.wide), act: tapTrigger),
    BaselineCase(
      'showFrostFormDialog/controller#open',
      (_) => _open(controller: FrostFormDialogController(errorSummary: 'Controller summary')),
      act: tapTrigger,
    ),
    BaselineCase(
      'showFrostFormDialog/leadingAction#open',
      (_) => _open(
        leadingAction: const FrostDialogAction<bool>(label: 'Delete', role: FrostButtonRole.destructive),
      ),
      act: tapTrigger,
    ),
    BaselineCase(
      'showFrostFormDialog/leadingAction#open-phone',
      (_) => _open(
        leadingAction: const FrostDialogAction<bool>(label: 'Delete', role: FrostButtonRole.destructive),
      ),
      act: onPhone(tapTrigger),
      envs: [narrowTouch],
    ),
    BaselineCase('showFrostFormDialog/showsCloseButton#open', (_) => _open(showsCloseButton: true), act: tapTrigger),
  ]);
}
