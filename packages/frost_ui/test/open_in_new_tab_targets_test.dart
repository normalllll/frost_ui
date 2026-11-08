import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';

import 'support.dart';

Future<void> _modifiedTap(WidgetTester tester, Finder target) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.tap(target);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _middleTap(WidgetTester tester, Finder target) async {
  final middle = await tester.startGesture(tester.getCenter(target), kind: PointerDeviceKind.mouse, buttons: kMiddleMouseButton);
  await middle.up();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  testWidgets('a list row sends Ctrl-click and middle-click to its open-in-tab callbacks', (tester) async {
    final calls = <String>[];
    await tester.pumpWidget(
      frostTestApp(
        FrostListRow(
          title: 'Reading list',
          onPressed: () => calls.add('open'),
          onOpenInNewTab: () => calls.add('new tab'),
          onOpenInBackground: () => calls.add('background'),
        ),
        platform: TargetPlatform.windows,
      ),
    );
    final row = find.text('Reading list');
    await _modifiedTap(tester, row);
    expect(calls, ['new tab']);
    calls.clear();
    await _middleTap(tester, row);
    expect(calls, ['background']);
    calls.clear();
    await tester.tap(row);
    await tester.pump(const Duration(milliseconds: 400));
    expect(calls, ['open']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a list row without the callbacks keeps Ctrl-click as a plain activation', (tester) async {
    var opened = 0;
    await tester.pumpWidget(
      frostTestApp(
        FrostListRow(title: 'Row', onPressed: () => opened++),
        platform: TargetPlatform.windows,
      ),
    );
    await _modifiedTap(tester, find.text('Row'));
    expect(opened, 1);
    await _middleTap(tester, find.text('Row'));
    expect(opened, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a linked text separates a plain click, Ctrl-click and middle-click on a link', (tester) async {
    final calls = <String>[];
    final uri = Uri.parse('app://tag/one');
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      frostTestApp(
        SizedBox(
          width: 400,
          child: FrostExpandableText.linked(
            runs: [
              const FrostTextRun('see '),
              FrostTextRun('#tag', link: uri),
            ],
            onLink: (value) => calls.add('open $value'),
            onLinkInNewTab: (value) => calls.add('new tab $value'),
            onLinkInBackground: (value) => calls.add('background $value'),
          ),
        ),
        platform: TargetPlatform.windows,
      ),
    );
    final link = find.bySemanticsLabel('#tag');
    await _modifiedTap(tester, link);
    expect(calls, ['new tab $uri']);
    calls.clear();
    await _middleTap(tester, link);
    expect(calls, ['background $uri']);
    calls.clear();
    await tester.tap(link);
    await tester.pump(const Duration(milliseconds: 400));
    expect(calls, ['open $uri']);
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });
}
