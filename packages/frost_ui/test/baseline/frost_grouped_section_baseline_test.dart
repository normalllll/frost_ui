import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';

import 'baseline.dart';

void _noop() {}

const _rows = [
  FrostListRow(title: 'First', onPressed: _noop),
  FrostListRow(title: 'Second', subtitle: FrostRowSubtitle('Subtitle'), onPressed: _noop),
  FrostListRow(title: 'Third', value: 'Value', onPressed: _noop),
];

void main() {
  baselineGroup('FrostGroupedSection', [
    BaselineCase('FrostGroupedSection/required', (_) => const FrostGroupedSection(children: _rows), envs: BaselineEnv.all),
    BaselineCase(
      'FrostGroupedSection/required+singleRow',
      (_) => const FrostGroupedSection(
        children: [FrostListRow(title: 'Only', onPressed: _noop)],
      ),
    ),
    BaselineCase('FrostGroupedSection/required+empty', (_) => const FrostGroupedSection(children: [])),
    BaselineCase(
      'FrostGroupedSection/header',
      (_) => const FrostGroupedSection(header: 'Header', children: _rows),
      envs: BaselineEnv.themes,
    ),
    BaselineCase(
      'FrostGroupedSection/footer',
      (_) => const FrostGroupedSection(footer: 'Footer', children: _rows),
      envs: BaselineEnv.themes,
    ),
    BaselineCase(
      'FrostGroupedSection/header+footer',
      (_) => const FrostGroupedSection(header: 'Header', footer: 'Footer', children: _rows),
      envs: [BaselineEnv.standard, BaselineEnv.largeText],
    ),
    BaselineCase(
      'FrostGroupedSection/required#hover',
      (_) => const FrostGroupedSection(children: _rows),
      act: (tester, subject) => baselineHover(tester, find.text('Second')),
    ),
  ]);
}
