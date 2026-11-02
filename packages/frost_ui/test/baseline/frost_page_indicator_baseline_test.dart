import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/media.dart';

import 'baseline.dart';

void _select(int _) {}

// onMedia indicators are drawn for dark photos: a dark backdrop makes them visible.
Widget _backdrop(Widget child) => ColoredBox(
  color: const Color(0xFF404040),
  child: Padding(padding: const EdgeInsets.all(8), child: child),
);

Future<void> _tapSecond(WidgetTester tester, Finder subject) async {
  final box = tester.getRect(find.descendant(of: subject, matching: find.byType(FrostPageIndicator)));
  await tester.tapAt(Offset(box.left + box.width * .75, box.center.dy));
}

void main() {
  baselineGroup('FrostPageIndicator', [
    BaselineCase('FrostPageIndicator/required', (_) => const FrostPageIndicator(count: 4, current: 1), envs: BaselineEnv.all),
    BaselineCase('FrostPageIndicator/count=0', (_) => const FrostPageIndicator(count: 0, current: 0)),
    BaselineCase('FrostPageIndicator/count=1', (_) => const FrostPageIndicator(count: 1, current: 0)),
    BaselineCase('FrostPageIndicator/count=2', (_) => const FrostPageIndicator(count: 2, current: 0)),
    BaselineCase('FrostPageIndicator/current=last', (_) => const FrostPageIndicator(count: 5, current: 4), envs: BaselineEnv.themes),
    BaselineCase('FrostPageIndicator/count=10', (_) => const FrostPageIndicator(count: 10, current: 3)),
    BaselineCase('FrostPageIndicator/count=11', (_) => const FrostPageIndicator(count: 11, current: 3), envs: [BaselineEnv.standard, BaselineEnv.largeText]),
    BaselineCase('FrostPageIndicator/onSelected', (_) => const FrostPageIndicator(count: 4, current: 1, onSelected: _select), envs: BaselineEnv.all),
    BaselineCase('FrostPageIndicator/onSelected#hover', (_) => const FrostPageIndicator(count: 4, current: 1, onSelected: _select), act: baselineHover),
    BaselineCase('FrostPageIndicator/onSelected#press', (_) => const FrostPageIndicator(count: 4, current: 1, onSelected: _select), act: baselinePress),
    BaselineCase('FrostPageIndicator/onSelected#select', (_) => const FrostPageIndicator(count: 4, current: 1, onSelected: _select), act: _tapSecond),
    BaselineCase('FrostPageIndicator/onSelected+count=11', (_) => const FrostPageIndicator(count: 11, current: 3, onSelected: _select)),
    BaselineCase('FrostPageIndicator/onMedia', (_) => _backdrop(const FrostPageIndicator(count: 4, current: 1, onMedia: true)), envs: BaselineEnv.themes),
    BaselineCase('FrostPageIndicator/onMedia+count=11', (_) => _backdrop(const FrostPageIndicator(count: 11, current: 3, onMedia: true))),
    BaselineCase('FrostPageIndicator/onMedia+onSelected', (_) => _backdrop(const FrostPageIndicator(count: 4, current: 1, onMedia: true, onSelected: _select))),
  ]);
}
