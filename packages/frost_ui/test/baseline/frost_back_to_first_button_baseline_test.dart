import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/navigation/back_to_first_button.dart' show FrostBackToFirstButton;

import 'baseline.dart';

void _noop() {}

final ValueListenable<({int index, int sequence})> _reselection = ValueNotifier((index: 0, sequence: 0));

Widget _scoped({
  bool ownsBackControl = false,
  int routeDepth = 2,
  FrostShellBackToFirst? backToFirst = const FrostShellBackToFirst(label: 'Back to first', icon: baselineIcon, onPressed: _noop),
}) => FrostShellNavigationScope(
  ownsBackControl: ownsBackControl,
  canGoBack: true,
  goBack: _noop,
  primaryReselection: _reselection,
  routeDepth: routeDepth,
  backToFirst: backToFirst,
  child: const FrostBackToFirstButton(),
);

void main() {
  baselineGroup('FrostBackToFirstButton', [
    // Outside a shell scope the button draws nothing.
    BaselineCase('FrostBackToFirstButton/required', (_) => const FrostBackToFirstButton()),
    BaselineCase('FrostBackToFirstButton/required+scope', (_) => _scoped(), envs: BaselineEnv.all),
    BaselineCase('FrostBackToFirstButton/required+scope#hover', (_) => _scoped(), act: baselineHover),
    BaselineCase('FrostBackToFirstButton/required+scope#press', (_) => _scoped(), act: baselinePress),
    BaselineCase('FrostBackToFirstButton/required+scope#focus', (_) => _scoped(), act: baselineFocus),
    BaselineCase('FrostBackToFirstButton/scope=ownsBackControl', (_) => _scoped(ownsBackControl: true)),
    BaselineCase('FrostBackToFirstButton/scope=routeDepth1', (_) => _scoped(routeDepth: 1)),
    // Formerly goToFirst: null; the scope now has no Back to first at all.
    BaselineCase('FrostBackToFirstButton/scope=goToFirst-null', (_) => _scoped(backToFirst: null)),
  ]);
}
