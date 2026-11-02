import 'package:frost_ui/frost_ui.dart';

import 'baseline.dart';

void main() {
  baselineGroup('FrostBadge', [
    BaselineCase('FrostBadge/required', (_) => const FrostBadge(label: 'New'), envs: BaselineEnv.all),
    for (final tone in FrostBadgeTone.values)
      BaselineCase(
        'FrostBadge/tone=${tone.name}',
        (_) => FrostBadge(label: 'New', tone: tone),
        envs: BaselineEnv.themes,
      ),
    BaselineCase('FrostBadge/icon', (_) => const FrostBadge(label: 'New', icon: baselineIcon)),
    BaselineCase(
      'FrostBadge/style=solid',
      (_) => const FrostBadge(label: 'New', style: FrostBadgeStyle.solid),
      envs: BaselineEnv.themes,
    ),
    for (final tone in FrostBadgeTone.values)
      BaselineCase(
        'FrostBadge/tone=${tone.name}+style=solid',
        (_) => FrostBadge(label: 'New', tone: tone, style: FrostBadgeStyle.solid),
        envs: BaselineEnv.themes,
      ),
    BaselineCase('FrostBadge/icon+style=solid', (_) => const FrostBadge(label: 'New', icon: baselineIcon, style: FrostBadgeStyle.solid)),
    for (final role in [FrostTextRole.footnote, FrostTextRole.callout, FrostTextRole.body])
      BaselineCase(
        'FrostBadge/textRole=${role.name}',
        (_) => FrostBadge(label: 'New', textRole: role),
        envs: const [BaselineEnv.standard, BaselineEnv.largeText],
      ),
  ]);
}
