import 'package:frost_ui/frost_ui.dart';

import 'baseline.dart';

const _longValue = 'A long value that cannot sit beside its label in a narrow column and must move below it';

void main() {
  baselineGroup('FrostLabeledContent', [
    BaselineCase(
      'FrostLabeledContent/required',
      (_) => const FrostLabeledContent(label: 'Size', value: '1.2 MB'),
      envs: BaselineEnv.all,
    ),
    BaselineCase(
      'FrostLabeledContent/value=long',
      (_) => const FrostLabeledContent(label: 'Description', value: _longValue),
      envs: [BaselineEnv.standard, BaselineEnv.narrow],
    ),
    BaselineCase(
      'FrostLabeledContent/content',
      (_) => const FrostLabeledContent(
        label: 'Status',
        content: FrostStatusDot(tone: FrostStatusTone.positive, label: 'Ready'),
      ),
      envs: BaselineEnv.all,
    ),
    BaselineCase(
      'FrostLabeledContent/content=wide',
      (_) => const FrostLabeledContent(label: 'Status', content: FrostText(_longValue)),
      envs: [BaselineEnv.standard, BaselineEnv.narrow],
    ),
  ]);
}
