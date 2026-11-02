import 'package:flutter/material.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/feedback/refresh_view.dart' show FrostNestedRefreshContext;

import 'baseline.dart';
import 'feedback_baseline_support.dart';

Widget _builder(BuildContext context, FrostNestedRefreshContext refresh) => CustomScrollView(
  controller: refresh.scrollController,
  physics: refresh.physics,
  slivers: [
    ?refresh.locators.sliverHeader,
    const SliverToBoxAdapter(child: SizedBox(height: 100, child: Text('Header'))),
    baselineRows(),
  ],
);

void main() {
  const height = 300.0;
  final touch = BaselineEnv.touch;
  baselineGroup('FrostNestedRefreshView', [
    BaselineCase(
      'FrostNestedRefreshView/required',
      (_) => const Scaffold(body: FrostNestedRefreshView(builder: _builder)),
      height: height,
      envs: BaselineEnv.all,
    ),
    BaselineCase(
      'FrostNestedRefreshView/onRefresh',
      (_) => Scaffold(
        body: FrostNestedRefreshView(onRefresh: baselineRefresh, builder: _builder),
      ),
      height: height,
      envs: BaselineEnv.themes,
    ),
    BaselineCase(
      'FrostNestedRefreshView/onRefresh#drag',
      (_) => Scaffold(
        body: FrostNestedRefreshView(onRefresh: baselineRefresh, builder: _builder),
      ),
      height: height,
      act: baselinePull(60),
    ),
    BaselineCase(
      'FrostNestedRefreshView/onRefresh#refreshing',
      (_) => Scaffold(
        body: FrostNestedRefreshView(onRefresh: baselineNeverRefresh, builder: _builder),
      ),
      height: height,
      act: baselineRefreshing,
      envs: BaselineEnv.themes,
    ),
    BaselineCase(
      'FrostNestedRefreshView/headerSnapExtent',
      (_) => const Scaffold(body: FrostNestedRefreshView(headerSnapExtent: 100, builder: _builder)),
      height: height,
    ),
    // A touch drag past the trigger extent snaps the header away.
    BaselineCase(
      'FrostNestedRefreshView/headerSnapExtent#scrolled',
      (_) => const Scaffold(body: FrostNestedRefreshView(headerSnapExtent: 100, builder: _builder)),
      height: height,
      act: baselineScrollBy(const Offset(0, -80)),
      envs: [touch],
    ),
    BaselineCase(
      'FrostNestedRefreshView/headerMobileSnapTriggerExtent',
      (_) => const Scaffold(body: FrostNestedRefreshView(headerSnapExtent: 100, headerMobileSnapTriggerExtent: 24, builder: _builder)),
      height: height,
    ),
    BaselineCase(
      'FrostNestedRefreshView/headerMobileSnapTriggerExtent#scrolled',
      (_) => const Scaffold(body: FrostNestedRefreshView(headerSnapExtent: 100, headerMobileSnapTriggerExtent: 24, builder: _builder)),
      height: height,
      act: baselineScrollBy(const Offset(0, -40)),
      envs: [touch],
    ),
  ]);
}
