import 'package:flutter/widgets.dart';
import 'package:frost_ui/frost_ui.dart';

import 'baseline.dart';

void _changed(bool _) {}

void main() {
  baselineGroup('FrostFormRow', [
    BaselineCase(
      'FrostFormRow/required',
      (_) => const FrostFormRow(
        label: FrostText('Notifications'),
        control: FrostSwitch(value: true, onChanged: _changed, semanticLabel: 'Notifications'),
      ),
      envs: BaselineEnv.all,
    ),
    BaselineCase(
      'FrostFormRow/label=long',
      (_) => const FrostFormRow(
        label: FrostText('Send me a notification when a download finishes, fails or is paused'),
        control: FrostSwitch(value: false, onChanged: _changed, semanticLabel: 'Notifications'),
      ),
      envs: [BaselineEnv.standard, BaselineEnv.narrow],
    ),
    BaselineCase(
      'FrostFormRow/control=wide',
      (_) => const FrostFormRow(
        label: FrostText('Quality'),
        control: SizedBox(width: 340, child: FrostSlider(value: .5, onChanged: null, semanticLabel: 'Quality')),
      ),
      envs: [BaselineEnv.standard, BaselineEnv.narrow],
    ),
    BaselineCase(
      'FrostFormRow/control=picker',
      (_) => const FrostFormRow(
        label: FrostText('Theme'),
        control: FrostPicker.segmented(
          options: [
            FrostPickerOption(value: 0, label: 'Light'),
            FrostPickerOption(value: 1, label: 'Dark'),
          ],
          value: 0,
          onChanged: null,
          label: 'Theme',
        ),
      ),
      envs: [BaselineEnv.standard, BaselineEnv.narrow],
    ),
  ]);
}
