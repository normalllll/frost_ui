import 'package:flutter/widgets.dart';
import 'package:frost_ui/frost_ui.dart';

import 'baseline.dart';

void main() {
  baselineGroup('FrostIcon', [
    const BaselineCase('FrostIcon/required', _required, envs: BaselineEnv.all),
    const BaselineCase('FrostIcon/size', _sized, envs: [BaselineEnv.standard, BaselineEnv.largeText]),
    const BaselineCase('FrostIcon/color', _colored, envs: BaselineEnv.themes),
    const BaselineCase('FrostIcon/semanticLabel', _labelled),
    const BaselineCase('FrostIcon/required+iconTheme', _themed, envs: BaselineEnv.themes),
  ]);
}

Widget _required(BuildContext context) => const FrostIcon(baselineIcon);
Widget _sized(BuildContext context) => const FrostIcon(baselineIcon, size: 32);
Widget _colored(BuildContext context) => const FrostIcon(baselineIcon, color: Color(0xFFD93025));
Widget _labelled(BuildContext context) => const FrostIcon(baselineIcon, semanticLabel: 'Add');
Widget _themed(BuildContext context) => const IconTheme(
  data: IconThemeData(size: 28, color: Color(0xFF3366CC)),
  child: FrostIcon(baselineIcon),
);
