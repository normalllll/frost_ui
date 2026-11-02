import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/feedback/refresh_dots.dart' show FrostDotsRefreshIndicator;

import 'baseline.dart';
import 'feedback_baseline_support.dart';

Future<void> _done() async {}

Future<void> _never() => Completer<void>().future;

Widget _list() => ListView(children: [for (var i = 0; i < 20; i++) SizedBox(height: 40, child: FrostText('Row $i'))]);

void main() {
  const height = 300.0;
  baselineGroup('FrostDotsRefreshIndicator', [
    BaselineCase(
      'FrostDotsRefreshIndicator/required',
      (_) => FrostDotsRefreshIndicator(onRefresh: _done, child: _list()),
      height: height,
      envs: BaselineEnv.all,
    ),
    BaselineCase(
      'FrostDotsRefreshIndicator/required#refreshing',
      (_) => FrostDotsRefreshIndicator(onRefresh: _never, child: _list()),
      height: height,
      act: baselineScrollBy(const Offset(0, 300)),
      envs: BaselineEnv.themes,
    ),
  ]);
}
