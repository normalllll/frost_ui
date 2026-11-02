import 'package:frost_ui/frost_ui.dart';

import 'baseline.dart';

const _source = 'final answer = compute(42);\nprint(answer);';
const _long = 'SomeVeryLongIdentifierThatDoesNotFitInTheNarrowColumn_withMoreSegments_andMore_thanThreeHundredSixtyPixelsOfWidth';

void main() {
  baselineGroup('FrostCodeBlock', [
    BaselineCase('FrostCodeBlock/required', (_) => const FrostCodeBlock(text: _source), envs: BaselineEnv.all),
    BaselineCase('FrostCodeBlock/required#focus', (_) => const FrostCodeBlock(text: _source), act: baselineFocus),
    BaselineCase('FrostCodeBlock/copyable=false', (_) => const FrostCodeBlock(text: _source, copyable: false), envs: BaselineEnv.themes),
    BaselineCase('FrostCodeBlock/wrap=none+long', (_) => const FrostCodeBlock(text: _long), envs: [BaselineEnv.narrow]),
    BaselineCase(
      'FrostCodeBlock/wrap=anywhere',
      (_) => const FrostCodeBlock(text: _long, wrap: FrostCodeWrap.anywhere),
      envs: [BaselineEnv.standard, BaselineEnv.narrow],
    ),
    BaselineCase(
      'FrostCodeBlock/wrap=anywhere+copyable=false',
      (_) => const FrostCodeBlock(text: _long, copyable: false, wrap: FrostCodeWrap.anywhere),
      envs: [BaselineEnv.narrow],
    ),
  ]);
}
