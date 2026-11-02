import 'package:frost_ui/frost_ui.dart';

import 'baseline.dart';
import 'nav_overlay_support.dart';

void _noop() {}

void main() {
  baselineGroup('FrostMenuDivider', [
    BaselineCase(
      'FrostMenuDivider/required#open',
      (_) => menuAnchor(const [FrostMenuAction('Copy', onSelected: _noop), FrostMenuDivider(), FrostMenuAction('Delete', onSelected: _noop)]),
      act: tapTrigger,
      envs: BaselineEnv.themes,
    ),
  ]);
}
