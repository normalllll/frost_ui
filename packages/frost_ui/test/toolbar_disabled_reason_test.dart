import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:material_ui/material_ui.dart';

import 'support.dart';

const _reason = 'ssh-keygen is not installed';

Widget _toolbar({required double width, required bool showsLabel, String? reason = _reason, VoidCallback? onPressed}) => frostTestApp(
  Align(
    alignment: Alignment.topLeft,
    child: SizedBox(
      width: width,
      child: FrostToolbar(
        middle: width < 200 ? const SizedBox(height: 40) : null,
        trailing: [
          FrostToolbarItem.action(
            icon: testIcons.add,
            label: 'Add account',
            showsLabel: showsLabel,
            onPressed: onPressed,
            disabledReason: reason,
            priority: FrostToolbarPriority.low,
          ),
          FrostToolbarItem.action(icon: testIcons.refresh, label: 'Refresh', priority: FrostToolbarPriority.high, onPressed: () {}),
          FrostToolbarItem.action(icon: testIcons.download, label: 'Export', priority: FrostToolbarPriority.high, onPressed: () {}),
        ],
      ),
    ),
  ),
  density: FrostDensity.compact,
);

Future<void> _hover(WidgetTester tester, Finder target) async {
  final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await mouse.addPointer(location: Offset.zero);
  addTearDown(mouse.removePointer);
  await mouse.moveTo(tester.getCenter(target));
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  testWidgets('label form: tooltip shows the reason and semantics carry it as the hint', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_toolbar(width: 700, showsLabel: true));
    final button = find.bySemanticsLabel('Add account');
    expect(tester.getSemantics(button).hint, _reason);
    expect(tester.getSemantics(button).label, 'Add account');
    await _hover(tester, find.bySemanticsLabel('Add account'));
    expect(find.text(_reason), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('icon-only form: tooltip shows the label, then the reason', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_toolbar(width: 700, showsLabel: false));
    final button = find.bySemanticsLabel('Add account');
    expect(tester.getSemantics(button).hint, _reason);
    await _hover(tester, button);
    expect(find.text('Add account\n$_reason'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('overflow form: the item stays disabled and carries the reason', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_toolbar(width: 150, showsLabel: true));
    await tester.ensureVisible(findFrostTooltip('L.more').last);
    await tester.pump();
    await tester.tap(findFrostTooltip('L.more').hitTestable());
    await tester.pumpAndSettle();
    final item = find.text('Add account').hitTestable();
    expect(item, findsOneWidget);
    await tester.tap(item);
    await tester.pumpAndSettle();
    expect(find.text('Add account').hitTestable(), findsOneWidget);
    await _hover(tester, item);
    expect(find.text(_reason), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('with an onPressed the reason is ignored', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_toolbar(width: 700, showsLabel: true, onPressed: () {}));
    expect(tester.getSemantics(find.bySemanticsLabel('Add account')).hint, isEmpty);
    await _hover(tester, find.bySemanticsLabel('Add account'));
    expect(find.text(_reason), findsNothing);
    semantics.dispose();
  });

  testWidgets("without a reason nothing changes", (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_toolbar(width: 700, showsLabel: true, reason: null));
    expect(tester.getSemantics(find.bySemanticsLabel("Add account")).hint, isEmpty);
    await _hover(tester, find.bySemanticsLabel("Add account"));
    expect(find.text(_reason), findsNothing);
    semantics.dispose();
  });
}
