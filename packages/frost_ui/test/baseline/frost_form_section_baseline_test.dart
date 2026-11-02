import 'package:frost_ui/frost_ui.dart';

import 'baseline.dart';

const _fields = [FrostTextField(label: 'Name'), FrostTextField(label: 'Email')];

void main() {
  baselineGroup('FrostFormSection', [
    BaselineCase('FrostFormSection/required', (_) => const FrostFormSection(children: _fields), envs: BaselineEnv.all),
    BaselineCase(
      'FrostFormSection/title',
      (_) => const FrostFormSection(title: 'Profile', children: _fields),
      envs: BaselineEnv.themes,
    ),
    BaselineCase(
      'FrostFormSection/children=one',
      (_) => const FrostFormSection(
        title: 'Profile',
        children: [FrostTextField(label: 'Name')],
      ),
    ),
    BaselineCase(
      'FrostFormSection/title+largeText',
      (_) => const FrostFormSection(title: 'Profile', children: _fields),
      envs: [BaselineEnv.largeText],
    ),
  ]);
}
