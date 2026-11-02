import 'package:flutter/widgets.dart';
import 'package:frost_ui/frost_ui.dart';

import 'baseline.dart';

void _noop() {}

const _height = 240.0;

Widget _row(BuildContext context, int index) => FrostListRow(title: 'Item $index', subtitle: FrostRowSubtitle('Subtitle'), onPressed: _noop);

/// A sliver needs a scroll view of its own.
Widget _scroll(int count, {bool dividers = false}) => CustomScrollView(
  slivers: [FrostSliverList(itemCount: count, itemBuilder: _row, dividers: dividers)],
);

void main() {
  baselineGroup('FrostSliverList', [
    BaselineCase('FrostSliverList/required', (_) => _scroll(4), height: _height, envs: BaselineEnv.all),
    BaselineCase('FrostSliverList/required+empty', (_) => _scroll(0), height: _height),
    BaselineCase('FrostSliverList/dividers', (_) => _scroll(4, dividers: true), height: _height, envs: BaselineEnv.themes),
    BaselineCase('FrostSliverList/dividers+overflowingItems', (_) => _scroll(20, dividers: true), height: _height),
  ]);
}
