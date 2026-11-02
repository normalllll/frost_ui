import 'package:flutter/widgets.dart';
import 'package:frost_ui/frost_ui.dart';

import 'baseline.dart';
import 'feedback_baseline_support.dart';

Widget _bar(BuildContext context, double value, Widget? child) => SizedBox(
  width: 200 * value,
  height: 20,
  child: ColoredBox(color: const Color(0xff4466aa), child: child),
);

void main() {
  baselineGroup('FrostSpringBuilder', [
    BaselineCase(
      'FrostSpringBuilder/required',
      (_) => FrostSpringBuilder(value: .5, spring: FrostMotion.standard, builder: _bar),
      envs: BaselineEnv.all,
    ),
    BaselineCase('FrostSpringBuilder/spring=snappy', (_) => FrostSpringBuilder(value: .5, spring: FrostMotion.snappy, builder: _bar)),
    BaselineCase('FrostSpringBuilder/child', (_) => FrostSpringBuilder(value: .5, spring: FrostMotion.standard, builder: _bar, child: FrostText('Bar'))),
    BaselineCase(
      'FrostSpringBuilder/value#changed',
      (_) => BaselineToggle(
        builder: (_, toggled) => FrostSpringBuilder(value: toggled ? 1 : .25, spring: FrostMotion.standard, builder: _bar),
      ),
      act: baselineToggle,
    ),
    BaselineCase(
      'FrostSpringBuilder/spring=snappy#changed',
      (_) => BaselineToggle(
        builder: (_, toggled) => FrostSpringBuilder(value: toggled ? 1 : .25, spring: FrostMotion.snappy, builder: _bar),
      ),
      act: baselineToggle,
    ),
  ]);
}
