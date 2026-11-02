import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/navigation/sort_menu.dart' show FrostSortMenu;

void main() {
  test('8B filters compile from widgets and frost_ui only', () {
    const options = [FrostPickerOption(value: 1, label: 'Field')];
    final widgets = <Widget>[
      FrostFilterBar(
        chips: [FrostFilterChip(label: 'Filter', value: 'Value', onPressed: () {}, onClear: () {})],
        onClearAll: () {},
      ),
      FrostSortMenu(fields: options, value: 1, ascending: true, onChanged: (_, _) {}, label: 'Sort'),
      FrostToolbar(
        trailing: [
          FrostToolbarItem.sortMenu(fields: options, value: 1, ascending: true, onChanged: (_, _) {}, label: 'Sort', priority: FrostToolbarPriority.low),
        ],
      ),
    ];
    expect(widgets, hasLength(3));
  });
}
