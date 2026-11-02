import 'package:flutter/widgets.dart';
import 'package:frost_ui/frost_ui.dart';

import 'baseline.dart';
import 'nav_overlay_support.dart';

Widget _popover({String? title, double? maxWidth, Widget? content}) => FrostPopover(
  title: title,
  maxWidth: maxWidth,
  builder: (context, focus, toggle) => trigger(focus, toggle),
  contentBuilder: (context, close) => content ?? body(),
);

void main() {
  baselineGroup('FrostPopover', [
    BaselineCase('FrostPopover/required', (_) => _popover(), envs: BaselineEnv.all),
    BaselineCase('FrostPopover/required#open', (_) => _popover(), act: tapTrigger, envs: [...BaselineEnv.themes, BaselineEnv.touch, BaselineEnv.largeText]),
    BaselineCase('FrostPopover/required#focus', (_) => _popover(), act: baselineFocus),
    BaselineCase(
      'FrostPopover/title#open',
      (_) => _popover(title: 'Details'),
      act: tapTrigger,
      envs: BaselineEnv.themes,
    ),
    BaselineCase('FrostPopover/maxWidth#open', (_) => _popover(maxWidth: 300, content: const SizedBox(width: 500, height: 40)), act: tapTrigger),
    BaselineCase('FrostPopover/maxWidth=wide#open', (_) => _popover(maxWidth: 560, content: const SizedBox(width: 520, height: 40)), act: tapTrigger),
    BaselineCase('FrostPopover/contentBuilder=long#open', (_) => _popover(content: Text(List.filled(40, 'Long').join(' '))), act: tapTrigger),
    // A narrow window presents the content in a sheet.
    BaselineCase('FrostPopover/required#open-sheet', (_) => _popover(), act: onPhone(tapTrigger), envs: [narrowTouch]),
    BaselineCase(
      'FrostPopover/title#open-sheet',
      (_) => _popover(title: 'Details'),
      act: onPhone(tapTrigger),
      envs: [narrowTouch],
    ),
  ]);
}
