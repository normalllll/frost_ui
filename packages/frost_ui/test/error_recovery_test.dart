import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/controls/action_state.dart' show FrostActionRunning;
import 'package:material_ui/material_ui.dart';

import 'support.dart';

Widget recoveryApp(Widget child, Future<bool> Function() resolve) => frostTestApp(
  FrostScope(
    config: FrostConfig(
      palettes: testConfig.palettes,
      fonts: testFonts,
      icons: testIcons,
      labels: testLabels,
      errors: FrostErrorPresenter(
        message: (_, error) => 'Recoverable failure',
        details: (_) => null,
        title: (_, error) => 'Mapped title',
        icon: (_, error) => testIcons.clock,
        action: (_, error) => error == 'plain' ? null : FrostErrorAction(label: 'Verify', icon: testIcons.user, onPressed: resolve),
      ),
    ),
    child: child,
  ),
);

Finder verify() => find.byWidgetPredicate((w) => w is FrostButton && w.label == 'Verify');

void main() {
  for (final outcome in ['false', 'exception', 'unmount', 'replace']) {
    testWidgets('$outcome recovery does not retry; failed actions restore controls', (tester) async {
      final pending = Completer<bool>();
      var retries = 0;
      var error = 'first';
      late StateSetter update;
      await tester.pumpWidget(
        recoveryApp(
          StatefulBuilder(
            builder: (_, set) {
              update = set;
              return Center(
                child: FrostErrorActionButton(error: error, onResolved: () => retries++),
              );
            },
          ),
          () => pending.future,
        ),
      );
      await tester.tap(verify());
      await tester.pump();
      if (outcome == 'unmount') await tester.pumpWidget(const SizedBox());
      if (outcome == 'replace') {
        update(() => error = 'second');
        await tester.pump();
      }
      if (outcome == 'exception') {
        pending.completeError(StateError('Verification failed'));
      } else {
        pending.complete(outcome == 'unmount' || outcome == 'replace');
      }
      await tester.pumpAndSettle();
      expect(retries, 0);
      if (outcome == 'exception') expect(tester.takeException(), isA<StateError>());
      expect(tester.takeException(), isNull);
      if (outcome == 'false' || outcome == 'exception') {
        expect(tester.widget<FrostButton>(verify()).state, isNot(isA<FrostActionRunning>()));
        await tester.pump(const Duration(seconds: 2));
      }
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets('page and details scrolling stay isolated from the primary controller', (tester) async {
    final primary = ScrollController();
    await tester.pumpWidget(
      frostTestApp(
        Center(
          child: PrimaryScrollController(
            controller: primary,
            child: SizedBox(
              height: 240,
              child: FrostErrorContent(message: 'Failed', onRetry: () {}, details: List.filled(50, 'Technical').join('\n')),
            ),
          ),
        ),
      ),
    );
    await tester.ensureVisible(find.text('L.errorDetails'));
    await tester.tap(find.text('L.errorDetails'));
    await tester.pumpAndSettle();
    expect(primary.positions, isEmpty);
    final positions = tester.stateList<ScrollableState>(find.byType(Scrollable)).map((s) => s.position).toList();
    expect(positions.where((p) => p.maxScrollExtent > 0).length, 2);
    for (final position in positions) {
      position.jumpTo(position.maxScrollExtent);
    }
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    primary.dispose();
  });
  testWidgets('unmapped errors render no recovery control and narrow large text can wrap actions', (tester) async {
    await tester.pumpWidget(recoveryApp(const Center(child: FrostErrorActionButton(error: 'plain', onResolved: null)), () async => true));
    expect(verify(), findsNothing);
    await tester.pumpWidget(
      recoveryApp(
        Center(
          child: SizedBox(
            width: 180,
            height: 280,
            child: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2)),
              child: FrostErrorContent.fromError(error: 'mapped', onRetry: () {}),
            ),
          ),
        ),
        () async => true,
      ),
    );
    await tester.pumpAndSettle();
    expect(verify(), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
