import 'package:flutter/widgets.dart';
import 'package:frost_ui/frost_ui.dart';

import 'baseline.dart';

List<FrostFontWarmUpSample> _samples(BuildContext context) => const [
  FrostFontWarmUpSample(locale: Locale('en'), text: 'Library Settings'),
  FrostFontWarmUpSample(locale: Locale('ja'), text: 'ライブラリ設定'),
];

List<FrostFontWarmUpSample> _noSamples(BuildContext context) => const [];

void main() {
  // The widget draws only its child; the samples are shaped ahead of time.
  baselineGroup('FrostFontWarmUp', [
    BaselineCase(
      'FrostFontWarmUp/required',
      (_) => const FrostFontWarmUp(samples: _samples, child: FrostText('Library')),
      envs: BaselineEnv.all,
    ),
    BaselineCase('FrostFontWarmUp/samples=empty', (_) => const FrostFontWarmUp(samples: _noSamples, child: FrostText('Library'))),
  ]);
}
