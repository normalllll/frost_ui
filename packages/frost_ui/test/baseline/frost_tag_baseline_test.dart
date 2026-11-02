import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';

import 'baseline.dart';

void _noop() {}

const _pointerAndTouch = [BaselineEnv.standard, BaselineEnv.touch];
const _menu = [FrostMenuAction('Copy', onSelected: _noop), FrostMenuAction('Hide', onSelected: _noop)];

Future<void> _secondaryTap(WidgetTester tester, Finder subject) => tester.tap(subject, buttons: kSecondaryButton);

void main() {
  baselineGroup('FrostTag', [
    BaselineCase('FrostTag/required', (_) => const FrostTag(label: 'landscape'), envs: BaselineEnv.all),
    BaselineCase(
      'FrostTag/label=long',
      (_) => const FrostTag(label: 'a tag with a very long name that cannot fit into the maximum tag width of two hundred forty points'),
      envs: [BaselineEnv.standard, BaselineEnv.largeText],
    ),
    BaselineCase(
      'FrostTag/detail',
      (_) => const FrostTag(label: 'landscape', detail: '1,204'),
      envs: BaselineEnv.themes,
    ),
    BaselineCase(
      'FrostTag/onPressed',
      (_) => const FrostTag(label: 'landscape', onPressed: _noop),
      envs: BaselineEnv.all,
    ),
    BaselineCase(
      'FrostTag/onPressed#hover',
      (_) => const FrostTag(label: 'landscape', onPressed: _noop),
      act: baselineHover,
    ),
    BaselineCase(
      'FrostTag/onPressed#press',
      (_) => const FrostTag(label: 'landscape', onPressed: _noop),
      act: baselinePress,
    ),
    BaselineCase(
      'FrostTag/onPressed#focus',
      (_) => const FrostTag(label: 'landscape', onPressed: _noop),
      act: baselineFocus,
    ),
    BaselineCase(
      'FrostTag/selected=true',
      (_) => const FrostTag(label: 'landscape', selected: true, onPressed: _noop),
      envs: BaselineEnv.themes,
    ),
    BaselineCase(
      'FrostTag/selected=false',
      (_) => const FrostTag(label: 'landscape', selected: false, onPressed: _noop),
      envs: BaselineEnv.themes,
    ),
    BaselineCase(
      'FrostTag/selected=true#hover',
      (_) => const FrostTag(label: 'landscape', selected: true, onPressed: _noop),
      act: baselineHover,
    ),
    BaselineCase('FrostTag/dataColor', (_) => const FrostTag(label: 'landscape', dataColor: 2), envs: BaselineEnv.themes),
    BaselineCase('FrostTag/dataColor+detail+onPressed', (_) => const FrostTag(label: 'landscape', detail: '1,204', dataColor: 2, onPressed: _noop)),
    BaselineCase('FrostTag/contextMenu', (_) => const FrostTag(label: 'landscape', contextMenu: _menu)),
    BaselineCase(
      'FrostTag/contextMenu#open',
      (_) => const FrostTag(label: 'landscape', contextMenu: _menu),
      act: _secondaryTap,
    ),
    for (final size in FrostControlSize.values)
      BaselineCase(
        'FrostTag/size=${size.name}',
        (_) => FrostTag(label: 'landscape', size: size),
        envs: _pointerAndTouch,
      ),
    BaselineCase(
      'FrostTag/icon',
      (_) => const FrostTag(label: 'landscape', icon: baselineIcon),
      envs: BaselineEnv.themes,
    ),
    BaselineCase(
      'FrostTag/style=topic',
      (_) => const FrostTag(label: 'landscape', style: FrostTagStyle.topic),
      envs: BaselineEnv.themes,
    ),
    BaselineCase(
      'FrostTag/style=topic+onPressed',
      (_) => const FrostTag(label: 'landscape', style: FrostTagStyle.topic, onPressed: _noop),
      envs: _pointerAndTouch,
    ),
    BaselineCase(
      'FrostTag/style=topic+onPressed#hover',
      (_) => const FrostTag(label: 'landscape', style: FrostTagStyle.topic, onPressed: _noop),
      act: baselineHover,
    ),
    BaselineCase(
      'FrostTag/style=topic+onPressed#press',
      (_) => const FrostTag(label: 'landscape', style: FrostTagStyle.topic, onPressed: _noop),
      act: baselinePress,
    ),
    BaselineCase('FrostTag/style=topic+selected=true', (_) => const FrostTag(label: 'landscape', style: FrostTagStyle.topic, selected: true, onPressed: _noop)),
    BaselineCase('FrostTag.skeleton/required', (_) => FrostTag.skeleton(label: 'landscape'), envs: BaselineEnv.all),
  ]);
}
