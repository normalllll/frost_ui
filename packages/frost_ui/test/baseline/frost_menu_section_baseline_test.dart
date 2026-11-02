import 'package:frost_ui/frost_ui.dart';

import 'baseline.dart';
import 'nav_overlay_support.dart';

void _noop() {}

const _items = <FrostMenuEntry>[FrostMenuAction('Copy', onSelected: _noop), FrostMenuAction('Paste', onSelected: _noop)];

void main() {
  baselineGroup('FrostMenuSection', [
    BaselineCase(
      'FrostMenuSection/required#open',
      (_) => menuAnchor(const [FrostMenuSection(entries: _items)]),
      act: tapTrigger,
      envs: BaselineEnv.themes,
    ),
    BaselineCase(
      'FrostMenuSection/header#open',
      (_) => menuAnchor(const [FrostMenuSection(header: 'Edit', entries: _items)]),
      act: tapTrigger,
      envs: BaselineEnv.themes,
    ),
    BaselineCase(
      'FrostMenuSection/header+sections#open',
      (_) => menuAnchor(const [
        FrostMenuSection(header: 'Edit', entries: _items),
        FrostMenuSection(
          header: 'View',
          entries: [FrostMenuAction('Zoom', leading: FrostGlyph.icon(baselineIcon), onSelected: _noop)],
        ),
      ]),
      act: tapTrigger,
    ),
  ]);
}
