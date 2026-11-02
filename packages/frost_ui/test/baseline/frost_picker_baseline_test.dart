import 'package:flutter/material.dart' show Color;
import 'package:flutter/widgets.dart' show ValueChanged;
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/controls/picker.dart' show FrostPickerStyle;

import 'baseline.dart';

void _changed(String _) {}
void _pressed() {}

const _plain = [
  FrostPickerOption(value: 'light', label: 'Light'),
  FrostPickerOption(value: 'dark', label: 'Dark'),
  FrostPickerOption(value: 'auto', label: 'Auto'),
];
const _many = [
  FrostPickerOption(value: 'a', label: 'Alpha'),
  FrostPickerOption(value: 'b', label: 'Beta'),
  FrostPickerOption(value: 'c', label: 'Gamma'),
  FrostPickerOption(value: 'd', label: 'Delta'),
  FrostPickerOption(value: 'e', label: 'Epsilon'),
];
const _withSubtitle = [
  FrostPickerOption(value: 'light', label: 'Light', subtitle: 'Always bright'),
  FrostPickerOption(value: 'dark', label: 'Dark', subtitle: 'Always dim'),
  FrostPickerOption(value: 'auto', label: 'Auto', subtitle: 'Follow the system'),
];
const _withIcon = [
  FrostPickerOption(value: 'light', label: 'Light', leading: FrostGlyph.icon(baselineIcon)),
  FrostPickerOption(value: 'dark', label: 'Dark', leading: FrostGlyph.icon(baselineIcon)),
  FrostPickerOption(value: 'auto', label: 'Auto', leading: FrostGlyph.icon(baselineIcon)),
];
const _withAvatar = [
  FrostPickerOption(
    value: 'light',
    label: 'Light',
    leading: FrostGlyph.avatar(FrostAvatar.person(name: 'Light')),
  ),
  FrostPickerOption(
    value: 'dark',
    label: 'Dark',
    leading: FrostGlyph.avatar(FrostAvatar.person(name: 'Dark')),
  ),
  FrostPickerOption(
    value: 'auto',
    label: 'Auto',
    leading: FrostGlyph.avatar(FrostAvatar.person(name: 'Auto')),
  ),
];
const _withDisabled = [
  FrostPickerOption(value: 'light', label: 'Light'),
  FrostPickerOption(value: 'dark', label: 'Dark', enabled: false),
  FrostPickerOption(value: 'auto', label: 'Auto'),
];
const _colors = [
  FrostPickerOption(value: 'pink', label: 'Pink', color: Color(0xFFE5487A)),
  FrostPickerOption(value: 'blue', label: 'Blue', color: Color(0xFF3B82F6)),
  FrostPickerOption(value: 'green', label: 'Green', color: Color(0xFF22A06B)),
];

FrostPicker<String> _picker(
  List<FrostPickerOption<String>> options, {
  String? value = 'dark',
  ValueChanged<String>? onChanged = _changed,
  FrostPickerStyle? style,
  FrostControlSize? size,
  String? error,
}) => style == null
    ? FrostPicker(options: options, value: value, onChanged: onChanged, label: 'Appearance', size: size, error: error)
    : FrostPicker(options: options, value: value, onChanged: onChanged, label: 'Appearance', style: style, size: size, error: error);

void main() {
  baselineGroup('FrostPicker', [
    // Default constructor: auto resolves to segments, a menu or a palette.
    BaselineCase('FrostPicker/required', (_) => _picker(_plain, value: null, onChanged: null), envs: BaselineEnv.all),
    BaselineCase('FrostPicker/onChanged', (_) => _picker(_plain), envs: BaselineEnv.themes),
    BaselineCase('FrostPicker/value=unmatched', (_) => _picker(_plain, value: 'missing')),
    BaselineCase('FrostPicker/options=many', (_) => _picker(_many, value: 'c'), envs: BaselineEnv.themes),
    BaselineCase('FrostPicker/options=many+disabled', (_) => _picker(_many, value: 'c', onChanged: null)),
    BaselineCase('FrostPicker/options=subtitle', (_) => _picker(_withSubtitle)),
    BaselineCase('FrostPicker/options=icon', (_) => _picker(_withIcon)),
    BaselineCase('FrostPicker/options=disabled', (_) => _picker(_withDisabled)),
    BaselineCase('FrostPicker/options=color', (_) => _picker(_colors, value: 'blue'), envs: BaselineEnv.themes),
    BaselineCase('FrostPicker/options=empty', (_) => _picker(const [], value: null)),
    for (final style in FrostPickerStyle.values)
      BaselineCase(
        'FrostPicker/style=${style.name}',
        (_) => _picker(style == FrostPickerStyle.palette ? _colors : _plain, value: style == FrostPickerStyle.palette ? 'blue' : 'dark', style: style),
        envs: BaselineEnv.themes,
      ),
    for (final size in FrostControlSize.values)
      BaselineCase('FrostPicker/size=${size.name}', (_) => _picker(_plain, size: size), envs: [BaselineEnv.standard, BaselineEnv.touch]),
    BaselineCase('FrostPicker/error', (_) => _picker(_plain, error: 'Choose one'), envs: BaselineEnv.themes),
    BaselineCase('FrostPicker/error+options=many', (_) => _picker(_many, error: 'Choose one')),
    BaselineCase('FrostPicker/onChanged#hover', (_) => _picker(_plain), act: baselineHover),
    BaselineCase('FrostPicker/onChanged#focus', (_) => _picker(_plain), act: baselineFocus),
    BaselineCase('FrostPicker/options=many#hover', (_) => _picker(_many, value: 'c'), act: baselineHover),
    BaselineCase('FrostPicker/options=many#press', (_) => _picker(_many, value: 'c'), act: baselinePress),
    BaselineCase('FrostPicker/options=many#focus', (_) => _picker(_many, value: 'c'), act: baselineFocus),
    BaselineCase(
      'FrostPicker/options=many#open',
      (_) => _picker(_many, value: 'c'),
      act: baselineTap,
      envs: BaselineEnv.themes,
    ),

    // .menu
    BaselineCase(
      'FrostPicker.menu/required',
      (_) => const FrostPicker.menu(options: _plain, value: null, onChanged: null, label: 'Appearance'),
      envs: BaselineEnv.all,
    ),
    BaselineCase(
      'FrostPicker.menu/onChanged',
      (_) => const FrostPicker.menu(options: _plain, value: 'dark', onChanged: _changed, label: 'Appearance'),
      envs: BaselineEnv.themes,
    ),
    BaselineCase(
      'FrostPicker.menu/value=unmatched',
      (_) => const FrostPicker.menu(options: _plain, value: 'missing', onChanged: _changed, label: 'Appearance'),
    ),
    BaselineCase(
      'FrostPicker.menu/options=subtitle',
      (_) => const FrostPicker.menu(options: _withSubtitle, value: 'dark', onChanged: _changed, label: 'Appearance'),
    ),
    BaselineCase(
      'FrostPicker.menu/options=icon',
      (_) => const FrostPicker.menu(options: _withIcon, value: 'dark', onChanged: _changed, label: 'Appearance'),
    ),
    BaselineCase(
      'FrostPicker.menu/options=disabled',
      (_) => const FrostPicker.menu(options: _withDisabled, value: 'light', onChanged: _changed, label: 'Appearance'),
    ),
    BaselineCase(
      'FrostPicker.menu/options=empty',
      (_) => const FrostPicker<String>.menu(options: [], value: null, onChanged: _changed, label: 'Appearance'),
    ),
    for (final size in FrostControlSize.values)
      BaselineCase(
        'FrostPicker.menu/size=${size.name}',
        (_) => FrostPicker.menu(options: _plain, value: 'dark', onChanged: _changed, label: 'Appearance', size: size),
        envs: [BaselineEnv.standard, BaselineEnv.touch],
      ),
    BaselineCase(
      'FrostPicker.menu/error',
      (_) => const FrostPicker.menu(options: _plain, value: 'dark', onChanged: _changed, label: 'Appearance', error: 'Choose one'),
      envs: BaselineEnv.themes,
    ),
    BaselineCase(
      'FrostPicker.menu/onChanged#hover',
      (_) => const FrostPicker.menu(options: _plain, value: 'dark', onChanged: _changed, label: 'Appearance'),
      act: baselineHover,
    ),
    BaselineCase(
      'FrostPicker.menu/onChanged#press',
      (_) => const FrostPicker.menu(options: _plain, value: 'dark', onChanged: _changed, label: 'Appearance'),
      act: baselinePress,
    ),
    BaselineCase(
      'FrostPicker.menu/onChanged#focus',
      (_) => const FrostPicker.menu(options: _plain, value: 'dark', onChanged: _changed, label: 'Appearance'),
      act: baselineFocus,
    ),
    BaselineCase(
      'FrostPicker.menu/onChanged#open',
      (_) => const FrostPicker.menu(options: _plain, value: 'dark', onChanged: _changed, label: 'Appearance'),
      act: baselineTap,
      envs: BaselineEnv.themes,
    ),
    BaselineCase(
      'FrostPicker.menu/options=subtitle#open',
      (_) => const FrostPicker.menu(options: _withSubtitle, value: 'dark', onChanged: _changed, label: 'Appearance'),
      act: baselineTap,
    ),
    BaselineCase(
      'FrostPicker.menu/options=icon#open',
      (_) => const FrostPicker.menu(options: _withIcon, value: 'dark', onChanged: _changed, label: 'Appearance'),
      act: baselineTap,
    ),
    BaselineCase(
      'FrostPicker.menu/options=disabled#open',
      (_) => const FrostPicker.menu(options: _withDisabled, value: 'light', onChanged: _changed, label: 'Appearance'),
      act: baselineTap,
    ),
    BaselineCase(
      'FrostPicker.menu/options=many#open',
      (_) => const FrostPicker.menu(options: _many, value: 'c', onChanged: _changed, label: 'Appearance'),
      act: baselineTap,
    ),
    // New API: a person's avatar as the option's leading glyph.
    BaselineCase(
      'FrostPicker.menu/options=person-avatar',
      (_) => const FrostPicker.menu(options: _withAvatar, value: 'dark', onChanged: _changed, label: 'Appearance'),
      envs: BaselineEnv.themes,
    ),
    BaselineCase(
      'FrostPicker.menu/options=person-avatar#open',
      (_) => const FrostPicker.menu(options: _withAvatar, value: 'dark', onChanged: _changed, label: 'Appearance'),
      act: baselineTap,
      envs: BaselineEnv.themes,
    ),

    // .segmented
    BaselineCase(
      'FrostPicker.segmented/required',
      (_) => const FrostPicker.segmented(options: _plain, value: null, onChanged: null, label: 'Appearance'),
      envs: BaselineEnv.all,
    ),
    BaselineCase(
      'FrostPicker.segmented/onChanged',
      (_) => const FrostPicker.segmented(options: _plain, value: 'dark', onChanged: _changed, label: 'Appearance'),
      envs: BaselineEnv.themes,
    ),
    BaselineCase(
      'FrostPicker.segmented/value=unmatched',
      (_) => const FrostPicker.segmented(options: _plain, value: 'missing', onChanged: _changed, label: 'Appearance'),
    ),
    BaselineCase(
      'FrostPicker.segmented/options=icon',
      (_) => const FrostPicker.segmented(options: _withIcon, value: 'dark', onChanged: _changed, label: 'Appearance'),
      envs: BaselineEnv.themes,
    ),
    BaselineCase(
      'FrostPicker.segmented/options=disabled',
      (_) => const FrostPicker.segmented(options: _withDisabled, value: 'light', onChanged: _changed, label: 'Appearance'),
    ),
    for (final size in FrostControlSize.values)
      BaselineCase(
        'FrostPicker.segmented/size=${size.name}',
        (_) => FrostPicker.segmented(options: _plain, value: 'dark', onChanged: _changed, label: 'Appearance', size: size),
        envs: [BaselineEnv.standard, BaselineEnv.touch],
      ),
    BaselineCase(
      'FrostPicker.segmented/error',
      (_) => const FrostPicker.segmented(options: _plain, value: 'dark', onChanged: _changed, label: 'Appearance', error: 'Choose one'),
      envs: BaselineEnv.themes,
    ),
    BaselineCase(
      'FrostPicker.segmented/iconOnly',
      (_) => const FrostPicker.segmented(options: _withIcon, value: 'dark', onChanged: _changed, label: 'Appearance', iconOnly: true),
      envs: BaselineEnv.themes,
    ),
    BaselineCase(
      'FrostPicker.segmented/onChanged#hover',
      (_) => const FrostPicker.segmented(options: _plain, value: 'dark', onChanged: _changed, label: 'Appearance'),
      act: baselineHover,
    ),
    BaselineCase(
      'FrostPicker.segmented/onChanged#press',
      (_) => const FrostPicker.segmented(options: _plain, value: 'dark', onChanged: _changed, label: 'Appearance'),
      act: baselinePress,
    ),
    BaselineCase(
      'FrostPicker.segmented/onChanged#focus',
      (_) => const FrostPicker.segmented(options: _plain, value: 'dark', onChanged: _changed, label: 'Appearance'),
      act: baselineFocus,
    ),

    // .inline
    BaselineCase(
      'FrostPicker.inline/required',
      (_) => const FrostPicker.inline(options: _plain, value: null, onChanged: null, label: 'Appearance'),
      envs: BaselineEnv.all,
    ),
    BaselineCase(
      'FrostPicker.inline/onChanged',
      (_) => const FrostPicker.inline(options: _plain, value: 'dark', onChanged: _changed, label: 'Appearance'),
      envs: BaselineEnv.themes,
    ),
    BaselineCase(
      'FrostPicker.inline/value=unmatched',
      (_) => const FrostPicker.inline(options: _plain, value: 'missing', onChanged: _changed, label: 'Appearance'),
    ),
    BaselineCase(
      'FrostPicker.inline/options=subtitle',
      (_) => const FrostPicker.inline(options: _withSubtitle, value: 'dark', onChanged: _changed, label: 'Appearance'),
      envs: BaselineEnv.themes,
    ),
    BaselineCase(
      'FrostPicker.inline/options=icon',
      (_) => const FrostPicker.inline(options: _withIcon, value: 'dark', onChanged: _changed, label: 'Appearance'),
    ),
    BaselineCase(
      'FrostPicker.inline/options=disabled',
      (_) => const FrostPicker.inline(options: _withDisabled, value: 'light', onChanged: _changed, label: 'Appearance'),
    ),
    for (final size in FrostControlSize.values)
      BaselineCase(
        'FrostPicker.inline/size=${size.name}',
        (_) => FrostPicker.inline(options: _plain, value: 'dark', onChanged: _changed, label: 'Appearance', size: size),
        envs: [BaselineEnv.standard, BaselineEnv.touch],
      ),
    BaselineCase(
      'FrostPicker.inline/error',
      (_) => const FrostPicker.inline(options: _plain, value: 'dark', onChanged: _changed, label: 'Appearance', error: 'Choose one'),
      envs: BaselineEnv.themes,
    ),
    BaselineCase(
      'FrostPicker.inline/onChanged#hover',
      (_) => const FrostPicker.inline(options: _plain, value: 'dark', onChanged: _changed, label: 'Appearance'),
      act: baselineHover,
    ),
    BaselineCase(
      'FrostPicker.inline/onChanged#press',
      (_) => const FrostPicker.inline(options: _plain, value: 'dark', onChanged: _changed, label: 'Appearance'),
      act: baselinePress,
    ),
    BaselineCase(
      'FrostPicker.inline/onChanged#focus',
      (_) => const FrostPicker.inline(options: _plain, value: 'dark', onChanged: _changed, label: 'Appearance'),
      act: baselineFocus,
    ),

    // .palette
    BaselineCase(
      'FrostPicker.palette/required',
      (_) => const FrostPicker.palette(options: _colors, value: null, onChanged: null, label: 'Accent'),
      envs: BaselineEnv.all,
    ),
    BaselineCase(
      'FrostPicker.palette/onChanged',
      (_) => const FrostPicker.palette(options: _colors, value: 'blue', onChanged: _changed, label: 'Accent'),
      envs: BaselineEnv.themes,
    ),
    BaselineCase(
      'FrostPicker.palette/value=unmatched',
      (_) => const FrostPicker.palette(options: _colors, value: 'missing', onChanged: _changed, label: 'Accent'),
    ),
    for (final size in FrostControlSize.values)
      BaselineCase(
        'FrostPicker.palette/size=${size.name}',
        (_) => FrostPicker.palette(options: _colors, value: 'blue', onChanged: _changed, label: 'Accent', size: size),
        envs: [BaselineEnv.standard, BaselineEnv.touch],
      ),
    BaselineCase(
      'FrostPicker.palette/error',
      (_) => const FrostPicker.palette(options: _colors, value: 'blue', onChanged: _changed, label: 'Accent', error: 'Choose one'),
      envs: BaselineEnv.themes,
    ),
    BaselineCase(
      'FrostPicker.palette/trailingSwatch',
      (_) => const FrostPicker.palette(
        options: _colors,
        value: 'blue',
        onChanged: _changed,
        label: 'Accent',
        trailingSwatch: FrostColorSwatch(color: Color(0xFF999999), label: 'Custom', icon: baselineIcon, onPressed: _pressed),
      ),
      envs: BaselineEnv.themes,
    ),
    BaselineCase(
      'FrostPicker.palette/trailingSwatch=selected',
      (_) => const FrostPicker.palette(
        options: _colors,
        value: 'custom',
        onChanged: _changed,
        label: 'Accent',
        trailingSwatch: FrostColorSwatch(color: Color(0xFFB45309), label: 'Custom', selected: true, onPressed: _pressed),
      ),
    ),
    BaselineCase(
      'FrostPicker.palette/onChanged#hover',
      (_) => const FrostPicker.palette(options: _colors, value: 'blue', onChanged: _changed, label: 'Accent'),
      act: baselineHover,
    ),
    BaselineCase(
      'FrostPicker.palette/onChanged#press',
      (_) => const FrostPicker.palette(options: _colors, value: 'blue', onChanged: _changed, label: 'Accent'),
      act: baselinePress,
    ),
    BaselineCase(
      'FrostPicker.palette/onChanged#focus',
      (_) => const FrostPicker.palette(options: _colors, value: 'blue', onChanged: _changed, label: 'Accent'),
      act: baselineFocus,
    ),
  ]);
}
