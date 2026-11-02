import 'package:frost_ui/frost_ui.dart';

import 'baseline.dart';

const _short = '/Users/example/notes.txt';
const _long = '/Users/example/Documents/Projects/frost/assets/images/backgrounds/background-photo-with-a-very-long-name-01.png';
const _windows = r'C:\Users\example\Documents\Projects\frost\assets\images\background-photo-01.png';

void main() {
  baselineGroup('FrostPathText', [
    BaselineCase('FrostPathText/required', (_) => const FrostPathText(_short), envs: BaselineEnv.all),
    BaselineCase('FrostPathText/required+longPath', (_) => const FrostPathText(_long), envs: [BaselineEnv.standard, BaselineEnv.narrow, BaselineEnv.largeText]),
    BaselineCase('FrostPathText/required+windowsPath', (_) => const FrostPathText(_windows), envs: [BaselineEnv.standard, BaselineEnv.narrow]),
    for (final role in [FrostTextRole.footnote, FrostTextRole.callout, FrostTextRole.headline])
      BaselineCase('FrostPathText/role=${role.name}', (_) => FrostPathText(_long, role: role)),
    for (final tone in [FrostTextTone.secondary, FrostTextTone.negative])
      BaselineCase('FrostPathText/tone=${tone.name}', (_) => FrostPathText(_short, tone: tone), envs: BaselineEnv.themes),
    BaselineCase('FrostPathText/selectable', (_) => const FrostPathText(_long, selectable: true), envs: [BaselineEnv.standard, BaselineEnv.narrow]),
  ]);
}
