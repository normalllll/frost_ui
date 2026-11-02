import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/desktop.dart';

import 'baseline.dart';

const _path = 'C:/Users/me/Pictures/Frost/Exports';
const _long = 'C:/Users/someone-with-a-long-name/Pictures/Frost/Exports/2026/October/Sunset-over-the-bay';

Future<void> _choose() async {}

// Never completes: the choose button stays in its running state.
Future<void> _pending() => Completer<void>().future;

void _reveal() {}

Future<void> _tapChoose(WidgetTester tester, Finder subject) async {
  await tester.tap(find.descendant(of: subject, matching: find.text('L.choose')));
}

void main() {
  baselineGroup('FrostPathField', [
    BaselineCase(
      'FrostPathField/required',
      (_) => const FrostPathField(path: _path, label: 'Folder'),
      envs: BaselineEnv.all,
    ),
    BaselineCase('FrostPathField/path=null', (_) => const FrostPathField(path: null, label: 'Folder'), envs: BaselineEnv.themes),
    BaselineCase(
      'FrostPathField/path=long',
      (_) => const FrostPathField(path: _long, label: 'Folder'),
      envs: [BaselineEnv.standard, BaselineEnv.narrow],
    ),
    BaselineCase(
      'FrostPathField/onChoose',
      (_) => const FrostPathField(path: _path, label: 'Folder', onChoose: _choose),
      envs: BaselineEnv.all,
    ),
    BaselineCase(
      'FrostPathField/onReveal',
      (_) => const FrostPathField(path: _path, label: 'Folder', onReveal: _reveal),
      envs: BaselineEnv.themes,
    ),
    BaselineCase(
      'FrostPathField/onChoose+onReveal',
      (_) => const FrostPathField(path: _path, label: 'Folder', onChoose: _choose, onReveal: _reveal),
      envs: [BaselineEnv.standard, BaselineEnv.narrow],
    ),
    BaselineCase('FrostPathField/placeholder', (_) => const FrostPathField(path: null, label: 'Folder', placeholder: 'Choose a folder', onChoose: _choose)),
    BaselineCase('FrostPathField/help', (_) => const FrostPathField(path: _path, label: 'Folder', help: 'Exports are saved here')),
    BaselineCase(
      'FrostPathField/error',
      (_) => const FrostPathField(path: _path, label: 'Folder', error: 'The folder is missing'),
      envs: BaselineEnv.themes,
    ),
    BaselineCase(
      'FrostPathField/onChoose#hover',
      (_) => const FrostPathField(path: _path, label: 'Folder', onChoose: _choose),
      act: baselineHover,
    ),
    BaselineCase(
      'FrostPathField/onChoose#focus',
      (_) => const FrostPathField(path: _path, label: 'Folder', onChoose: _choose),
      act: baselineFocus,
    ),
    BaselineCase(
      'FrostPathField/onChoose#running',
      (_) => const FrostPathField(path: _path, label: 'Folder', onChoose: _pending),
      act: _tapChoose,
    ),
  ]);
}
