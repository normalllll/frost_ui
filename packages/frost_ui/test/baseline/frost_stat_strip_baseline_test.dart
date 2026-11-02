import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/display/stat.dart' show FrostStatStrip;

import 'baseline.dart';

const _three = [
  FrostStat(value: '1.2k', caption: 'Followers'),
  FrostStat(value: '48', caption: 'Following'),
  FrostStat(value: '312', unit: 'posts', caption: 'Total'),
];

const _six = [
  ..._three,
  FrostStat(value: '9', caption: 'Albums'),
  FrostStat(value: '2.4', unit: 'GB', caption: 'Storage'),
  FrostStat(value: '17', caption: 'Likes'),
];

void main() {
  baselineGroup('FrostStatStrip', [
    BaselineCase('FrostStatStrip/required', (_) => const FrostStatStrip(stats: _three), envs: BaselineEnv.all),
    BaselineCase(
      'FrostStatStrip/stats=single',
      (_) => const FrostStatStrip(
        stats: [FrostStat(value: '1.2k', caption: 'Followers')],
      ),
    ),
    BaselineCase('FrostStatStrip/stats=six', (_) => const FrostStatStrip(stats: _six), envs: [BaselineEnv.standard, BaselineEnv.largeText, BaselineEnv.narrow]),
    BaselineCase('FrostStatStrip/stats=empty', (_) => const FrostStatStrip(stats: [])),
  ]);
}
