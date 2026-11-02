import 'package:flutter/widgets.dart';
import 'package:frost_ui/frost_ui.dart';

import 'baseline.dart';

void _changed(String value) {}

const _items = [
  FrostPickerOption(value: 'system', label: 'System'),
  FrostPickerOption(value: 'light', label: 'Light'),
  FrostPickerOption(value: 'dark', label: 'Dark'),
];
const _values = ['system', 'light', 'dark'];

String _label(String value) => value.toUpperCase();

Widget _required(BuildContext context) => const FrostSettingsSelectTile<String>(title: 'Appearance', value: 'light', items: _items, onChanged: _changed);
Widget _valuesRequired(BuildContext context) =>
    FrostSettingsSelectTile<String>.values(title: 'Appearance', value: 'light', values: _values, label: _label, onChanged: _changed);

void main() {
  baselineGroup('FrostSettingsSelectTile', [
    const BaselineCase('FrostSettingsSelectTile/required', _required, envs: BaselineEnv.all),
    const BaselineCase('FrostSettingsSelectTile/required#hover', _required, act: baselineHover),
    const BaselineCase('FrostSettingsSelectTile/required#open', _required, act: baselineTap),
    BaselineCase(
      'FrostSettingsSelectTile/icon',
      (_) => const FrostSettingsSelectTile<String>(title: 'Appearance', icon: baselineIcon, value: 'light', items: _items, onChanged: _changed),
    ),
    BaselineCase(
      'FrostSettingsSelectTile/subtitle',
      (_) => const FrostSettingsSelectTile<String>(
        title: 'Appearance',
        subtitle: 'Follows the system by default',
        value: 'light',
        items: _items,
        onChanged: _changed,
      ),
      envs: [BaselineEnv.standard, BaselineEnv.narrow],
    ),
    for (final tone in FrostStatusTone.values)
      BaselineCase(
        'FrostSettingsSelectTile/subtitle+subtitleStatus=${tone.name}',
        (_) => FrostSettingsSelectTile<String>(
          title: 'Appearance',
          subtitle: 'Status text',
          subtitleStatus: tone,
          value: 'light',
          items: _items,
          onChanged: _changed,
        ),
      ),
    BaselineCase(
      'FrostSettingsSelectTile/enabled=false',
      (_) => const FrostSettingsSelectTile<String>(title: 'Appearance', value: 'light', items: _items, onChanged: _changed, enabled: false),
      envs: BaselineEnv.themes,
    ),
    BaselineCase(
      'FrostSettingsSelectTile/items=empty',
      (_) => const FrostSettingsSelectTile<String>(title: 'Appearance', value: 'light', items: [], onChanged: _changed),
    ),
    BaselineCase(
      'FrostSettingsSelectTile/value=unknown',
      (_) => const FrostSettingsSelectTile<String>(title: 'Appearance', value: 'other', items: _items, onChanged: _changed),
    ),
    BaselineCase(
      'FrostSettingsSelectTile/inSection',
      (_) => const FrostGroupedSection(
        children: [
          FrostSettingsSelectTile<String>(title: 'Appearance', value: 'light', items: _items, onChanged: _changed),
          FrostSettingsSelectTile<String>(title: 'Contrast', value: 'dark', items: _items, onChanged: _changed),
        ],
      ),
    ),
    const BaselineCase('FrostSettingsSelectTile.values/required', _valuesRequired, envs: BaselineEnv.themes),
    BaselineCase(
      'FrostSettingsSelectTile.values/icon+subtitle+subtitleStatus',
      (_) => FrostSettingsSelectTile<String>.values(
        title: 'Appearance',
        icon: baselineIcon,
        subtitle: 'Status text',
        subtitleStatus: FrostStatusTone.positive,
        value: 'light',
        values: _values,
        label: _label,
        onChanged: _changed,
      ),
    ),
    BaselineCase(
      'FrostSettingsSelectTile.values/enabled=false',
      (_) => FrostSettingsSelectTile<String>.values(title: 'Appearance', value: 'light', values: _values, label: _label, onChanged: _changed, enabled: false),
    ),
  ]);
}
