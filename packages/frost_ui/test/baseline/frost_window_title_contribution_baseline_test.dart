import 'package:flutter/widgets.dart';
import 'package:frost_ui/frost_ui.dart';

import 'baseline.dart';
import 'nav_overlay_support.dart';

const _home = FrostPageTitle(id: 1, title: 'Home');

void main() {
  baselineGroup('FrostWindowTitleContribution', [
    BaselineCase(
      'FrostWindowTitleContribution/required',
      (_) => RegistryHost(
        builder: (_) => const FrostWindowTitleContribution(path: '/', page: _home, child: Text('Content')),
      ),
      envs: BaselineEnv.all,
    ),
    BaselineCase('FrostWindowTitleContribution/required#noScope', (_) => const FrostWindowTitleContribution(path: '/', page: _home, child: Text('Content'))),
    BaselineCase(
      'FrostWindowTitleContribution/page=null',
      (_) => RegistryHost(
        builder: (_) => const FrostWindowTitleContribution(path: '/', page: null, child: Text('Content')),
      ),
    ),
    BaselineCase(
      'FrostWindowTitleContribution/path',
      (_) => RegistryHost(
        builder: (_) => const FrostWindowTitleContribution(path: '/other', page: _home, child: Text('Content')),
      ),
    ),
    BaselineCase(
      'FrostWindowTitleContribution/page=kind+imageUrl',
      (_) => RegistryHost(
        builder: (_) => const FrostWindowTitleContribution(
          path: '/',
          page: FrostPageTitle(id: 3, title: 'Detail', kind: 'detail', imageUrl: 'https://example.com/a.png'),
          child: Text('Content'),
        ),
      ),
    ),
  ]);
}
