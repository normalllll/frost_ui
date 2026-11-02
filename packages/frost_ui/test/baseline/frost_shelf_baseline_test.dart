import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';

import 'baseline.dart';

Widget _item(BuildContext context, int index) => ColoredBox(
  color: Color(0x33888888 + index * 0x00101010),
  child: Center(child: FrostText('Item $index', tone: FrostTextTone.primary)),
);

FrostShelf _shelf({int itemCount = 12, double itemExtent = 140, double height = 120, Widget? action, double? spacing, double? inset}) => FrostShelf(
  title: 'Recent',
  itemCount: itemCount,
  itemExtent: itemExtent,
  height: height,
  itemBuilder: _item,
  action: action,
  spacing: spacing ?? FrostGap.group,
  inset: inset,
);

Future<void> _scrollEnd(WidgetTester tester, Finder subject) async {
  await tester.drag(find.descendant(of: subject, matching: find.byType(Scrollable)).first, const Offset(-3000, 0));
}

Future<void> _scrollMiddle(WidgetTester tester, Finder subject) async {
  await tester.drag(find.descendant(of: subject, matching: find.byType(Scrollable)).first, const Offset(-300, 0));
}

final _wide = BaselineEnv.standard.copyWith(width: 1280);
// The shelf inset follows the page inset: 16 below 600, 24 from 600.
final _insetLimit = [BaselineEnv.standard.copyWith(width: 599), BaselineEnv.standard.copyWith(width: 600)];

void main() {
  baselineGroup('FrostShelf', [
    BaselineCase(
      'FrostShelf/required',
      (_) => _shelf(),
      envs: [BaselineEnv.standard, BaselineEnv.light, BaselineEnv.narrow, BaselineEnv.touch, BaselineEnv.largeText, _wide, ..._insetLimit],
    ),
    BaselineCase(
      'FrostShelf/action',
      (_) => _shelf(
        action: const FrostButton.quiet(label: 'Show all', onPressed: _noop),
      ),
      envs: [BaselineEnv.standard, BaselineEnv.narrow],
    ),
    BaselineCase('FrostShelf/spacing=24', (_) => _shelf(spacing: 24)),
    BaselineCase('FrostShelf/inset=40', (_) => _shelf(inset: 40), envs: [BaselineEnv.standard, BaselineEnv.narrow]),
    BaselineCase('FrostShelf/itemExtent=200', (_) => _shelf(itemExtent: 200, height: 160)),
    BaselineCase('FrostShelf/itemCount=2', (_) => _shelf(itemCount: 2)),
    BaselineCase('FrostShelf/itemCount=0', (_) => _shelf(itemCount: 0)),
    BaselineCase('FrostShelf/required#scrolled', (_) => _shelf(), act: _scrollMiddle),
    BaselineCase('FrostShelf/required#end', (_) => _shelf(), act: _scrollEnd),
  ]);
}

void _noop() {}
