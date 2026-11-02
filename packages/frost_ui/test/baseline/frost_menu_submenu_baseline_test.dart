import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';

import 'baseline.dart';
import 'nav_overlay_support.dart';

void _noop() {}

const _children = <FrostMenuEntry>[FrostMenuAction('Mail', onSelected: _noop), FrostMenuAction('Message', onSelected: _noop)];

// Opens the menu, then hovers the submenu row so the nested panel opens.
BaselineAct _openSubmenu(String label) => (tester, subject) async {
  await tapTrigger(tester, subject);
  await tester.pumpAndSettle();
  await baselineHover(tester, find.text(label).first);
  await tester.pump(const Duration(milliseconds: 600));
};

void main() {
  baselineGroup('FrostMenuSubmenu', [
    BaselineCase(
      'FrostMenuSubmenu/required#open',
      (_) => menuAnchor(const [FrostMenuSubmenu('Send to', entries: _children)]),
      act: tapTrigger,
      envs: [...BaselineEnv.themes, BaselineEnv.touch, BaselineEnv.largeText],
    ),
    BaselineCase(
      'FrostMenuSubmenu/required#open+sibling',
      (_) => menuAnchor(const [FrostMenuAction('Other', onSelected: _noop), FrostMenuSubmenu('Send to', entries: _children)]),
      act: tapTrigger,
    ),
    BaselineCase('FrostMenuSubmenu/required#hover', (_) => menuAnchor(const [FrostMenuSubmenu('Send to', entries: _children)]), act: _openSubmenu('Send to')),
    BaselineCase(
      'FrostMenuSubmenu/icon#open',
      (_) => menuAnchor(const [FrostMenuSubmenu('Send to', leading: FrostGlyph.icon(baselineIcon), entries: _children)]),
      act: tapTrigger,
      envs: [...BaselineEnv.themes, BaselineEnv.touch, BaselineEnv.largeText],
    ),
    BaselineCase(
      'FrostMenuSubmenu/icon#open+sibling',
      (_) => menuAnchor(const [
        FrostMenuAction('Other', onSelected: _noop),
        FrostMenuSubmenu('Send to', leading: FrostGlyph.icon(baselineIcon), entries: _children),
      ]),
      act: tapTrigger,
    ),
    BaselineCase(
      'FrostMenuSubmenu/icon#hover',
      (_) => menuAnchor(const [FrostMenuSubmenu('Send to', leading: FrostGlyph.icon(baselineIcon), entries: _children)]),
      act: _openSubmenu('Send to'),
    ),
    BaselineCase('FrostMenuSubmenu/entries=empty#open', (_) => menuAnchor(const [FrostMenuSubmenu('Send to', entries: [])]), act: tapTrigger),
    // New API: a person's avatar in the icon column.
    BaselineCase(
      'FrostMenuSubmenu/leading=person-avatar#open',
      (_) => menuAnchor(const [
        FrostMenuSubmenu(
          'Send to',
          leading: FrostGlyph.avatar(FrostAvatar.person(name: 'zhang')),
          entries: _children,
        ),
      ]),
      act: tapTrigger,
      envs: BaselineEnv.themes,
    ),
    BaselineCase(
      'FrostMenuSubmenu/leading=person-avatar#hover',
      (_) => menuAnchor(const [
        FrostMenuSubmenu(
          'Send to',
          leading: FrostGlyph.avatar(FrostAvatar.person(name: 'zhang')),
          entries: _children,
        ),
      ]),
      act: _openSubmenu('Send to'),
    ),
  ]);
}
