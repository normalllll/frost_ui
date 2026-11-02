import 'package:flutter/widgets.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/layout/content_viewport.dart' show FrostContentColumnBudget;

import 'baseline.dart';

// Reports the content width the viewport hands to its child.
Widget _probe(BuildContext context) =>
    FrostText('width=${MediaQuery.sizeOf(context).width} reserve=${FrostContentColumnBudget.of(context)}', tone: FrostTextTone.primary);

Widget _required(BuildContext context) => const FrostContentViewport(child: Builder(builder: _probe));
Widget _navigationReserve(BuildContext context) => const FrostContentViewport(navigationReserve: 236, child: Builder(builder: _probe));
Widget _nested(BuildContext context) => const FrostContentColumnBudget(
  reservedWidth: 100,
  child: FrostContentViewport(child: Builder(builder: _probe)),
);

void main() {
  baselineGroup('FrostContentViewport', [
    const BaselineCase('FrostContentViewport/required', _required, envs: [BaselineEnv.standard, BaselineEnv.narrow]),
    const BaselineCase('FrostContentViewport/navigationReserve', _navigationReserve),
    const BaselineCase('FrostContentViewport/required+inheritedBudget', _nested),
  ]);
}
