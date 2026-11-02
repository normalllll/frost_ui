import 'package:flutter/widgets.dart';
import 'package:frost_ui/frost_ui.dart';

import 'baseline.dart';
import 'nav_overlay_support.dart';

void _noop() {}

// The action under test sits in an open menu, after an unrelated sibling
// without an icon, so the leading column and the row geometry both show.
Widget _menu(FrostMenuAction action, {bool sibling = true}) => menuAnchor([if (sibling) const FrostMenuAction('Other', onSelected: _noop), action]);

void main() {
  baselineGroup('FrostMenuAction', [
    BaselineCase(
      'FrostMenuAction/required#open',
      (_) => _menu(const FrostMenuAction('Copy'), sibling: false),
      act: tapTrigger,
      envs: [...BaselineEnv.themes, BaselineEnv.touch, BaselineEnv.largeText],
    ),
    BaselineCase('FrostMenuAction/required#open+sibling', (_) => _menu(const FrostMenuAction('Copy')), act: tapTrigger),
    BaselineCase(
      'FrostMenuAction/icon#open',
      (_) => _menu(const FrostMenuAction('Copy', leading: FrostGlyph.icon(baselineIcon), onSelected: _noop), sibling: false),
      act: tapTrigger,
      envs: [...BaselineEnv.themes, BaselineEnv.touch, BaselineEnv.largeText],
    ),
    BaselineCase(
      'FrostMenuAction/icon#open+sibling',
      (_) => _menu(const FrostMenuAction('Copy', leading: FrostGlyph.icon(baselineIcon), onSelected: _noop)),
      act: tapTrigger,
    ),
    BaselineCase('FrostMenuAction/onSelected#open', (_) => _menu(const FrostMenuAction('Copy', onSelected: _noop)), act: tapTrigger),
    BaselineCase('FrostMenuAction/onSelected#hover', (_) => _menu(const FrostMenuAction('Copy', onSelected: _noop)), act: openThenHover('Copy')),
    BaselineCase('FrostMenuAction/checked=true#open', (_) => _menu(const FrostMenuAction('Copy', checked: true, onSelected: _noop)), act: tapTrigger),
    BaselineCase('FrostMenuAction/checked=false#open', (_) => _menu(const FrostMenuAction('Copy', checked: false, onSelected: _noop)), act: tapTrigger),
    BaselineCase(
      'FrostMenuAction/icon+checked#open',
      (_) => _menu(const FrostMenuAction('Copy', leading: FrostGlyph.icon(baselineIcon), checked: true, onSelected: _noop)),
      act: tapTrigger,
    ),
    BaselineCase('FrostMenuAction/enabled=false#open', (_) => _menu(const FrostMenuAction('Copy', enabled: false, onSelected: _noop)), act: tapTrigger),
    BaselineCase(
      'FrostMenuAction/destructive#open',
      (_) => _menu(const FrostMenuAction('Delete', destructive: true, onSelected: _noop)),
      act: tapTrigger,
      envs: BaselineEnv.themes,
    ),
    BaselineCase(
      'FrostMenuAction/shortcut#open',
      (_) => _menu(const FrostMenuAction('Copy', shortcut: FrostShortcut(LogicalKeyboardKey.keyC, primary: true), onSelected: _noop)),
      act: tapTrigger,
    ),
    BaselineCase(
      'FrostMenuAction/tooltip#open',
      (_) => _menu(const FrostMenuAction('Copy', tooltip: 'Copies the item', onSelected: _noop)),
      act: tapTrigger,
    ),
    BaselineCase(
      'FrostMenuAction/enabled=false+tooltip#open',
      (_) => _menu(const FrostMenuAction('Copy', enabled: false, tooltip: 'Nothing selected', onSelected: _noop)),
      act: tapTrigger,
    ),
    // New API: a person's avatar in the icon column.
    BaselineCase(
      'FrostMenuAction/leading=person-avatar#open',
      (_) => _menu(
        const FrostMenuAction(
          'Zhang',
          leading: FrostGlyph.avatar(FrostAvatar.person(name: 'zhang')),
          onSelected: _noop,
        ),
        sibling: false,
      ),
      act: tapTrigger,
      envs: BaselineEnv.themes,
    ),
    BaselineCase(
      'FrostMenuAction/leading=person-avatar#open+sibling',
      (_) => _menu(
        const FrostMenuAction(
          'Zhang',
          leading: FrostGlyph.avatar(FrostAvatar.person(name: 'zhang')),
          onSelected: _noop,
        ),
      ),
      act: tapTrigger,
    ),
  ]);
}
