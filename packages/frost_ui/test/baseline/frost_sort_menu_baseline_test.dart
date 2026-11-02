import 'package:flutter/widgets.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/navigation/sort_menu.dart' show FrostSortMenu;

import 'baseline.dart';
import 'nav_overlay_support.dart';

void _sorted(String _, bool _) {}

const _fields = [FrostPickerOption<String>(value: 'name', label: 'Name'), FrostPickerOption<String>(value: 'date', label: 'Date')];
const _iconFields = [
  FrostPickerOption<String>(value: 'name', label: 'Name', leading: FrostGlyph.icon(baselineIcon)),
  FrostPickerOption<String>(value: 'date', label: 'Date', leading: FrostGlyph.icon(baselineIcon)),
  FrostPickerOption<String>(value: 'size', label: 'Size', leading: FrostGlyph.icon(baselineIcon), enabled: false),
];

Widget _menu({List<FrostPickerOption<String>> fields = _fields, String value = 'name', bool ascending = true}) =>
    FrostSortMenu<String>(fields: fields, value: value, ascending: ascending, onChanged: _sorted, label: 'Sort');

void main() {
  baselineGroup('FrostSortMenu', [
    BaselineCase('FrostSortMenu/required', (_) => _menu(), envs: BaselineEnv.all),
    BaselineCase('FrostSortMenu/required#open', (_) => _menu(), act: tapButton, envs: BaselineEnv.themes),
    BaselineCase('FrostSortMenu/required#hover', (_) => _menu(), act: baselineHover),
    BaselineCase('FrostSortMenu/required#focus', (_) => _menu(), act: baselineFocus),
    BaselineCase('FrostSortMenu/value=date', (_) => _menu(value: 'date')),
    BaselineCase('FrostSortMenu/value=date#open', (_) => _menu(value: 'date'), act: tapButton),
    BaselineCase('FrostSortMenu/ascending=false', (_) => _menu(ascending: false)),
    BaselineCase('FrostSortMenu/ascending=false#open', (_) => _menu(ascending: false), act: tapButton),
    BaselineCase('FrostSortMenu/fields=icon#open', (_) => _menu(fields: _iconFields), act: tapButton),
    BaselineCase('FrostSortMenu/value=unknown', (_) => _menu(value: 'missing')),
  ]);
}
