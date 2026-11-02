import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/navigation/back_to_first_button.dart' show FrostBackToFirstButton;

import 'baseline.dart';
import 'nav_overlay_support.dart';

void _noop() {}

final ValueListenable<({int index, int sequence})> _reselection = ValueNotifier((index: 0, sequence: 0));

const _backToFirst = FrostShellBackToFirst(label: 'Back to first', icon: baselineIcon, onPressed: _noop);

// A page header shows what the scope decides: ordinary Back, or none when the
// shell owns it, and Back to first from the second route level.
Widget _scope({bool ownsBackControl = false, bool canGoBack = true, int routeDepth = 0, FrostShellBackToFirst? backToFirst}) => windowed(
  FrostShellNavigationScope(
    ownsBackControl: ownsBackControl,
    canGoBack: canGoBack,
    goBack: _noop,
    primaryReselection: _reselection,
    routeDepth: routeDepth,
    backToFirst: backToFirst,
    child: const Align(
      alignment: Alignment.topCenter,
      child: FrostPageHeader(title: Text('Title')),
    ),
  ),
);

void main() {
  baselineGroup('FrostShellNavigationScope', [
    BaselineCase('FrostShellNavigationScope/required', (_) => _scope(), envs: [...BaselineEnv.all, wide]),
    BaselineCase('FrostShellNavigationScope/required#hover', (_) => _scope(), act: baselineHover),
    BaselineCase('FrostShellNavigationScope/ownsBackControl', (_) => _scope(ownsBackControl: true), envs: BaselineEnv.themes),
    BaselineCase('FrostShellNavigationScope/canGoBack=false', (_) => _scope(canGoBack: false)),
    BaselineCase('FrostShellNavigationScope/routeDepth=2', (_) => _scope(routeDepth: 2)),
    BaselineCase(
      'FrostShellNavigationScope/goToFirst+backToFirstLabel+backToFirstIcon',
      (_) => _scope(routeDepth: 2, backToFirst: _backToFirst),
      envs: [BaselineEnv.standard, BaselineEnv.narrow, BaselineEnv.touch],
    ),
    BaselineCase(
      'FrostShellNavigationScope/goToFirst+backToFirstLabel+backToFirstIcon#hover',
      (_) => _scope(routeDepth: 2, backToFirst: _backToFirst),
      act: (tester, subject) => baselineHover(tester, find.byType(FrostBackToFirstButton)),
    ),
    BaselineCase('FrostShellNavigationScope/goToFirst+routeDepth=1', (_) => _scope(routeDepth: 1, backToFirst: _backToFirst)),
    BaselineCase('FrostShellNavigationScope/goToFirst+ownsBackControl', (_) => _scope(ownsBackControl: true, routeDepth: 2, backToFirst: _backToFirst)),
  ]);
}
