import 'package:flutter/widgets.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/motion/layout_crossfade.dart' show FrostMotionSize;

import 'baseline.dart';
import 'feedback_baseline_support.dart';

const _duration = Duration(milliseconds: 180);

Widget _content(bool toggled) => SizedBox(width: toggled ? 240 : 120, height: toggled ? 100 : 40, child: const FrostText('Content'));

void main() {
  baselineGroup('FrostMotionSize', [
    BaselineCase(
      'FrostMotionSize/required',
      (_) => const FrostMotionSize(
        duration: _duration,
        child: SizedBox(width: 120, height: 40, child: FrostText('Content')),
      ),
      envs: BaselineEnv.all,
    ),
    BaselineCase(
      'FrostMotionSize/required#resized',
      (_) => BaselineToggle(
        builder: (_, toggled) => FrostMotionSize(duration: _duration, child: _content(toggled)),
      ),
      act: baselineToggle,
    ),
    BaselineCase(
      'FrostMotionSize/alignment',
      (_) => const FrostMotionSize(
        duration: _duration,
        alignment: Alignment.topLeft,
        child: SizedBox(width: 120, height: 40, child: FrostText('Content')),
      ),
    ),
    BaselineCase(
      'FrostMotionSize/alignment#resized',
      (_) => BaselineToggle(
        builder: (_, toggled) => FrostMotionSize(duration: _duration, alignment: Alignment.topLeft, child: _content(toggled)),
      ),
      act: baselineToggle,
    ),
    BaselineCase(
      'FrostMotionSize/curve',
      (_) => const FrostMotionSize(
        duration: _duration,
        curve: Curves.easeInOutCubic,
        child: SizedBox(width: 120, height: 40, child: FrostText('Content')),
      ),
    ),
    BaselineCase(
      'FrostMotionSize/curve#resized',
      (_) => BaselineToggle(
        builder: (_, toggled) => FrostMotionSize(duration: _duration, curve: Curves.easeInOutCubic, child: _content(toggled)),
      ),
      act: baselineToggle,
    ),
  ]);
}
