import 'package:flutter/widgets.dart' show Widget;
import 'package:frost_ui/frost_ui.dart';
import 'package:material_ui/material_ui.dart' show Color;

import 'baseline.dart';

void _changed(String _) {}

// An option has no widget of its own: each case renders it in the picker styles
// that draw its fields.
const _first = FrostPickerOption(value: 'light', label: 'Light');
const _rest = [FrostPickerOption(value: 'dark', label: 'Dark'), FrostPickerOption(value: 'auto', label: 'Auto')];

Widget _segmented(FrostPickerOption<String> first) =>
    FrostPicker.segmented(options: [first, ..._rest], value: 'light', onChanged: _changed, label: 'Appearance');
Widget _inline(FrostPickerOption<String> first) => FrostPicker.inline(options: [first, ..._rest], value: 'light', onChanged: _changed, label: 'Appearance');
Widget _menu(FrostPickerOption<String> first) => FrostPicker.menu(options: [first, ..._rest], value: 'light', onChanged: _changed, label: 'Appearance');
Widget _palette(FrostPickerOption<String> first) => FrostPicker.palette(
  options: [
    first,
    const FrostPickerOption(value: 'dark', label: 'Dark', color: Color(0xFF3B82F6)),
  ],
  value: 'light',
  onChanged: _changed,
  label: 'Appearance',
);

void main() {
  baselineGroup('FrostPickerOption', [
    BaselineCase('FrostPickerOption/required', (_) => _segmented(_first), envs: BaselineEnv.all),
    BaselineCase('FrostPickerOption/required+style=menu', (_) => _menu(_first)),
    BaselineCase('FrostPickerOption/required+style=inline', (_) => _inline(_first)),
    BaselineCase('FrostPickerOption/required+style=menu#open', (_) => _menu(_first), act: baselineTap),

    // icon: the old spelling in every style that draws it.
    BaselineCase(
      'FrostPickerOption/icon',
      (_) => _segmented(const FrostPickerOption(value: 'light', label: 'Light', leading: FrostGlyph.icon(baselineIcon))),
      envs: BaselineEnv.themes,
    ),
    BaselineCase(
      'FrostPickerOption/icon+style=menu',
      (_) => _menu(const FrostPickerOption(value: 'light', label: 'Light', leading: FrostGlyph.icon(baselineIcon))),
      envs: BaselineEnv.themes,
    ),
    BaselineCase(
      'FrostPickerOption/icon+style=inline',
      (_) => _inline(const FrostPickerOption(value: 'light', label: 'Light', leading: FrostGlyph.icon(baselineIcon))),
      envs: BaselineEnv.themes,
    ),
    BaselineCase(
      'FrostPickerOption/icon+style=menu#open',
      (_) => _menu(const FrostPickerOption(value: 'light', label: 'Light', leading: FrostGlyph.icon(baselineIcon))),
      act: baselineTap,
      envs: BaselineEnv.themes,
    ),
    BaselineCase(
      'FrostPickerOption/icon+subtitle+style=inline',
      (_) => _inline(const FrostPickerOption(value: 'light', label: 'Light', leading: FrostGlyph.icon(baselineIcon), subtitle: 'Always bright')),
    ),
    BaselineCase(
      'FrostPickerOption/icon+subtitle+style=menu#open',
      (_) => _menu(const FrostPickerOption(value: 'light', label: 'Light', leading: FrostGlyph.icon(baselineIcon), subtitle: 'Always bright')),
      act: baselineTap,
    ),
    BaselineCase(
      'FrostPickerOption/icon+enabled=false',
      (_) => _segmented(const FrostPickerOption(value: 'light', label: 'Light', leading: FrostGlyph.icon(baselineIcon), enabled: false)),
    ),
    BaselineCase(
      'FrostPickerOption/icon+touch',
      (_) => _segmented(const FrostPickerOption(value: 'light', label: 'Light', leading: FrostGlyph.icon(baselineIcon))),
      envs: [BaselineEnv.touch],
    ),

    // New API: a person's avatar as the option's leading glyph.
    BaselineCase(
      'FrostPickerOption/leading=person-avatar+style=menu',
      (_) => _menu(
        const FrostPickerOption(
          value: 'light',
          label: 'Light',
          leading: FrostGlyph.avatar(FrostAvatar.person(name: 'zhang')),
        ),
      ),
      envs: BaselineEnv.themes,
    ),
    BaselineCase(
      'FrostPickerOption/leading=person-avatar+style=menu#open',
      (_) => _menu(
        const FrostPickerOption(
          value: 'light',
          label: 'Light',
          leading: FrostGlyph.avatar(FrostAvatar.person(name: 'zhang')),
        ),
      ),
      act: baselineTap,
      envs: BaselineEnv.themes,
    ),
    BaselineCase(
      'FrostPickerOption/leading=person-avatar+style=inline',
      (_) => _inline(
        const FrostPickerOption(
          value: 'light',
          label: 'Light',
          leading: FrostGlyph.avatar(FrostAvatar.person(name: 'zhang')),
        ),
      ),
      envs: BaselineEnv.themes,
    ),
    BaselineCase(
      'FrostPickerOption/leading=person-avatar+subtitle+style=menu#open',
      (_) => _menu(
        const FrostPickerOption(
          value: 'light',
          label: 'Light',
          leading: FrostGlyph.avatar(FrostAvatar.person(name: 'zhang')),
          subtitle: 'Always bright',
        ),
      ),
      act: baselineTap,
    ),

    BaselineCase(
      'FrostPickerOption/subtitle+style=inline',
      (_) => _inline(const FrostPickerOption(value: 'light', label: 'Light', subtitle: 'Always bright')),
      envs: BaselineEnv.themes,
    ),
    BaselineCase(
      'FrostPickerOption/subtitle+style=menu',
      (_) => _menu(const FrostPickerOption(value: 'light', label: 'Light', subtitle: 'Always bright')),
    ),
    BaselineCase(
      'FrostPickerOption/subtitle+style=menu#open',
      (_) => _menu(const FrostPickerOption(value: 'light', label: 'Light', subtitle: 'Always bright')),
      act: baselineTap,
    ),
    BaselineCase('FrostPickerOption/enabled=false', (_) => _segmented(const FrostPickerOption(value: 'light', label: 'Light', enabled: false))),
    BaselineCase('FrostPickerOption/enabled=false+style=inline', (_) => _inline(const FrostPickerOption(value: 'light', label: 'Light', enabled: false))),
    BaselineCase(
      'FrostPickerOption/enabled=false+style=menu#open',
      (_) => _menu(const FrostPickerOption(value: 'light', label: 'Light', enabled: false)),
      act: baselineTap,
    ),
    BaselineCase(
      'FrostPickerOption/color+style=palette',
      (_) => _palette(const FrostPickerOption(value: 'light', label: 'Light', color: Color(0xFFE5487A))),
      envs: BaselineEnv.themes,
    ),
    BaselineCase(
      'FrostPickerOption/color+style=segmented',
      (_) => _segmented(const FrostPickerOption(value: 'light', label: 'Light', color: Color(0xFFE5487A))),
    ),
    BaselineCase(
      'FrostPickerOption/value=null',
      (_) => FrostPicker<String?>.segmented(
        options: const [
          FrostPickerOption(value: null, label: 'None'),
          FrostPickerOption(value: 'dark', label: 'Dark'),
        ],
        value: null,
        onChanged: (_) {},
        label: 'Appearance',
      ),
    ),
  ]);
}
