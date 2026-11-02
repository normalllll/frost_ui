import 'package:flutter/widgets.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/layout/pinned_chrome.dart' show FrostPinnedChromeMaterial;

import 'baseline.dart';

Widget _probe(BuildContext context) => SizedBox(
  height: 64,
  child: Stack(
    children: [
      const Positioned.fill(child: FrostPinnedChromeGlass(opacity: 1)),
      FrostText('enabled=${FrostPinnedChromeMaterial.enabledOf(context)}', tone: FrostTextTone.primary),
    ],
  ),
);

Widget _required(BuildContext context) => const FrostPinnedChromeMaterial(enabled: true, child: Builder(builder: _probe));
Widget _disabled(BuildContext context) => const FrostPinnedChromeMaterial(enabled: false, child: Builder(builder: _probe));

void main() {
  baselineGroup('FrostPinnedChromeMaterial', [
    const BaselineCase('FrostPinnedChromeMaterial/required', _required),
    const BaselineCase('FrostPinnedChromeMaterial/enabled=false', _disabled, envs: BaselineEnv.themes),
  ]);
}
