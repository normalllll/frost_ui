import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';

import 'baseline.dart';

void _noop() {}
void _select(String _) {}

const _items = ['Alpha', 'Bravo', 'Charlie', 'Delta'];
const _height = 240.0;

Widget _row(BuildContext context, String item, bool highlighted) => FrostListRow(title: item, subtitle: FrostRowSubtitle('Subtitle'), onPressed: _noop);
Widget _iconRow(BuildContext context, String item, bool highlighted) =>
    item == 'Bravo' ? FrostListRow(title: item, onPressed: _noop) : FrostListRow(title: item, leading: FrostGlyph.icon(baselineIcon), onPressed: _noop);

/// Hovers the row titled [title] rather than the middle of the list.
BaselineAct _hoverRow(String title) =>
    (tester, subject) => baselineHover(tester, find.text(title));

void main() {
  baselineGroup('FrostList', [
    BaselineCase(
      'FrostList/required',
      (_) => FrostList<String>(items: _items, itemBuilder: _row),
      height: _height,
      envs: BaselineEnv.all,
    ),
    BaselineCase(
      'FrostList/required+empty',
      (_) => FrostList<String>(items: const [], itemBuilder: _row),
      height: _height,
    ),
    BaselineCase(
      'FrostList/selected',
      (_) => FrostList<String>(items: _items, itemBuilder: _row, selected: 'Bravo'),
      height: _height,
      envs: BaselineEnv.themes,
    ),
    BaselineCase(
      'FrostList/selected+onSelected',
      (_) => FrostList<String>(items: _items, itemBuilder: _row, selected: 'Bravo', onSelected: _select),
      height: _height,
    ),
    BaselineCase(
      'FrostList/onSelected#hover',
      (_) => FrostList<String>(items: _items, itemBuilder: _row, onSelected: _select),
      height: _height,
      act: _hoverRow('Charlie'),
    ),
    BaselineCase(
      'FrostList/onSelected#press',
      (_) => FrostList<String>(items: _items, itemBuilder: _row, onSelected: _select),
      height: _height,
      act: baselinePress,
    ),
    BaselineCase(
      'FrostList/onSelected#focus',
      (_) => FrostList<String>(items: _items, itemBuilder: _row, onSelected: _select),
      height: _height,
      act: baselineFocus,
    ),
    BaselineCase(
      'FrostList/dividers',
      (_) => FrostList<String>(items: _items, itemBuilder: _row, dividers: true),
      height: _height,
      envs: BaselineEnv.themes,
    ),
    BaselineCase(
      'FrostList/reserveIconColumn',
      (_) => FrostList<String>(items: _items, itemBuilder: _iconRow, reserveIconColumn: true),
      height: _height,
    ),
    BaselineCase(
      'FrostList/reserveIconColumn=false+mixedIcons',
      (_) => FrostList<String>(items: _items, itemBuilder: _iconRow),
      height: _height,
    ),
    BaselineCase(
      'FrostList/dividers+reserveIconColumn',
      (_) => FrostList<String>(items: _items, itemBuilder: _iconRow, dividers: true, reserveIconColumn: true),
      height: _height,
    ),
    BaselineCase(
      'FrostList/overflowingItems',
      (_) => FrostList<String>(items: [for (var i = 0; i < 20; i++) 'Item $i'], itemBuilder: _row, dividers: true),
      height: _height,
    ),
  ]);
}
