import 'package:frost_data/frost_data.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:material_ui/material_ui.dart';

import '../../../frost_ui/test/baseline/baseline.dart';
import '../../../frost_ui/test/baseline/feedback_baseline_support.dart';
import 'data_baseline_support.dart';

Widget _list(BaselineFeed feed, {Widget? empty, EdgeInsetsGeometry? padding, double? itemExtent, bool autoLoadMore = true}) => BaselineSourceHost(
  feed: feed,
  builder: (_, source) => baselineScroll([
    FrostSliverDataList<int>(
      source: source,
      itemBuilder: baselineRow,
      firstLoadSkeleton: baselineSkeleton,
      empty: empty,
      padding: padding,
      itemExtent: itemExtent,
      autoLoadMore: autoLoadMore,
    ),
  ]),
);

void main() {
  const height = 400.0;
  baselineGroup('FrostSliverDataList', [
    BaselineCase('FrostSliverDataList/required', (_) => _list(BaselineFeed.content), height: height, envs: BaselineEnv.all),
    BaselineCase('FrostSliverDataList/required#loading', (_) => _list(BaselineFeed.loading), height: height, envs: BaselineEnv.themes),
    BaselineCase('FrostSliverDataList/required#error', (_) => _list(BaselineFeed.error), height: height, envs: BaselineEnv.themes),
    BaselineCase('FrostSliverDataList/required#error+open', (_) => _list(BaselineFeed.error), height: height, act: baselineTapText('L.errorDetails')),
    BaselineCase('FrostSliverDataList/required#empty', (_) => _list(BaselineFeed.empty), height: height, envs: BaselineEnv.themes),
    BaselineCase('FrostSliverDataList/required#footerError', (_) => _list(BaselineFeed.footerError), height: height),
    BaselineCase('FrostSliverDataList/required#pending', (_) => _list(BaselineFeed.pending), height: height),
    BaselineCase(
      'FrostSliverDataList/empty',
      (_) => _list(
        BaselineFeed.empty,
        empty: const FrostEmptyState(title: 'Nothing saved yet', message: 'Saved items appear here.'),
      ),
      height: height,
    ),
    BaselineCase(
      'FrostSliverDataList/padding',
      (_) => _list(BaselineFeed.content, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
      height: height,
    ),
    BaselineCase('FrostSliverDataList/itemExtent', (_) => _list(BaselineFeed.content, itemExtent: 48), height: height),
    // Without automatic loading the footer keeps showing the pending next page.
    BaselineCase('FrostSliverDataList/autoLoadMore=false', (_) => _list(BaselineFeed.content, autoLoadMore: false), height: height),
    BaselineCase(
      'FrostSliverDataList/required#scrolled',
      (_) => BaselineSourceHost(
        feed: BaselineFeed.content,
        count: 30,
        builder: (_, source) => baselineScroll([FrostSliverDataList<int>(source: source, itemBuilder: baselineRow, firstLoadSkeleton: baselineSkeleton)]),
      ),
      height: height,
      act: baselineScrollBy(const Offset(0, -2000)),
    ),
  ]);
}
