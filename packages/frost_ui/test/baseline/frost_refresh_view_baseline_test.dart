import 'package:flutter/material.dart';
import 'package:frost_ui/frost_ui.dart';

import 'baseline.dart';
import 'feedback_baseline_support.dart';

Widget _builder(BuildContext context, ScrollPhysics? physics, FrostRefreshLocators locators) =>
    FrostLoadingScrollView(physics: physics, slivers: [?locators.sliverHeader, baselineRows()]);

void main() {
  const height = 300.0;
  baselineGroup('FrostRefreshView', [
    BaselineCase(
      'FrostRefreshView/required',
      (_) => const Scaffold(body: FrostRefreshView(builder: _builder)),
      height: height,
      envs: BaselineEnv.all,
    ),
    BaselineCase(
      'FrostRefreshView/required#drag',
      (_) => const Scaffold(body: FrostRefreshView(builder: _builder)),
      height: height,
      act: baselinePull(60),
    ),
    BaselineCase(
      'FrostRefreshView/scrollController',
      (_) => BaselineScrollHost(
        builder: (_, controller) => Scaffold(
          body: FrostRefreshView(
            scrollController: controller,
            builder: (context, physics, locators) =>
                FrostLoadingScrollView(controller: controller, physics: physics, slivers: [?locators.sliverHeader, baselineRows()]),
          ),
        ),
      ),
      height: height,
    ),
    BaselineCase(
      'FrostRefreshView/onRefresh',
      (_) => Scaffold(
        body: FrostRefreshView(onRefresh: baselineRefresh, builder: _builder),
      ),
      height: height,
      envs: BaselineEnv.themes,
    ),
    BaselineCase(
      'FrostRefreshView/onRefresh#drag',
      (_) => Scaffold(
        body: FrostRefreshView(onRefresh: baselineRefresh, builder: _builder),
      ),
      height: height,
      act: baselinePull(60),
    ),
    BaselineCase(
      'FrostRefreshView/onRefresh#armed',
      (_) => Scaffold(
        body: FrostRefreshView(onRefresh: baselineRefresh, builder: _builder),
      ),
      height: height,
      act: baselinePull(240),
    ),
    BaselineCase(
      'FrostRefreshView/onRefresh#refreshing',
      (_) => Scaffold(
        body: FrostRefreshView(onRefresh: baselineNeverRefresh, builder: _builder),
      ),
      height: height,
      act: baselineRefreshing,
      envs: BaselineEnv.themes,
    ),
  ]);
}
