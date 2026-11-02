import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';

import 'baseline.dart';

void _noop() {}

const _child = FrostListRow(title: 'Title', subtitle: FrostRowSubtitle('Subtitle'), onPressed: _noop);
const _pin = FrostSwipeAction(label: 'Pin', icon: baselineIcon, onPressed: _noop);
const _mute = FrostSwipeAction(label: 'Mute', icon: baselineIcon, onPressed: _noop, tone: FrostSwipeTone.accent);
const _delete = FrostSwipeAction(label: 'Delete', icon: baselineIcon, onPressed: _noop, tone: FrostSwipeTone.destructive);

/// Drags the row by [dx] with a finger, then lets the swipe settle.
BaselineAct _swipe(double dx) => (tester, subject) async {
  await tester.drag(find.text('Title'), Offset(dx, 0));
};

void main() {
  baselineGroup('FrostSwipeActions', [
    BaselineCase('FrostSwipeActions/required', (_) => const FrostSwipeActions(child: _child), envs: BaselineEnv.all),
    BaselineCase(
      'FrostSwipeActions/leading',
      (_) => const FrostSwipeActions(leading: [_pin], child: _child),
      envs: BaselineEnv.themes,
    ),
    BaselineCase(
      'FrostSwipeActions/trailing',
      (_) => const FrostSwipeActions(trailing: [_delete], child: _child),
      envs: BaselineEnv.themes,
    ),
    BaselineCase('FrostSwipeActions/leading+trailing', (_) => const FrostSwipeActions(leading: [_pin], trailing: [_mute, _delete], child: _child)),
    BaselineCase(
      'FrostSwipeActions/trailing#hover',
      (_) => const FrostSwipeActions(trailing: [_mute, _delete], child: _child),
      act: baselineHover,
      envs: BaselineEnv.themes,
    ),
    BaselineCase(
      'FrostSwipeActions/leading+trailing#hover',
      (_) => const FrostSwipeActions(leading: [_pin], trailing: [_mute, _delete], child: _child),
      act: baselineHover,
    ),
    BaselineCase(
      'FrostSwipeActions/trailing#focus',
      (_) => const FrostSwipeActions(trailing: [_mute, _delete], child: _child),
      act: baselineFocus,
    ),
    BaselineCase(
      'FrostSwipeActions/showsPointerActions=false#hover',
      (_) => const FrostSwipeActions(trailing: [_mute, _delete], showsPointerActions: false, child: _child),
      act: baselineHover,
    ),
    BaselineCase(
      'FrostSwipeActions/trailing#swipeOpen',
      (_) => const FrostSwipeActions(trailing: [_mute, _delete], child: _child),
      act: _swipe(-160),
      envs: [
        BaselineEnv.touch,
        BaselineEnv.touch.copyWith(brightness: Brightness.light),
      ],
    ),
    BaselineCase(
      'FrostSwipeActions/leading#swipeOpen',
      (_) => const FrostSwipeActions(leading: [_pin], child: _child),
      act: _swipe(160),
      envs: [BaselineEnv.touch],
    ),
    BaselineCase(
      'FrostSwipeActions/leading+trailing#swipeFull',
      (_) => const FrostSwipeActions(leading: [_pin], trailing: [_delete], child: _child),
      act: _swipe(-500),
      envs: [BaselineEnv.touch],
    ),
  ]);
}
