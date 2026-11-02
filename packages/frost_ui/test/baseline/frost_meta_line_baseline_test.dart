import 'package:frost_ui/frost_ui.dart';

import 'baseline.dart';

const _items = ['2.4 MB', '1920 × 1080', 'PNG', '3 days ago'];

void main() {
  baselineGroup('FrostMetaLine', [
    BaselineCase('FrostMetaLine/required', (_) => const FrostMetaLine(items: _items), envs: BaselineEnv.all),
    BaselineCase('FrostMetaLine/items=single', (_) => const FrostMetaLine(items: ['2.4 MB'])),
    BaselineCase('FrostMetaLine/items=empty-skipped', (_) => const FrostMetaLine(items: ['2.4 MB', '', 'PNG'])),
    BaselineCase('FrostMetaLine/items=empty', (_) => const FrostMetaLine(items: [])),
    BaselineCase(
      'FrostMetaLine/items=wider-than-line',
      (_) => const FrostMetaLine(items: ['An item that is far wider than the available width of the line and scrolls on its own', 'PNG']),
      envs: [BaselineEnv.narrow],
    ),
  ]);
}
