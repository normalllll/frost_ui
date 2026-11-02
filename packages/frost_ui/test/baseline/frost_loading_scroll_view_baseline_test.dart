import 'package:flutter/material.dart';
import 'package:frost_ui/frost_ui.dart';

import 'baseline.dart';
import 'feedback_baseline_support.dart';

Widget _scroll({
  ScrollController? controller,
  ScrollPhysics? physics,
  bool? primary,
  bool shrinkWrap = false,
  double? cacheExtent,
  double preloadExtent = 480,
  Clip clipBehavior = Clip.hardEdge,
}) => Scaffold(
  body: FrostLoadingScrollView(
    slivers: [baselineRows(count: 60)],
    controller: controller,
    physics: physics,
    primary: primary,
    shrinkWrap: shrinkWrap,
    cacheExtent: cacheExtent,
    preloadExtent: preloadExtent,
    clipBehavior: clipBehavior,
  ),
);

void main() {
  const height = 300.0;
  baselineGroup('FrostLoadingScrollView', [
    BaselineCase(
      'FrostLoadingScrollView/required',
      (_) => Scaffold(body: FrostLoadingScrollView(slivers: [baselineRows(count: 60)])),
      height: height,
      envs: BaselineEnv.all,
    ),
    BaselineCase(
      'FrostLoadingScrollView/required#scrolled',
      (_) => Scaffold(body: FrostLoadingScrollView(slivers: [baselineRows(count: 60)])),
      height: height,
      act: baselineScrollBy(const Offset(0, -200)),
    ),
    BaselineCase(
      'FrostLoadingScrollView/controller',
      (_) => BaselineScrollHost(builder: (_, controller) => _scroll(controller: controller)),
      height: height,
    ),
    BaselineCase('FrostLoadingScrollView/physics', (_) => _scroll(physics: const BouncingScrollPhysics()), height: height),
    BaselineCase('FrostLoadingScrollView/primary=false', (_) => _scroll(primary: false), height: height),
    BaselineCase('FrostLoadingScrollView/primary=true', (_) => _scroll(primary: true), height: height),
    BaselineCase('FrostLoadingScrollView/shrinkWrap', (_) => _scroll(shrinkWrap: true), height: height),
    BaselineCase('FrostLoadingScrollView/cacheExtent', (_) => _scroll(cacheExtent: 1200), height: height),
    BaselineCase('FrostLoadingScrollView/preloadExtent', (_) => _scroll(preloadExtent: 0), height: height),
    BaselineCase('FrostLoadingScrollView/clipBehavior', (_) => _scroll(clipBehavior: Clip.none), height: height),
  ]);
}
