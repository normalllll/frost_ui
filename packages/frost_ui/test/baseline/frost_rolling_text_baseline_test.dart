import 'package:flutter/widgets.dart';
import 'package:frost_ui/frost_ui.dart';

import 'baseline.dart';
import 'feedback_baseline_support.dart';

const _style = TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: Color(0xffcccccc));

void main() {
  baselineGroup('FrostRollingText', [
    BaselineCase('FrostRollingText/required', (_) => const FrostRollingText('1234'), envs: BaselineEnv.all),
    BaselineCase('FrostRollingText/style', (_) => const FrostRollingText('1234', style: _style), envs: BaselineEnv.themes),
    BaselineCase('FrostRollingText/text=nonNumeric', (_) => const FrostRollingText('abc', style: _style)),
    BaselineCase('FrostRollingText/text=empty', (_) => const FrostRollingText('', style: _style)),
    // The count grows: 9 → 10 rolls the ones digit and adds the tens.
    BaselineCase(
      'FrostRollingText/required#grown',
      (_) => BaselineToggle(builder: (_, toggled) => FrostRollingText(toggled ? '10' : '9', style: _style)),
      act: baselineToggle,
    ),
    // The count shrinks: 10 → 9.
    BaselineCase(
      'FrostRollingText/required#shrunk',
      (_) => BaselineToggle(builder: (_, toggled) => FrostRollingText(toggled ? '9' : '10', style: _style)),
      act: baselineToggle,
    ),
    BaselineCase(
      'FrostRollingText/text#changed',
      (_) => BaselineToggle(builder: (_, toggled) => FrostRollingText(toggled ? '1,235' : '1,234', style: _style)),
      act: baselineToggle,
    ),
  ]);
}
