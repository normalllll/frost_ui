import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';

import 'baseline.dart';

void _noop() {}

const _items = ['Alpha', 'Bravo', 'Charlie', 'Delta'];
const _height = 240.0;
const _share = FrostSelectionAction(label: 'Share', icon: baselineIcon, onPressed: _noop);
const _delete = FrostSelectionAction(label: 'Delete', icon: baselineIcon, onPressed: _noop, destructive: true);
const _disabled = FrostSelectionAction(label: 'Move', icon: baselineIcon, onPressed: null);

/// A fresh selection per case so cases never share state.
FrostSelection<String> _selection({bool active = true, Set<String> selected = const {}}) {
  final selection = FrostSelection<String>();
  if (active) selection.enter();
  selected.forEach(selection.toggle);
  return selection;
}

/// The bar sits below a filling area, as the class documentation asks.
Widget _bar(FrostSelection<String> selection, {List<FrostSelectionAction> actions = const []}) => Column(
  children: [
    const Expanded(child: SizedBox.expand()),
    FrostSelectionBar<String>(selection: selection, allItems: _items, actions: actions),
  ],
);

void main() {
  baselineGroup('FrostSelectionBar', [
    BaselineCase('FrostSelectionBar/required', (_) => _bar(_selection(active: false)), height: _height),
    BaselineCase('FrostSelectionBar/required+active', (_) => _bar(_selection()), height: _height, envs: BaselineEnv.all),
    BaselineCase(
      'FrostSelectionBar/required+selected',
      (_) => _bar(_selection(selected: {'Bravo'})),
      height: _height,
      envs: BaselineEnv.themes,
    ),
    BaselineCase('FrostSelectionBar/required+allSelected', (_) => _bar(_selection(selected: {..._items})), height: _height),
    BaselineCase(
      'FrostSelectionBar/actions',
      (_) => _bar(_selection(selected: {'Bravo'}), actions: [_share, _delete]),
      height: _height,
      envs: BaselineEnv.all,
    ),
    BaselineCase('FrostSelectionBar/actions+noneSelected', (_) => _bar(_selection(), actions: [_share, _delete]), height: _height),
    BaselineCase(
      'FrostSelectionBar/actions=destructive',
      (_) => _bar(_selection(selected: {'Bravo'}), actions: [_delete]),
      height: _height,
      envs: BaselineEnv.themes,
    ),
    BaselineCase(
      'FrostSelectionBar/actions=disabled',
      (_) => _bar(_selection(selected: {'Bravo'}), actions: [_disabled]),
      height: _height,
    ),
    BaselineCase(
      'FrostSelectionBar/actions#hover',
      (_) => _bar(_selection(selected: {'Bravo'}), actions: [_share, _delete]),
      height: _height,
      act: (tester, subject) => baselineHover(tester, find.text('Share')),
    ),
    BaselineCase(
      'FrostSelectionBar/actions#press',
      (_) => _bar(_selection(selected: {'Bravo'}), actions: [_share, _delete]),
      height: _height,
      act: (tester, subject) => baselinePress(tester, find.text('Share')),
    ),
    BaselineCase(
      'FrostSelectionBar/actions#focus',
      (_) => _bar(_selection(selected: {'Bravo'}), actions: [_share, _delete]),
      height: _height,
      act: baselineFocus,
    ),
  ]);
}
