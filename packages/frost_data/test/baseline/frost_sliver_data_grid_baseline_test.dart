import 'package:flutter/material.dart';
import 'package:frost_data/frost_data.dart';
import 'package:frost_ui/frost_ui.dart';

import '../../../frost_ui/test/baseline/baseline.dart';
import '../../../frost_ui/test/baseline/feedback_baseline_support.dart';
import 'data_baseline_support.dart';

double _tileHeight(BuildContext context, double tileWidth) => 96;

// An unset spacing passes the constructor's own default.
Widget _grid(BaselineFeed feed, {Widget? empty, double minTileWidth = 160, double? spacing}) => BaselineSourceHost(
  feed: feed,
  builder: (_, source) => baselineScroll([
    FrostSliverDataGrid<int>(
      source: source,
      itemBuilder: baselineTile,
      firstLoadSkeleton: baselineSkeleton,
      empty: empty,
      minTileWidth: minTileWidth,
      tileHeight: _tileHeight,
      spacing: spacing ?? FrostGap.grid,
    ),
  ]),
);

void main() {
  const height = 480.0;
  final widths = [BaselineEnv.standard, BaselineEnv.narrow];
  baselineGroup('FrostSliverDataGrid', [
    BaselineCase('FrostSliverDataGrid/required', (_) => _grid(BaselineFeed.content), height: height, envs: BaselineEnv.all),
    BaselineCase('FrostSliverDataGrid/required#loading', (_) => _grid(BaselineFeed.loading), height: height),
    BaselineCase('FrostSliverDataGrid/required#error', (_) => _grid(BaselineFeed.error), height: height),
    BaselineCase('FrostSliverDataGrid/required#empty', (_) => _grid(BaselineFeed.empty), height: height),
    BaselineCase(
      'FrostSliverDataGrid/empty',
      (_) => _grid(BaselineFeed.empty, empty: const FrostEmptyState(title: 'Nothing saved yet')),
      height: height,
    ),
    BaselineCase('FrostSliverDataGrid/minTileWidth', (_) => _grid(BaselineFeed.content, minTileWidth: 260), height: height, envs: widths),
    BaselineCase('FrostSliverDataGrid/spacing', (_) => _grid(BaselineFeed.content, spacing: 24), height: height),
  ]);
}
