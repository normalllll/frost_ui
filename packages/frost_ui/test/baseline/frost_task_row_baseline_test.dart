import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';

import 'baseline.dart';

void _noop() {}

const _thumbnail = SizedBox.square(
  dimension: 48,
  child: DecoratedBox(decoration: BoxDecoration(color: Color(0xFF3366CC))),
);
const _action1 = FrostTaskAction(label: 'Pause', icon: baselineIcon, onPressed: _noop);
const _action2 = FrostTaskAction(label: 'Cancel', icon: baselineIcon, onPressed: _noop);
const _action3 = FrostTaskAction(label: 'Open folder', icon: baselineIcon, onPressed: _noop);
final _menu = [FrostMenuAction('Copy link', onSelected: _noop)];

BaselineCase _row(String id, WidgetBuilder builder, {List<BaselineEnv> envs = const [BaselineEnv.standard], BaselineAct? act}) =>
    BaselineCase(id, builder, envs: envs, act: act);

/// Opens the context menu with a secondary mouse click on the subject.
Future<void> _secondaryClick(WidgetTester tester, Finder subject) async {
  final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse, buttons: kSecondaryMouseButton);
  await mouse.down(tester.getCenter(subject));
  await mouse.up();
}

void main() {
  baselineGroup('FrostTaskRow', [
    _row(
      'FrostTaskRow/required',
      (_) => const FrostTaskRow(title: 'Download', status: FrostTaskStatus.queued),
      envs: BaselineEnv.all,
    ),
    for (final status in FrostTaskStatus.values)
      _row(
        'FrostTaskRow/status=${status.name}',
        (_) => FrostTaskRow(title: 'Download', status: status),
        envs: BaselineEnv.themes,
      ),
    _row(
      'FrostTaskRow/detail',
      (_) => const FrostTaskRow(title: 'Download', status: FrostTaskStatus.completed, detail: '12.4 MB in 3 s'),
      envs: BaselineEnv.all,
    ),
    _row(
      'FrostTaskRow/selected',
      (_) => const FrostTaskRow(title: 'Download', status: FrostTaskStatus.completed, detail: '12.4 MB in 3 s', selected: true),
      envs: BaselineEnv.themes,
    ),
    for (final status in [FrostTaskStatus.running, FrostTaskStatus.paused])
      _row(
        'FrostTaskRow/status=${status.name}+progress',
        (_) => FrostTaskRow(title: 'Download', status: status, detail: '4.2 of 12.4 MB', progress: .4),
        envs: BaselineEnv.themes,
      ),
    _row(
      'FrostTaskRow/status=completed+progress',
      (_) => const FrostTaskRow(title: 'Download', status: FrostTaskStatus.completed, detail: '12.4 MB', progress: .4),
    ),
    _row(
      'FrostTaskRow/progress+progressPlacement=belowDetail',
      (_) => const FrostTaskRow(
        title: 'Download',
        status: FrostTaskStatus.running,
        detail: '4.2 of 12.4 MB',
        progress: .4,
        progressPlacement: FrostTaskProgressPlacement.belowDetail,
      ),
    ),
    _row(
      'FrostTaskRow/thumbnail',
      (_) => const FrostTaskRow(title: 'Download', status: FrostTaskStatus.completed, detail: '12.4 MB', thumbnail: _thumbnail),
      envs: BaselineEnv.themes,
    ),
    _row('FrostTaskRow/showsStatusDot=false', (_) => const FrostTaskRow(title: 'Download', status: FrostTaskStatus.completed, showsStatusDot: false)),
    _row(
      'FrostTaskRow/actions=1',
      (_) => const FrostTaskRow(title: 'Download', status: FrostTaskStatus.running, actions: [_action1]),
      envs: BaselineEnv.themes,
    ),
    _row('FrostTaskRow/actions=2', (_) => const FrostTaskRow(title: 'Download', status: FrostTaskStatus.running, actions: [_action1, _action2])),
    _row('FrostTaskRow/actions=3', (_) => const FrostTaskRow(title: 'Download', status: FrostTaskStatus.running, actions: [_action1, _action2, _action3])),
    _row(
      'FrostTaskRow/actions=3#open',
      (_) => const FrostTaskRow(title: 'Download', status: FrostTaskStatus.running, actions: [_action1, _action2, _action3]),
      act: _secondaryClick,
    ),
    _row(
      'FrostTaskRow/trailing',
      (_) => const FrostTaskRow(
        title: 'Download',
        status: FrostTaskStatus.completed,
        trailing: FrostButton.icon(icon: baselineIcon, label: 'More', onPressed: _noop),
      ),
    ),
    _row(
      'FrostTaskRow/longTitle+detail+actions',
      (_) => const FrostTaskRow(
        title: 'A download with a title that is far too long to fit on one line',
        status: FrostTaskStatus.running,
        detail: 'A long detail text that has to wrap onto another line in narrow widths',
        progress: .4,
        thumbnail: _thumbnail,
        actions: [_action1, _action2],
      ),
      envs: [BaselineEnv.narrow, BaselineEnv.largeText],
    ),
    _row(
      'FrostTaskRow/onPressed',
      (_) => const FrostTaskRow(title: 'Download', status: FrostTaskStatus.completed, onPressed: _noop),
      envs: [BaselineEnv.standard, BaselineEnv.touch],
    ),
    _row(
      'FrostTaskRow/onPressed#hover',
      (_) => const FrostTaskRow(title: 'Download', status: FrostTaskStatus.completed, onPressed: _noop),
      act: baselineHover,
    ),
    _row(
      'FrostTaskRow/onPressed#press',
      (_) => const FrostTaskRow(title: 'Download', status: FrostTaskStatus.completed, onPressed: _noop),
      act: baselinePress,
    ),
    _row(
      'FrostTaskRow/onPressed#focus',
      (_) => const FrostTaskRow(title: 'Download', status: FrostTaskStatus.completed, onPressed: _noop),
      act: baselineFocus,
    ),
    _row('FrostTaskRow/contextMenu', (_) => FrostTaskRow(title: 'Download', status: FrostTaskStatus.completed, contextMenu: _menu)),
    _row(
      'FrostTaskRow/contextMenu#open',
      (_) => FrostTaskRow(title: 'Download', status: FrostTaskStatus.completed, contextMenu: _menu),
      act: _secondaryClick,
    ),
  ]);
}
