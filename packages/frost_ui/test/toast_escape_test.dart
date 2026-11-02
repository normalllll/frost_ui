import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';

import 'support.dart';

Widget app() => frostTestApp(
  Scaffold(
    body: Builder(
      builder: (context) => FrostButton(
        label: 'Open',
        onPressed: () => showFrostDialog<void>(
          context: context,
          builder: (_) => FrostDialog(title: 'Title', content: const Text('Body')),
        ),
      ),
    ),
  ),
);

Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 900));
}

void main() {
  testWidgets('Escape dismisses the toasts', (tester) async {
    await tester.pumpWidget(app());
    FrostToast.error('Fetch failed');
    FrostToast.info('Second');
    await settle(tester);
    expect(find.text('Fetch failed'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settle(tester);
    expect(find.text('Fetch failed'), findsNothing);
    expect(find.text('Second'), findsNothing);
  });

  testWidgets('dismissAll dismisses every notice, queued ones included', (tester) async {
    await tester.pumpWidget(app());
    for (var i = 0; i < 7; i++) {
      FrostToast.info('Notice $i');
    }
    await settle(tester);
    expect(find.text('Notice 0'), findsOneWidget);
    FrostToast.dismissAll();
    await settle(tester);
    await settle(tester);
    expect(find.textContaining('Notice'), findsNothing);
  });

  testWidgets('Escape closes only the dialog while a toast shows', (tester) async {
    await tester.pumpWidget(app());
    await tester.tap(find.text('Open'));
    await settle(tester);
    FrostToast.info('Saved');
    await settle(tester);
    expect(find.text('Body'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settle(tester);
    expect(find.text('Body'), findsNothing);
    expect(find.text('Saved'), findsOneWidget);
    // With the dialog gone, the next Escape reaches the toast.
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settle(tester);
    expect(find.text('Saved'), findsNothing);
  });

  testWidgets('Escape still closes a dialog when no toast shows', (tester) async {
    await tester.pumpWidget(app());
    await tester.tap(find.text('Open'));
    await settle(tester);
    expect(find.text('Body'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settle(tester);
    expect(find.text('Body'), findsNothing);
  });
}
