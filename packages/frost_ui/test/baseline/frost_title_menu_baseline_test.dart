import 'package:frost_ui/frost_ui.dart';

import 'baseline.dart';
import 'nav_overlay_support.dart';

void _noop() {}

const _entries = <FrostMenuEntry>[
  FrostMenuAction('Library', leading: FrostGlyph.icon(baselineIcon), checked: true, onSelected: _noop),
  FrostMenuAction('Favorites', leading: FrostGlyph.icon(baselineIcon), checked: false, onSelected: _noop),
];

void main() {
  baselineGroup('FrostTitleMenu', [
    BaselineCase(
      'FrostTitleMenu/required',
      (_) => const FrostTitleMenu(title: 'Library', entries: _entries),
      envs: BaselineEnv.all,
    ),
    BaselineCase(
      'FrostTitleMenu/required#open',
      (_) => const FrostTitleMenu(title: 'Library', entries: _entries),
      act: tapButton,
      envs: BaselineEnv.themes,
    ),
    BaselineCase(
      'FrostTitleMenu/required#hover',
      (_) => const FrostTitleMenu(title: 'Library', entries: _entries),
      act: baselineHover,
    ),
    BaselineCase(
      'FrostTitleMenu/required#press',
      (_) => const FrostTitleMenu(title: 'Library', entries: _entries),
      act: baselinePress,
    ),
    BaselineCase(
      'FrostTitleMenu/required#focus',
      (_) => const FrostTitleMenu(title: 'Library', entries: _entries),
      act: baselineFocus,
    ),
    BaselineCase('FrostTitleMenu/entries=empty', (_) => const FrostTitleMenu(title: 'Library', entries: [])),
    BaselineCase(
      'FrostTitleMenu/title=long',
      (_) => const FrostTitleMenu(title: 'A very long title that has to be truncated in a narrow row', entries: _entries),
      envs: [BaselineEnv.narrow],
    ),
  ]);
}
