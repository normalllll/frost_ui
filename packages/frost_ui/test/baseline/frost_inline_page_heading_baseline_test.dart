import 'package:flutter/widgets.dart';
import 'package:frost_ui/frost_ui.dart';

import 'baseline.dart';
import 'nav_overlay_support.dart';

void _noop() {}

const _action = FrostButton.icon(icon: baselineIcon, label: 'Add', onPressed: _noop);

// [columnWidth]: the heading sits in a content column of that width.
Widget _heading({List<Widget>? actions, double? columnWidth}) {
  final heading = FrostInlinePageHeading(title: 'Settings', actions: actions ?? const []);
  return windowed(columnWidth == null ? heading : FrostColumnPlacement(alignment: FrostColumnAlignment.start, maxWidth: columnWidth, child: heading));
}

void main() {
  baselineGroup('FrostInlinePageHeading', [
    BaselineCase('FrostInlinePageHeading/required', (_) => _heading(), envs: [...BaselineEnv.all, wide, medium]),
    BaselineCase('FrostInlinePageHeading/actions', (_) => _heading(actions: const [_action]), envs: [wide, BaselineEnv.standard, BaselineEnv.narrow]),
    BaselineCase('FrostInlinePageHeading/actions=two', (_) => _heading(actions: const [_action, _action])),
    // The content column the heading aligns with.
    BaselineCase(
      'FrostInlinePageHeading/maxWidth=480',
      (_) => _heading(columnWidth: 480, actions: const [_action]),
      envs: [wide, BaselineEnv.standard, BaselineEnv.narrow],
    ),
    BaselineCase('FrostInlinePageHeading/maxWidth=960', (_) => _heading(columnWidth: 960, actions: const [_action]), envs: [wide, BaselineEnv.standard]),
  ]);
}
