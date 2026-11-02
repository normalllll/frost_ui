import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';

import 'baseline.dart';

void _noop() {}

const _items = ['Alpha', 'Bravo', 'Charlie'];

/// A fresh selection per case so cases never share state.
FrostSelection<String> _selection({bool active = false, Set<String> selected = const {}}) {
  final selection = FrostSelection<String>();
  if (active) selection.enter();
  selected.forEach(selection.toggle);
  return selection;
}

/// The scope with selectable rows, which is how it is used.
Widget _scope(FrostSelection<String> selection) => FrostSelectionScope<String>(
  selection: selection,
  items: _items,
  child: Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final item in _items)
        FrostSelectableItem<String>(
          item: item,
          child: FrostListRow(title: item, subtitle: FrostRowSubtitle('Subtitle'), onPressed: _noop),
        ),
    ],
  ),
);

void main() {
  baselineGroup('FrostSelectionScope', [
    BaselineCase('FrostSelectionScope/required', (_) => _scope(_selection()), envs: BaselineEnv.all),
    BaselineCase('FrostSelectionScope/selection=active', (_) => _scope(_selection(active: true)), envs: BaselineEnv.themes),
    BaselineCase('FrostSelectionScope/selection=selected', (_) => _scope(_selection(selected: {'Bravo'})), envs: BaselineEnv.themes),
    BaselineCase('FrostSelectionScope/selection=allSelected', (_) => _scope(_selection(selected: {'Alpha', 'Bravo', 'Charlie'}))),
    BaselineCase(
      'FrostSelectionScope/child=plain',
      (_) => FrostSelectionScope<String>(selection: _selection(), items: _items, child: const SizedBox(width: 100, height: 40)),
    ),
    BaselineCase(
      'FrostSelectionScope/selection=selected#hover',
      (_) => _scope(_selection(selected: {'Bravo'})),
      act: (tester, subject) => baselineHover(tester, find.text('Charlie')),
    ),
  ]);
}
