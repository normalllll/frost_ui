import 'package:frost_ui/frost_ui.dart';

import 'baseline.dart';

void main() {
  baselineGroup('FrostCountBadge', [
    BaselineCase('FrostCountBadge/required', (_) => const FrostCountBadge(count: 5), envs: BaselineEnv.all),
    BaselineCase('FrostCountBadge/count=0', (_) => const FrostCountBadge(count: 0)),
    BaselineCase('FrostCountBadge/count=1234', (_) => const FrostCountBadge(count: 1234)),
    BaselineCase('FrostCountBadge/max', (_) => const FrostCountBadge(count: 12, max: 9), envs: BaselineEnv.themes),
    BaselineCase('FrostCountBadge/max=count', (_) => const FrostCountBadge(count: 99, max: 99)),
    for (final tone in FrostCountBadgeTone.values)
      BaselineCase('FrostCountBadge/tone=${tone.name}', (_) => FrostCountBadge(count: 5, tone: tone), envs: BaselineEnv.themes),
  ]);
}
