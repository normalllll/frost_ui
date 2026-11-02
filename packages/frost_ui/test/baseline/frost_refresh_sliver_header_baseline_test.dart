import 'package:flutter/material.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/feedback/refresh_indicator.dart' show FrostRefreshSliverHeader;

import 'baseline.dart';
import 'feedback_baseline_support.dart';

// The header is a sliver that reads the pull state of the refresh view above it.
Widget _view({bool never = false}) => Scaffold(
  body: FrostRefreshView(
    onRefresh: never ? baselineNeverRefresh : baselineRefresh,
    builder: (context, physics, locators) => FrostLoadingScrollView(physics: physics, slivers: [const FrostRefreshSliverHeader(), baselineRows()]),
  ),
);

void main() {
  const height = 300.0;
  baselineGroup('FrostRefreshSliverHeader', [
    BaselineCase('FrostRefreshSliverHeader/required', (_) => _view(), height: height, envs: BaselineEnv.all),
    BaselineCase('FrostRefreshSliverHeader/required#drag', (_) => _view(), height: height, act: baselinePull(60), envs: BaselineEnv.themes),
    BaselineCase('FrostRefreshSliverHeader/required#armed', (_) => _view(), height: height, act: baselinePull(240), envs: BaselineEnv.themes),
    BaselineCase('FrostRefreshSliverHeader/required#refreshing', (_) => _view(never: true), height: height, act: baselineRefreshing, envs: BaselineEnv.themes),
  ]);
}
