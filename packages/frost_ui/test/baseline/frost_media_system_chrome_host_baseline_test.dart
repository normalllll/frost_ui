import 'package:flutter/widgets.dart';
import 'package:frost_ui/frost_ui.dart';

import 'baseline.dart';

const _page = SizedBox(
  width: 320,
  height: 200,
  child: ColoredBox(
    color: Color(0xFF5577AA),
    child: Center(child: FrostText('Routed content', tone: FrostTextTone.primary)),
  ),
);

Widget _required(BuildContext context) => const FrostMediaSystemChromeHost(child: _page);
Widget _withEdgeToEdgeRoute(BuildContext context) => const FrostMediaSystemChromeHost(child: FrostMediaSystemChrome(child: _page));

void main() {
  baselineGroup('FrostMediaSystemChromeHost', [
    const BaselineCase('FrostMediaSystemChromeHost/required', _required, envs: BaselineEnv.themes),
    const BaselineCase('FrostMediaSystemChromeHost/required+edgeToEdgeRoute', _withEdgeToEdgeRoute, envs: BaselineEnv.themes),
  ]);
}
