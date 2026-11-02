import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';

import 'baseline.dart';

void _noop() {}
void _reorder(int oldIndex, int newIndex) {}

const _items = ['Alpha', 'Bravo', 'Charlie', 'Delta'];
const _height = 240.0;

Widget _row(BuildContext context, String item) => FrostListRow(title: item, subtitle: FrostRowSubtitle('Subtitle'), onPressed: _noop);

void main() {
  baselineGroup('FrostReorderableList', [
    BaselineCase(
      'FrostReorderableList/required',
      (_) => FrostReorderableList<String>(items: _items, itemBuilder: _row, onReorder: _reorder),
      height: _height,
      envs: BaselineEnv.all,
    ),
    BaselineCase(
      'FrostReorderableList/required+empty',
      (_) => FrostReorderableList<String>(items: const [], itemBuilder: _row, onReorder: _reorder),
      height: _height,
    ),
    BaselineCase(
      'FrostReorderableList/required+overflowingItems',
      (_) => FrostReorderableList<String>(items: [for (var i = 0; i < 20; i++) 'Item $i'], itemBuilder: _row, onReorder: _reorder),
      height: _height,
    ),
    BaselineCase(
      'FrostReorderableList/required#focus',
      (_) => FrostReorderableList<String>(items: _items, itemBuilder: _row, onReorder: _reorder),
      height: _height,
      act: baselineFocus,
    ),
    BaselineCase(
      'FrostReorderableList/required#hover',
      (_) => FrostReorderableList<String>(items: _items, itemBuilder: _row, onReorder: _reorder),
      height: _height,
      act: (tester, subject) => baselineHover(tester, find.text('Bravo')),
    ),
    BaselineCase(
      'FrostReorderableList/required#press',
      (_) => FrostReorderableList<String>(items: _items, itemBuilder: _row, onReorder: _reorder),
      height: _height,
      act: (tester, subject) => baselinePress(tester, find.text('Bravo')),
    ),
  ]);
}
