import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/overlays/_menu_panel.dart';
import 'package:material_ui/material_ui.dart';

import 'support.dart';

const _player = ValueKey('player');

Widget _page(Widget body) => frostTestApp(
  Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const AspectRatio(aspectRatio: 16 / 9, child: ColoredBox(key: _player, color: Colors.black)),
      Expanded(child: FrostOverlayRegion(child: body)),
    ],
  ),
  platform: TargetPlatform.android,
);

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('a sheet opened from the body below a player leaves the player uncovered', (tester) async {
    _phone(tester);
    await tester.pumpWidget(
      _page(
        Builder(
          builder: (context) => Center(
            child: FrostButton(
              label: 'Replies',
              onPressed: () => showFrostSheet<void>(context: context, title: 'Replies', builder: (_) => const Text('Reply list')),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final player = tester.getRect(find.byKey(_player));
    await tester.tap(find.text('Replies'));
    await tester.pumpAndSettle();
    expect(find.text('Reply list'), findsOneWidget);
    final barrier = tester.getRect(find.byType(ModalBarrier).last);
    expect(barrier.top, greaterThanOrEqualTo(player.bottom), reason: 'the scrim stays below the player');
    final sheet = tester.getRect(find.ancestor(of: find.text('Reply list'), matching: find.byType(FrostSurface)).last);
    expect(sheet.top, greaterThanOrEqualTo(player.bottom));

    await tester.tapAt(player.center);
    await tester.pumpAndSettle();
    expect(find.text('Reply list'), findsOneWidget, reason: 'the player is outside the scrim, so a tap on it does not dismiss the sheet');
  });

  testWidgets('a menu anchored at the bottom of the body opens inside the body', (tester) async {
    _phone(tester);
    await tester.pumpWidget(
      _page(
        Align(
          alignment: Alignment.bottomCenter,
          child: FrostMenuAnchor(
            entries: [for (var index = 0; index < 14; index++) FrostMenuAction('Part $index', onSelected: () {})],
            builder: (_, _, toggle) => FrostButton(label: 'Parts', onPressed: toggle),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final player = tester.getRect(find.byKey(_player));
    await tester.tap(find.text('Parts'));
    await tester.pumpAndSettle();
    final panel = tester.getRect(find.byType(FrostMenuPanel));
    expect(panel.top, greaterThanOrEqualTo(player.bottom), reason: 'the menu does not open over the player');
    expect(tester.takeException(), isNull);
  });
}
