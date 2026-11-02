import 'package:frost_ui/frost_ui.dart';

import 'baseline.dart';

const _entries = [
  FrostKeyValue(label: 'Size', value: '1.2 MB'),
  FrostKeyValue(label: 'Format', value: 'PNG'),
  FrostKeyValue(label: 'Created', value: '2024-05-01'),
];

const _path = FrostKeyValue.path(label: 'Path', value: r'D:\Pictures\Gallery\2024\05\a-rather-long-file-name-for-testing-wrapping.png');

void main() {
  baselineGroup('FrostKeyValueList', [
    BaselineCase('FrostKeyValueList/required', (_) => const FrostKeyValueList(entries: _entries), envs: BaselineEnv.all),
    BaselineCase('FrostKeyValueList/dividers', (_) => const FrostKeyValueList(entries: _entries, dividers: true), envs: BaselineEnv.themes),
    BaselineCase(
      'FrostKeyValueList/entries=path',
      (_) => const FrostKeyValueList(entries: [..._entries, _path]),
      envs: [BaselineEnv.standard, BaselineEnv.narrow],
    ),
    BaselineCase(
      'FrostKeyValueList/entries=path+dividers',
      (_) => const FrostKeyValueList(entries: [..._entries, _path], dividers: true),
      envs: [BaselineEnv.narrow],
    ),
    BaselineCase('FrostKeyValueList/entries=empty', (_) => const FrostKeyValueList(entries: [])),
  ]);
}
