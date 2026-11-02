import 'package:flutter/widgets.dart';
import 'package:frost_ui/frost_ui.dart';

import 'baseline.dart';
import 'nav_overlay_support.dart';

void main() {
  baselineGroup('FrostWindowTitleScope', [
    BaselineCase('FrostWindowTitleScope/required', (_) => RegistryHost(builder: (_) => const Text('Content')), envs: BaselineEnv.all),
    BaselineCase(
      'FrostWindowTitleScope/registry=shared',
      (_) => RegistryHost(
        builder: (_) => const Column(
          children: [
            FrostWindowTitleContribution(
              path: '/',
              page: FrostPageTitle(id: 1, title: 'Home'),
              child: Text('One'),
            ),
            FrostWindowTitleContribution(
              path: '/other',
              page: FrostPageTitle(id: 2, title: 'Other'),
              child: Text('Two'),
            ),
          ],
        ),
      ),
    ),
  ]);
}
