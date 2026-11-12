import 'package:flutter/material.dart';
import 'package:frost_ui/frost_ui.dart';

import 'baseline.dart';

Widget _item(BuildContext context, int index) => SizedBox(height: 48, child: FrostText('Item $index', tone: FrostTextTone.primary));

Widget _pages(BuildContext context) => FrostDefaultTabController(
  length: 2,
  child: FrostTabView(
    children: [
      FrostKeepAlive(child: Column(children: [for (var i = 0; i < 6; i++) _item(context, i)])),
      const FrostKeepAlive(
        child: Center(child: FrostText('Second page', tone: FrostTextTone.primary)),
      ),
    ],
  ),
);

void main() {
  baselineGroup('FrostKeepAlive', [
    BaselineCase('FrostKeepAlive/required', (context) => _pages(context), height: 400, envs: [BaselineEnv.standard, BaselineEnv.narrow]),
  ]);
}
