import 'package:frost_ui/frost_ui.dart';

import 'baseline.dart';
import 'nav_overlay_support.dart';

void _noop() {}

const _entries = <FrostMenuEntry>[
  FrostMenuAction('Copy', leading: FrostGlyph.icon(baselineIcon), onSelected: _noop),
  FrostMenuAction('Paste', onSelected: _noop),
];

void main() {
  baselineGroup('FrostToolbarMenuButton', [
    BaselineCase(
      'FrostToolbarMenuButton/required',
      (_) => const FrostToolbarMenuButton(label: 'Sort', entries: _entries),
      envs: BaselineEnv.all,
    ),
    BaselineCase(
      'FrostToolbarMenuButton/required#open',
      (_) => const FrostToolbarMenuButton(label: 'Sort', entries: _entries),
      act: tapButton,
      envs: BaselineEnv.themes,
    ),
    BaselineCase(
      'FrostToolbarMenuButton/required#hover',
      (_) => const FrostToolbarMenuButton(label: 'Sort', entries: _entries),
      act: baselineHover,
    ),
    BaselineCase(
      'FrostToolbarMenuButton/required#press',
      (_) => const FrostToolbarMenuButton(label: 'Sort', entries: _entries),
      act: baselinePress,
    ),
    BaselineCase(
      'FrostToolbarMenuButton/required#focus',
      (_) => const FrostToolbarMenuButton(label: 'Sort', entries: _entries),
      act: baselineFocus,
    ),
    BaselineCase('FrostToolbarMenuButton/entries=empty', (_) => const FrostToolbarMenuButton(label: 'Sort', entries: [])),
    BaselineCase(
      'FrostToolbarMenuButton/icon',
      (_) => const FrostToolbarMenuButton(label: 'Sort', entries: _entries, icon: baselineIcon),
      envs: BaselineEnv.themes,
    ),
    BaselineCase(
      'FrostToolbarMenuButton/icon#hover',
      (_) => const FrostToolbarMenuButton(label: 'Sort', entries: _entries, icon: baselineIcon),
      act: baselineHover,
    ),
    BaselineCase('FrostToolbarMenuButton/tooltip', (_) => const FrostToolbarMenuButton(label: 'Sort', entries: _entries, tooltip: 'Sort the list')),
    BaselineCase(
      'FrostToolbarMenuButton/tooltip#hover',
      (_) => const FrostToolbarMenuButton(label: 'Sort', entries: _entries, tooltip: 'Sort the list'),
      act: hoverFor(const Duration(milliseconds: 700)),
    ),
    BaselineCase(
      'FrostToolbarMenuButton/valueLabel',
      (_) => const FrostToolbarMenuButton(label: 'Sort', entries: _entries, valueLabel: 'Name'),
      envs: BaselineEnv.themes,
    ),
    BaselineCase(
      'FrostToolbarMenuButton/showsLabel=false',
      (_) => const FrostToolbarMenuButton(label: 'More', entries: _entries, icon: baselineIcon, showsLabel: false),
      envs: BaselineEnv.all,
    ),
    BaselineCase(
      'FrostToolbarMenuButton/showsLabel=false#open',
      (_) => const FrostToolbarMenuButton(label: 'More', entries: _entries, icon: baselineIcon, showsLabel: false),
      act: tapButton,
    ),
  ]);
}
