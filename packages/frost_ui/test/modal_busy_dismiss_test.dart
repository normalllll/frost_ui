import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';

import 'support.dart';

void main() {
  for (final (name, size) in [('wide panel', const Size(1200, 820)), ('narrow bottom sheet', const Size(390, 820))]) {
    group(name, () {
      late ValueNotifier<bool> busy;
      setUp(() => busy = ValueNotifier(true));
      tearDown(() => busy.dispose());

      Future<void> open(WidgetTester tester, {bool barrierDismissible = true}) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          frostTestApp(
            Scaffold(
              body: Builder(
                builder: (context) => FrostButton(
                  label: 'Open',
                  onPressed: () => showFrostAdaptiveDialog<void>(
                    context: context,
                    barrierDismissible: barrierDismissible,
                    builder: (_) => ValueListenableBuilder<bool>(
                      valueListenable: busy,
                      builder: (_, busy, _) => PopScope(
                        canPop: !busy,
                        child: FrostDialog(title: 'Push', content: const Text('Body')),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        expect(find.text('Body'), findsOneWidget);
      }

      testWidgets('Escape and a barrier tap respect PopScope, then close when idle', (tester) async {
        await open(tester);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(find.text('Body'), findsOneWidget);
        await tester.tapAt(const Offset(2, 2));
        await tester.pumpAndSettle();
        expect(find.text('Body'), findsOneWidget);

        busy.value = false;
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(find.text('Body'), findsNothing);
      });

      testWidgets('a barrier tap closes when idle', (tester) async {
        busy.value = false;
        await open(tester);
        await tester.tapAt(const Offset(2, 2));
        await tester.pumpAndSettle();
        expect(find.text('Body'), findsNothing);
      });

      testWidgets('without barrierDismissible Escape does nothing', (tester) async {
        busy.value = false;
        await open(tester, barrierDismissible: false);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(find.text('Body'), findsOneWidget);
      });
    });
  }

  group('narrow bottom sheet drag', () {
    Future<ValueNotifier<bool>> open(WidgetTester tester, {required bool busy}) async {
      tester.view.physicalSize = const Size(390, 820);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final notifier = ValueNotifier(busy);
      addTearDown(notifier.dispose);
      await tester.pumpWidget(
        frostTestApp(
          Scaffold(
            body: Builder(
              builder: (context) => FrostButton(
                label: 'Open',
                onPressed: () => showFrostAdaptiveDialog<void>(
                  context: context,
                  builder: (_) => ValueListenableBuilder<bool>(
                    valueListenable: notifier,
                    builder: (_, busy, _) => PopScope(
                      canPop: !busy,
                      child: FrostDialog(title: 'Push', content: const Text('Body')),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      return notifier;
    }

    testWidgets('a fling does not close a busy sheet and it returns to rest', (tester) async {
      await open(tester, busy: true);
      final rest = tester.getTopLeft(find.text('Body')).dy;
      await tester.fling(find.text('Body'), const Offset(0, 300), 2500);
      await tester.pumpAndSettle();
      expect(find.text('Body'), findsOneWidget);
      expect(tester.getTopLeft(find.text('Body')).dy, closeTo(rest, .5));
    });

    testWidgets('a fling closes an idle sheet', (tester) async {
      await open(tester, busy: false);
      await tester.fling(find.text('Body'), const Offset(0, 300), 2500);
      await tester.pumpAndSettle();
      expect(find.text('Body'), findsNothing);
    });
  });
}
