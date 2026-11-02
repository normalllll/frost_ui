import 'package:flutter/widgets.dart';
import 'package:frost_ui/frost_ui.dart';

import 'baseline.dart';
import 'nav_overlay_support.dart';

void _noop() {}

const _entries = <FrostMenuEntry>[
  FrostMenuAction('Copy', leading: FrostGlyph.icon(baselineIcon), onSelected: _noop),
  FrostMenuAction('Paste', onSelected: _noop),
];

Widget _anchor(List<FrostMenuEntry> entries) => FrostAdaptiveMenuAnchor(entries: entries, builder: (context, focus, toggle) => trigger(focus, toggle));

void main() {
  baselineGroup('FrostAdaptiveMenuAnchor', [
    BaselineCase('FrostAdaptiveMenuAnchor/required', (_) => _anchor(_entries), envs: BaselineEnv.all),
    BaselineCase('FrostAdaptiveMenuAnchor/required#open', (_) => _anchor(_entries), act: tapTrigger, envs: BaselineEnv.themes),
    BaselineCase('FrostAdaptiveMenuAnchor/required#focus', (_) => _anchor(_entries), act: baselineFocus),
    // Touch in a narrow window uses the fitted sheet form.
    BaselineCase('FrostAdaptiveMenuAnchor/required#open-sheet', (_) => _anchor(_entries), act: onPhone(tapTrigger), envs: [narrowTouch]),
    BaselineCase('FrostAdaptiveMenuAnchor/entries=empty#open', (_) => _anchor(const []), act: tapTrigger),
  ]);
}
