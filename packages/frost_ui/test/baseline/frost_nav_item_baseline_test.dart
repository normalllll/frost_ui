import 'package:flutter/widgets.dart';
import 'package:frost_ui/frost_ui.dart';

import 'baseline.dart';

void _noop() {}

// A sidebar-wide slot, so the expanded forms have their label room.
Widget _item({bool selected = false, VoidCallback? onTap = _noop, double? progress, double? labelOpacity, double width = 176}) => Padding(
  padding: const EdgeInsets.all(8),
  child: SizedBox(
    width: width,
    child: FrostNavItem(label: 'Library', icon: baselineIcon, selected: selected, onTap: onTap, progress: progress ?? 0, labelOpacity: labelOpacity ?? 1),
  ),
);

void main() {
  baselineGroup('FrostNavItem', [
    BaselineCase('FrostNavItem/required', (_) => _item(), envs: BaselineEnv.all),
    BaselineCase('FrostNavItem/required#hover', (_) => _item(), act: baselineHover),
    BaselineCase('FrostNavItem/required#press', (_) => _item(), act: baselinePress),
    BaselineCase('FrostNavItem/required#focus', (_) => _item(), act: baselineFocus),
    BaselineCase('FrostNavItem/selected', (_) => _item(selected: true), envs: BaselineEnv.themes),
    BaselineCase('FrostNavItem/onTap=null', (_) => _item(onTap: null)),
    for (final progress in [0.5, 1.0]) ...[
      BaselineCase('FrostNavItem/progress=$progress', (_) => _item(progress: progress), envs: progress == 1.0 ? BaselineEnv.all : BaselineEnv.themes),
      BaselineCase('FrostNavItem/progress=$progress+selected', (_) => _item(progress: progress, selected: true)),
    ],
    BaselineCase('FrostNavItem/progress=1#hover', (_) => _item(progress: 1), act: baselineHover),
    BaselineCase('FrostNavItem/progress=1#press', (_) => _item(progress: 1), act: baselinePress),
    BaselineCase('FrostNavItem/labelOpacity', (_) => _item(progress: 1, labelOpacity: .5)),
    BaselineCase('FrostNavItem/progress=1+label=narrow', (_) => _item(progress: 1, width: 80)),
  ]);
}
