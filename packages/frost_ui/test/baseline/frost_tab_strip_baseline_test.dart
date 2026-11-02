import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/desktop.dart';
import 'package:frost_ui/frost_ui.dart';

import '../support.dart';
import 'baseline.dart';
import 'nav_overlay_support.dart';

void _noop() {}

FrostTabLabel _label(BuildContext context, String tab) => FrostTabLabel(title: tab);
FrostTabLabel _iconLabel(BuildContext context, String tab) => FrostTabLabel(title: tab, leading: const FrostIcon(baselineIcon, size: 16));
FrostTabLabel _longLabel(BuildContext context, String tab) => FrostTabLabel(title: '$tab with a very long title that has to be truncated');

Widget _strip({
  int count = 1,
  int active = 0,
  bool base = false,
  FrostTabLabel Function(BuildContext, String) label = _label,
  VoidCallback? onNewTab,
  double? maxTabWidth,
  double? minTabWidth,
}) => TabsHost(
  count: count,
  active: active,
  base: base,
  builder: (context, controller) => SizedBox(
    height: 40,
    child: FrostTabStrip<String>(
      controller: controller,
      label: label,
      closeTooltip: 'Close tab',
      newTabTooltip: 'New tab',
      newTabIcon: baselineIcon,
      onNewTab: onNewTab,
      maxTabWidth: maxTabWidth ?? 220,
      minTabWidth: minTabWidth ?? 40,
    ),
  ),
);

Finder _tab(String title) => find.text(title);

void main() {
  baselineGroup('FrostTabStrip', [
    BaselineCase('FrostTabStrip/required', (_) => _strip(), envs: BaselineEnv.all),
    BaselineCase('FrostTabStrip/required#hover', (_) => _strip(count: 3), act: (tester, subject) => baselineHover(tester, _tab('Tab 2'))),
    BaselineCase('FrostTabStrip/required#press', (_) => _strip(count: 3), act: (tester, subject) => baselinePress(tester, _tab('Tab 2'))),
    BaselineCase('FrostTabStrip/required#focus', (_) => _strip(count: 3), act: baselineFocus),
    BaselineCase('FrostTabStrip/required#close', (_) => _strip(count: 3), act: (tester, subject) => tester.tap(findFrostTooltip('Close tab').first)),
    BaselineCase('FrostTabStrip/required#activate', (_) => _strip(count: 3), act: (tester, subject) => tester.tap(_tab('Tab 3'))),
    BaselineCase('FrostTabStrip/tabs=3', (_) => _strip(count: 3), envs: [...BaselineEnv.themes, BaselineEnv.narrow, BaselineEnv.touch]),
    BaselineCase('FrostTabStrip/tabs=3+active', (_) => _strip(count: 3, active: 2), envs: BaselineEnv.themes),
    BaselineCase('FrostTabStrip/tabs=12', (_) => _strip(count: 12), envs: [BaselineEnv.standard, BaselineEnv.narrow]),
    BaselineCase('FrostTabStrip/tabs=baseTab', (_) => _strip(count: 2, base: true), envs: [BaselineEnv.standard, BaselineEnv.narrow]),
    BaselineCase('FrostTabStrip/label=icon', (_) => _strip(count: 3, label: _iconLabel), envs: BaselineEnv.themes),
    BaselineCase('FrostTabStrip/label=long', (_) => _strip(count: 3, label: _longLabel), envs: [BaselineEnv.standard, BaselineEnv.narrow]),
    BaselineCase('FrostTabStrip/onNewTab', (_) => _strip(count: 2, onNewTab: _noop), envs: BaselineEnv.all),
    BaselineCase(
      'FrostTabStrip/onNewTab#hover',
      (_) => _strip(count: 2, onNewTab: _noop),
      act: (tester, subject) => baselineHover(tester, findFrostTooltip('New tab').first),
    ),
    BaselineCase('FrostTabStrip/maxTabWidth', (_) => _strip(count: 3, maxTabWidth: 120)),
    BaselineCase('FrostTabStrip/minTabWidth', (_) => _strip(count: 12, minTabWidth: 100), envs: [BaselineEnv.standard, BaselineEnv.narrow]),
    BaselineCase('FrostTabStrip/maxTabWidth+minTabWidth', (_) => _strip(count: 3, maxTabWidth: 160, minTabWidth: 120, onNewTab: _noop)),
  ]);
}
