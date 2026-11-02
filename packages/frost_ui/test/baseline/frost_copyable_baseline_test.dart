import 'package:frost_ui/frost_ui.dart';

import 'baseline.dart';

void main() {
  baselineGroup('FrostCopyable', [
    BaselineCase('FrostCopyable/required', (_) => const FrostCopyable(text: 'abc-123-def'), envs: BaselineEnv.all),
    BaselineCase('FrostCopyable/required#focus', (_) => const FrostCopyable(text: 'abc-123-def'), act: baselineFocus),
    BaselineCase('FrostCopyable/display', (_) => const FrostCopyable(text: 'abc-123-def-456-ghi', display: 'abc...ghi')),
    BaselineCase('FrostCopyable/monospace', (_) => const FrostCopyable(text: 'abc-123-def', monospace: true), envs: BaselineEnv.themes),
    BaselineCase('FrostCopyable/display+monospace', (_) => const FrostCopyable(text: 'abc-123-def-456-ghi', display: 'abc...ghi', monospace: true)),
    BaselineCase(
      'FrostCopyable/required+long',
      (_) => const FrostCopyable(text: 'A long value that wraps across several lines when the column is narrow enough to need it'),
      envs: [BaselineEnv.narrow],
    ),
  ]);
}
