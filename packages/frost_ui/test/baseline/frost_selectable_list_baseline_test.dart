import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';

import 'baseline.dart';

void _noop() {}

const _items = ['Alpha', 'Bravo', 'Charlie', 'Delta'];
const _height = 240.0;

/// A fresh selection per case so cases never share state.
FrostSelection<String> _selection({bool active = false, Set<String> selected = const {}}) {
  final selection = FrostSelection<String>();
  if (active) selection.enter();
  selected.forEach(selection.toggle);
  return selection;
}

Widget _row(BuildContext context, String item, bool selected) => FrostListRow(title: item, subtitle: FrostRowSubtitle('Subtitle'), onPressed: _noop);

BaselineAct _hoverRow(String title) =>
    (tester, subject) => baselineHover(tester, find.text(title));

void main() {
  baselineGroup('FrostSelectableList', [
    BaselineCase(
      'FrostSelectableList/required',
      (_) => FrostSelectableList<String>(selection: _selection(), items: _items, itemBuilder: _row),
      height: _height,
      envs: BaselineEnv.all,
    ),
    BaselineCase(
      'FrostSelectableList/required+empty',
      (_) => FrostSelectableList<String>(selection: _selection(), items: const [], itemBuilder: _row),
      height: _height,
    ),
    BaselineCase(
      'FrostSelectableList/selection=active',
      (_) => FrostSelectableList<String>(selection: _selection(active: true), items: _items, itemBuilder: _row),
      height: _height,
      envs: BaselineEnv.themes,
    ),
    BaselineCase(
      'FrostSelectableList/selection=selected',
      (_) => FrostSelectableList<String>(
        selection: _selection(selected: {'Bravo', 'Charlie'}),
        items: _items,
        itemBuilder: _row,
      ),
      height: _height,
      envs: BaselineEnv.all,
    ),
    BaselineCase(
      'FrostSelectableList/selection=selected#hover',
      (_) => FrostSelectableList<String>(
        selection: _selection(selected: {'Bravo'}),
        items: _items,
        itemBuilder: _row,
      ),
      height: _height,
      act: _hoverRow('Charlie'),
    ),
    BaselineCase(
      'FrostSelectableList/selection=active#press',
      (_) => FrostSelectableList<String>(selection: _selection(active: true), items: _items, itemBuilder: _row),
      height: _height,
      act: (tester, subject) => baselinePress(tester, find.text('Charlie')),
    ),
    BaselineCase(
      'FrostSelectableList/required#hover',
      (_) => FrostSelectableList<String>(selection: _selection(), items: _items, itemBuilder: _row),
      height: _height,
      act: _hoverRow('Charlie'),
    ),
    BaselineCase(
      'FrostSelectableList/selection=selected+overflowingItems',
      (_) => FrostSelectableList<String>(
        selection: _selection(selected: {'Item 1'}),
        items: [for (var i = 0; i < 20; i++) 'Item $i'],
        itemBuilder: _row,
      ),
      height: _height,
    ),
  ]);
}
