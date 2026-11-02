import 'package:frost_ui/frost_ui.dart';

import 'baseline.dart';
import 'nav_overlay_support.dart';

void _noop() {}

const _entries = <FrostMenuEntry>[FrostMenuAction('Copy', onSelected: _noop), FrostMenuAction('Paste', onSelected: _noop)];

void main() {
  baselineGroup('FrostMenuAnchor', [
    BaselineCase('FrostMenuAnchor/required', (_) => menuAnchor(_entries), envs: BaselineEnv.all),
    BaselineCase('FrostMenuAnchor/required#open', (_) => menuAnchor(_entries), act: tapTrigger, envs: BaselineEnv.themes),
    BaselineCase('FrostMenuAnchor/required#focus', (_) => menuAnchor(_entries), act: baselineFocus),
    BaselineCase('FrostMenuAnchor/entries=empty', (_) => menuAnchor(const []), act: tapTrigger),
    BaselineCase(
      'FrostMenuAnchor/entries=mixed#open',
      (_) => menuAnchor(_mixed),
      act: tapTrigger,
      envs: [BaselineEnv.standard, BaselineEnv.touch, BaselineEnv.narrow],
    ),
  ]);
}

const _mixed = <FrostMenuEntry>[
  FrostMenuAction('Open', leading: FrostGlyph.icon(baselineIcon), onSelected: _noop),
  FrostMenuSection(
    header: 'Share',
    entries: [
      FrostMenuAction('Copy link', onSelected: _noop),
      FrostMenuSubmenu('Send to', entries: [FrostMenuAction('Mail', onSelected: _noop)]),
    ],
  ),
  FrostMenuDivider(),
  FrostMenuAction('Delete', destructive: true, onSelected: _noop),
];
