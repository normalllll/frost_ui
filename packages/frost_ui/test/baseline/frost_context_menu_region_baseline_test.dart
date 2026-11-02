import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';

import 'baseline.dart';
import 'nav_overlay_support.dart';

void _noop() {}

const _entries = <FrostMenuEntry>[
  FrostMenuAction('Copy', leading: FrostGlyph.icon(baselineIcon), onSelected: _noop),
  FrostMenuAction('Delete', destructive: true, onSelected: _noop),
];

Widget _area() => const SizedBox(width: 200, height: 80, child: Center(child: Text('Area')));

Future<void> _rightClick(WidgetTester tester, Finder subject) async {
  await tester.tap(subject, buttons: kSecondaryMouseButton);
}

Future<void> _longPress(WidgetTester tester, Finder subject) => tester.longPress(subject);

void main() {
  baselineGroup('FrostContextMenuRegion', [
    BaselineCase(
      'FrostContextMenuRegion/required',
      (_) => FrostContextMenuRegion(entries: _entries, child: _area()),
      envs: BaselineEnv.all,
    ),
    BaselineCase(
      'FrostContextMenuRegion/required#open',
      (_) => FrostContextMenuRegion(entries: _entries, child: _area()),
      act: _rightClick,
      envs: [...BaselineEnv.themes, BaselineEnv.largeText],
    ),
    // Long press on a narrow touch window opens the fitted sheet form.
    BaselineCase(
      'FrostContextMenuRegion/required#open-sheet',
      (_) => FrostContextMenuRegion(entries: _entries, child: _area()),
      act: onPhone(_longPress),
      envs: [narrowTouch],
    ),
    BaselineCase(
      'FrostContextMenuRegion/required#open-touch',
      (_) => FrostContextMenuRegion(entries: _entries, child: _area()),
      act: _longPress,
      envs: [BaselineEnv.touch],
    ),
    BaselineCase(
      'FrostContextMenuRegion/entries=empty#open',
      (_) => FrostContextMenuRegion(entries: const [], child: _area()),
      act: _rightClick,
    ),
    BaselineCase(
      'FrostContextMenuRegion/enabled=false#open',
      (_) => FrostContextMenuRegion(entries: _entries, enabled: false, child: _area()),
      act: _rightClick,
    ),
    BaselineCase(
      'FrostContextMenuRegion/entries=mixed#open',
      (_) => FrostContextMenuRegion(
        entries: const [
          FrostMenuSection(
            header: 'Edit',
            entries: [FrostMenuAction('Copy', onSelected: _noop)],
          ),
          FrostMenuDivider(),
          FrostMenuSubmenu('Send to', entries: [FrostMenuAction('Mail', onSelected: _noop)]),
        ],
        child: _area(),
      ),
      act: _rightClick,
    ),
    BaselineCase(
      'FrostContextMenuRegion/required#focus',
      (_) => FrostContextMenuRegion(
        entries: _entries,
        child: const FrostButton(label: 'Target', onPressed: _noop),
      ),
      act: baselineFocus,
    ),
    BaselineCase(
      'FrostContextMenuX.frostContextMenu/required',
      (_) => _area().frostContextMenu(_entries),
      envs: BaselineEnv.all,
    ),
    BaselineCase(
      'FrostContextMenuX.frostContextMenu/enabled=false#open',
      (_) => _area().frostContextMenu(_entries, enabled: false),
      act: _rightClick,
    ),
  ]);
}
