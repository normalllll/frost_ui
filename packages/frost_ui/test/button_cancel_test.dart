import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';

import 'support.dart';

void main() {
  testWidgets('a loading icon button with onCancel stays tappable and reads as cancel', (tester) async {
    final semantics = tester.ensureSemantics();
    var played = 0, cancelled = 0;
    Future<void> pump({required bool loading, bool cancellable = true}) => tester.pumpWidget(
      frostTestApp(
        Center(
          child: FrostButton.icon(
            icon: testIcons.play,
            label: 'Play',
            onPressed: () => played++,
            state: loading ? FrostActionState.running(onCancel: cancellable ? () => cancelled++ : null) : FrostActionState.idle,
          ),
        ),
      ),
    );

    await pump(loading: false);
    await tester.tap(find.byType(FrostButton));
    expect((played, cancelled), (1, 0));

    await pump(loading: true);
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(FrostActivityIndicator), findsOneWidget);
    await tester.tap(find.byType(FrostButton));
    expect((played, cancelled), (1, 1));
    final node = tester.getSemantics(find.byType(FrostButton));
    expect(node.label, 'L.cancel');
    expect(node.flagsCollection.isEnabled, Tristate.isTrue);

    // Without onCancel a loading button keeps ignoring presses.
    await pump(loading: true, cancellable: false);
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.byType(FrostButton), warnIfMissed: false);
    expect((played, cancelled), (1, 1));
    expect(tester.getSemantics(find.byType(FrostButton)).label, 'Play');
    semantics.dispose();
  });
}
