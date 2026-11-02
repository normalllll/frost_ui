import 'package:flutter/material.dart';
import 'package:frost_data/frost_data.dart';
import 'package:frost_ui/frost_ui.dart';

import '../../../frost_ui/test/baseline/baseline.dart';
import '../../../frost_ui/test/baseline/feedback_baseline_support.dart';
import 'data_baseline_support.dart';

// Unset arguments pass the constructor's own defaults.
Widget _grid(
  BaselineFeed feed, {
  Widget? empty,
  double? preferredTileWidth,
  double? crossAxisSpacing,
  double? mainAxisSpacing,
  EdgeInsetsGeometry? padding,
  int? columns,
  int? maxColumns,
  bool autoLoadMore = true,
}) => BaselineSourceHost(
  feed: feed,
  builder: (_, source) => baselineScroll([
    FrostSliverDataWaterfallGrid<int>(
      source: source,
      itemBuilder: baselineTile,
      firstLoadSkeleton: baselineSkeleton,
      empty: empty,
      preferredTileWidth: preferredTileWidth ?? FrostMetrics.gridExtent,
      crossAxisSpacing: crossAxisSpacing ?? FrostGap.grid,
      mainAxisSpacing: mainAxisSpacing ?? FrostGap.grid,
      padding: padding,
      columns: columns,
      maxColumns: maxColumns,
      autoLoadMore: autoLoadMore,
    ),
  ]),
);

void main() {
  const height = 480.0;
  final widths = [BaselineEnv.standard, BaselineEnv.narrow];
  baselineGroup('FrostSliverDataWaterfallGrid', [
    BaselineCase('FrostSliverDataWaterfallGrid/required', (_) => _grid(BaselineFeed.content), height: height, envs: BaselineEnv.all),
    BaselineCase('FrostSliverDataWaterfallGrid/required#loading', (_) => _grid(BaselineFeed.loading), height: height),
    BaselineCase('FrostSliverDataWaterfallGrid/required#error', (_) => _grid(BaselineFeed.error), height: height),
    BaselineCase('FrostSliverDataWaterfallGrid/required#empty', (_) => _grid(BaselineFeed.empty), height: height),
    BaselineCase(
      'FrostSliverDataWaterfallGrid/empty',
      (_) => _grid(BaselineFeed.empty, empty: const FrostEmptyState(title: 'Nothing saved yet')),
      height: height,
    ),
    BaselineCase('FrostSliverDataWaterfallGrid/preferredTileWidth', (_) => _grid(BaselineFeed.content, preferredTileWidth: 120), height: height, envs: widths),
    BaselineCase('FrostSliverDataWaterfallGrid/crossAxisSpacing', (_) => _grid(BaselineFeed.content, crossAxisSpacing: 24), height: height),
    BaselineCase('FrostSliverDataWaterfallGrid/mainAxisSpacing', (_) => _grid(BaselineFeed.content, mainAxisSpacing: 24), height: height),
    BaselineCase('FrostSliverDataWaterfallGrid/padding', (_) => _grid(BaselineFeed.content, padding: const EdgeInsets.all(24)), height: height),
    BaselineCase('FrostSliverDataWaterfallGrid/columns', (_) => _grid(BaselineFeed.content, columns: 2), height: height, envs: widths),
    BaselineCase('FrostSliverDataWaterfallGrid/maxColumns', (_) => _grid(BaselineFeed.content, maxColumns: 2), height: height, envs: widths),
    BaselineCase('FrostSliverDataWaterfallGrid/autoLoadMore=false', (_) => _grid(BaselineFeed.content, autoLoadMore: false), height: height),
  ]);
}
