import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';

import 'baseline.dart';
import 'nav_overlay_support.dart';

void _noop() {}

const _h = 600.0;

const _primary = ColoredBox(
  color: Color(0xFF203040),
  child: Align(alignment: Alignment.topLeft, child: Text('Primary')),
);
const _secondary = Column(
  children: [
    FrostPageHeader(title: Text('Detail')),
    Expanded(child: Center(child: Text('Secondary'))),
  ],
);

Widget _split({Widget? secondary, VoidCallback? onCloseSecondary = _noop, double? initialPrimaryWidth, bool? resizable}) => windowed(
  FrostSplitView(
    primary: _primary,
    secondary: secondary,
    onCloseSecondary: onCloseSecondary,
    initialPrimaryWidth: initialPrimaryWidth ?? 320,
    resizable: resizable ?? true,
  ),
);

BaselineCase _case(String id, Widget Function() build, {List<BaselineEnv> envs = const [wide, narrow], BaselineAct? act}) =>
    BaselineCase(id, (_) => build(), height: _h, envs: envs, act: act);

// Drags the divider 60 pixels to the right.
Future<void> _drag(WidgetTester tester, Finder subject) async {
  final origin = tester.getTopLeft(subject);
  await tester.dragFrom(origin + const Offset(320, 200), const Offset(60, 0));
}

Future<void> _hoverDivider(WidgetTester tester, Finder subject) async {
  final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await gesture.addPointer(location: Offset.zero);
  addTearDown(gesture.removePointer);
  await gesture.moveTo(tester.getTopLeft(subject) + const Offset(320, 200));
}

void main() {
  baselineGroup('FrostSplitView', [
    _case('FrostSplitView/required', () => _split(onCloseSecondary: null), envs: pageEnvs),
    _case('FrostSplitView/onCloseSecondary', () => _split(), envs: pageEnvs),
    _case(
      'FrostSplitView/secondary',
      () => _split(secondary: _secondary),
      envs: [
        ...pageEnvs,
        wide.copyWith(brightness: Brightness.light),
      ],
    ),
    _case('FrostSplitView/secondary+onCloseSecondary=null', () => _split(secondary: _secondary, onCloseSecondary: null), envs: [wide, narrow]),
    _case(
      'FrostSplitView/secondary#hover',
      () => _split(secondary: _secondary),
      act: _hoverDivider,
      envs: [wide],
    ),
    _case(
      'FrostSplitView/secondary#focus',
      () => _split(secondary: _secondary),
      act: baselineFocus,
      envs: [wide],
    ),
    _case(
      'FrostSplitView/secondary#resize',
      () => _split(secondary: _secondary),
      act: _drag,
      envs: [wide],
    ),
    _case('FrostSplitView/initialPrimaryWidth=240', () => _split(secondary: _secondary, initialPrimaryWidth: 240), envs: [wide, medium]),
    _case('FrostSplitView/initialPrimaryWidth=400', () => _split(secondary: _secondary, initialPrimaryWidth: 400), envs: [wide, medium]),
    _case('FrostSplitView/initialPrimaryWidth=100', () => _split(secondary: _secondary, initialPrimaryWidth: 100), envs: [wide]),
    _case('FrostSplitView/initialPrimaryWidth=600', () => _split(secondary: _secondary, initialPrimaryWidth: 600), envs: [wide]),
    _case('FrostSplitView/resizable=false', () => _split(secondary: _secondary, resizable: false), envs: [wide, medium]),
    _case(
      'FrostSplitView/resizable=false#resize',
      () => _split(secondary: _secondary, resizable: false),
      act: _drag,
      envs: [wide],
    ),
  ]);
}
