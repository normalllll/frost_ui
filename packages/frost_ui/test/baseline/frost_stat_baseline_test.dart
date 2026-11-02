import 'package:frost_ui/frost_ui.dart';

import 'baseline.dart';

void main() {
  baselineGroup('FrostStat', [
    BaselineCase(
      'FrostStat/required',
      (_) => const FrostStat(value: '1,234', caption: 'Followers'),
      envs: BaselineEnv.all,
    ),
    BaselineCase(
      'FrostStat/unit',
      (_) => const FrostStat(value: '12.4', unit: 'GB', caption: 'Used'),
      envs: BaselineEnv.themes,
    ),
    BaselineCase('FrostStat/caption=empty', (_) => const FrostStat(value: '1,234', caption: '')),
    BaselineCase(
      'FrostStat/value=long',
      (_) => const FrostStat(value: '123,456,789,012,345,678', unit: 'bytes', caption: 'Total'),
      envs: [BaselineEnv.narrow],
    ),
    BaselineCase(
      'FrostStat.skeleton/required',
      (_) => FrostStat.skeleton(value: '1,234', unit: null, caption: 'Followers'),
      envs: BaselineEnv.all,
    ),
    BaselineCase('FrostStat.skeleton/unit', (_) => FrostStat.skeleton(value: '12.4', unit: 'GB', caption: 'Used')),
    BaselineCase('FrostStat.skeleton/caption=null', (_) => FrostStat.skeleton(value: '1,234', unit: null, caption: null)),
  ]);
}
