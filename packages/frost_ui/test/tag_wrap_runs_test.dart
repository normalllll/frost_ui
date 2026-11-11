import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/controls/_button_parts.dart' show FrostButtonFrame;

import 'support.dart';

const _names = ['#オリジナル', '#ファンタジー', '#異世界', '#少女', '#冒険'];

Widget _tags(List<String> pressed, {List<String> names = _names}) => frostTestApp(
  FrostInputFeedback(
    child: Align(
      alignment: Alignment.topLeft,
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: SizedBox(
          width: 240,
          child: FrostWrap(
            children: [for (final name in names) FrostTag(label: name, style: FrostTagStyle.topic, onPressed: () => pressed.add(name))],
          ),
        ),
      ),
    ),
  ),
);

Rect _pill(WidgetTester tester, String name) => tester.getRect(find.ancestor(of: find.text(name), matching: find.byType(FrostButtonFrame)).first);

/// Pills grouped by run, top to bottom.
List<List<Rect>> _runs(WidgetTester tester) {
  final runs = <double, List<Rect>>{};
  for (final name in _names) {
    final pill = _pill(tester, name);
    runs.putIfAbsent(pill.top, () => []).add(pill);
  }
  return [for (final top in runs.keys.toList()..sort()) runs[top]!..sort((a, b) => a.left.compareTo(b.left))];
}

void main() {
  final densities = TargetPlatformVariant({TargetPlatform.windows, TargetPlatform.android});

  testWidgets('wrapped tags leave the same gap between the pills of two runs as between neighbours in a run', (tester) async {
    await tester.pumpWidget(_tags([]));
    await tester.pumpAndSettle();
    final runs = _runs(tester);
    expect(runs.length, greaterThan(1));
    final across = runs.first[1].left - runs.first[0].right;
    expect(runs[1].first.top - runs.first.first.bottom, moreOrLessEquals(across, epsilon: .5));
    expect(tester.takeException(), isNull);
  }, variant: densities);

  testWidgets('a single run of tags is no taller than a tag target', (tester) async {
    await tester.pumpWidget(_tags([], names: const ['#少女']));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(FrostWrap)).height, lessThanOrEqualTo(FrostDensity.of(tester.element(find.byType(FrostWrap))).targetHeight));
    expect(tester.takeException(), isNull);
  }, variant: densities);

  testWidgets('a finger reaches a wrapped tag within its full target, and the nearer tag between two runs', (tester) async {
    final pressed = <String>[];
    await tester.pumpWidget(_tags(pressed));
    await tester.pumpAndSettle();
    final runs = _runs(tester);
    final upper = runs.first.first, lower = runs[1].first;
    String nameAt(Rect pill) => _names.firstWhere((name) => _pill(tester, name) == pill);
    final reach = (FrostControlSize.minimumHitHeight(touch: true) - upper.height) / 2;

    // The touch target follows the latest pointer: a first touch on the pill.
    await tester.tapAt(upper.center);
    await tester.pumpAndSettle();
    pressed.clear();
    await tester.tapAt(Offset(upper.center.dx, upper.top - reach + 1));
    await tester.pumpAndSettle();
    expect(pressed, [nameAt(upper)], reason: 'above the first run, within the touch target');

    final gap = lower.top - upper.bottom;
    await tester.tapAt(Offset(upper.left + 4, upper.bottom + gap * .25));
    await tester.pumpAndSettle();
    await tester.tapAt(Offset(lower.left + 4, lower.top - gap * .25));
    await tester.pumpAndSettle();
    expect(pressed.skip(1), [nameAt(upper), nameAt(lower)]);
    expect(tester.takeException(), isNull);
  }, variant: densities);
}
