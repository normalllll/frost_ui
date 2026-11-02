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
  baselineGroup('FrostSelectableItem', [
    BaselineCase('FrostSelectableItem/required', (_) => _scope(_selection()), envs: BaselineEnv.all),
    BaselineCase('FrostSelectableItem/required+selectionActive', (_) => _scope(_selection(active: true)), envs: BaselineEnv.themes),
    BaselineCase('FrostSelectableItem/required+selected', (_) => _scope(_selection(selected: {'Bravo'})), envs: BaselineEnv.themes),
    BaselineCase(
      'FrostSelectableItem/required+selected#press',
      (_) => _scope(_selection(selected: {'Bravo'})),
      act: (tester, subject) => baselinePress(tester, find.text('Charlie')),
    ),
    BaselineCase('FrostSelectableItem/required+selected#focus', (_) => _scope(_selection(selected: {'Bravo'})), act: baselineFocus),
    BaselineCase(
      'FrostSelectableItem/child=plain',
      (_) => FrostSelectionScope<String>(
        selection: _selection(selected: {'Alpha'}),
        items: const ['Alpha'],
        child: const FrostSelectableItem<String>(item: 'Alpha', child: SizedBox(width: 100, height: 40)),
      ),
    ),
  ]);
}
