import 'package:frost_data/frost_data.dart';

import '../../../frost_ui/test/baseline/baseline.dart';
import '../../../frost_ui/test/baseline/feedback_baseline_support.dart';
import 'data_baseline_support.dart';

void main() {
  baselineGroup('FrostLoadingMoreIndicator', [
    // A loaded first page with more to come: the loading dots.
    BaselineCase(
      'FrostLoadingMoreIndicator/required',
      (_) => BaselineSourceHost(
        feed: BaselineFeed.content,
        prepare: true,
        builder: (_, source) => FrostLoadingMoreIndicator<int>(source: source),
      ),
      envs: BaselineEnv.all,
    ),
    // Every page loaded: the end-of-list text.
    BaselineCase(
      'FrostLoadingMoreIndicator/required#done',
      (_) => BaselineSourceHost(
        feed: BaselineFeed.content,
        prepare: true,
        exhaust: true,
        builder: (_, source) => FrostLoadingMoreIndicator<int>(source: source),
      ),
      envs: BaselineEnv.all,
    ),
    // The next page failed: the compact error with its retry button.
    BaselineCase(
      'FrostLoadingMoreIndicator/required#error',
      (_) => BaselineSourceHost(
        feed: BaselineFeed.footerError,
        prepare: true,
        exhaust: true,
        builder: (_, source) => FrostLoadingMoreIndicator<int>(source: source),
      ),
      envs: BaselineEnv.all,
    ),
    BaselineCase(
      'FrostLoadingMoreIndicator/required#error+open',
      (_) => BaselineSourceHost(
        feed: BaselineFeed.footerError,
        prepare: true,
        exhaust: true,
        builder: (_, source) => FrostLoadingMoreIndicator<int>(source: source),
      ),
      act: baselineTapText('L.errorDetails'),
    ),
  ]);
}
