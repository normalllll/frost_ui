import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';

import 'baseline.dart';
import 'nav_overlay_support.dart';

void _noop() {}
void _select(int _) {}

const _destinations = [FrostNavDestination(icon: baselineIcon, label: 'Home', badge: 3), FrostNavDestination(icon: baselineIcon, label: 'Search')];

// FrostShellDestination must sit below a FrostShell, which provides its bar.
Widget _shell(Widget Function() child) => windowed(
  FrostShell(
    destinations: _destinations,
    selectedIndex: 0,
    atDestinationRoot: true,
    onDestinationSelected: _select,
    canGoBack: false,
    onBack: _noop,
    showsMobileNavigation: true,
    child: child(),
  ),
);

Finder _tab(String label) => find.text(label);

void main() {
  baselineGroup('FrostShellDestination', [
    BaselineCase(
      'FrostShellDestination/required',
      (_) => _shell(() => const FrostShellDestination(child: Center(child: Text('Page')))),
      height: 820,
      envs: pageEnvs,
    ),
    BaselineCase(
      'FrostShellDestination/required#press',
      (_) => _shell(() => const FrostShellDestination(child: Center(child: Text('Page')))),
      height: 820,
      envs: [narrowTouch],
      act: (tester, subject) => baselinePress(tester, _tab('Search')),
    ),
    BaselineCase(
      'FrostShellDestination/required#focus',
      (_) => _shell(() => const FrostShellDestination(child: Center(child: Text('Page')))),
      height: 820,
      envs: [narrowTouch],
      act: baselineFocus,
    ),
    BaselineCase(
      'FrostShellDestination/child=list',
      (_) => _shell(
        () => FrostShellDestination(
          child: ListView(children: [for (var i = 0; i < 30; i++) SizedBox(height: 48, child: Text('Row $i'))]),
        ),
      ),
      height: 820,
      envs: [wide, narrowTouch],
    ),
  ]);
}
