import 'package:flutter/widgets.dart';
import 'package:frost_ui/frost_ui.dart';

import 'baseline.dart';

const _edgeToEdge = SizedBox(
  width: 320,
  height: 200,
  child: ColoredBox(
    color: Color(0xFF5577AA),
    child: Center(child: FrostText('Edge-to-edge media', tone: FrostTextTone.primary)),
  ),
);

Widget _required(BuildContext context) => const FrostMediaSystemChrome(child: _edgeToEdge);

// The route's system-bar protection is painted by the host above its Navigator.
Widget _inHost(BuildContext context) => const FrostMediaSystemChromeHost(child: FrostMediaSystemChrome(child: _edgeToEdge));

void main() {
  baselineGroup('FrostMediaSystemChrome', [
    const BaselineCase('FrostMediaSystemChrome/required', _required, envs: BaselineEnv.themes),
    const BaselineCase('FrostMediaSystemChrome/required+inHost', _inHost, envs: BaselineEnv.themes),
  ]);
}
