import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/src/motion/_layout_identity.dart';
import 'package:frost_ui/src/motion/_material_reveal.dart';
import 'package:frost_ui/src/motion/layout_crossfade.dart';

import 'support.dart';

// A child can publish its last layout identity while its parent is inactive,
// before a GlobalKey subtree is reattached elsewhere in the same frame.
class _NotifyOnDeactivate extends StatefulWidget {
  const _NotifyOnDeactivate(this.identity);
  final FrostLayoutIdentity identity;
  @override
  State<_NotifyOnDeactivate> createState() => _NotifyOnDeactivateState();
}

class _NotifyOnDeactivateState extends State<_NotifyOnDeactivate> {
  @override
  void deactivate() {
    widget.identity.update(Object(), viewport: 300);
    super.deactivate();
  }

  @override
  Widget build(BuildContext context) => const SizedBox(width: 100, height: 40, child: Text('Retained row'));
}

void main() {
  testWidgets('inactive layout notifications are ignored and reparented rows still fade', (tester) async {
    final identity = FrostLayoutIdentity()..update(0, viewport: 300);
    final key = GlobalKey();
    var right = false;
    late StateSetter update;
    await tester.pumpWidget(
      frostTestApp(
        StatefulBuilder(
          builder: (_, set) {
            update = set;
            final row = FrostLayoutCrossfade(key: key, layoutIdentity: identity, child: _NotifyOnDeactivate(identity));
            return Row(
              children: [
                Expanded(child: right ? const SizedBox() : row),
                Expanded(child: right ? row : const SizedBox()),
              ],
            );
          },
        ),
      ),
    );
    final retained = tester.state(find.byType(_NotifyOnDeactivate));
    update(() => right = true);
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(tester.state(find.byType(_NotifyOnDeactivate)), same(retained));

    identity.update(Object(), viewport: 300);
    await tester.pump();
    final transition = tester.widget<FrostMaterialRevealTransition>(find.byType(FrostMaterialRevealTransition).last);
    expect(transition.opacity.value, 0);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    expect(transition.opacity.value, 1);
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
    identity.dispose();
  });
  testWidgets('the outgoing frame keeps the screen resolution and its logical size', (tester) async {
    tester.view.devicePixelRatio = 2;
    tester.view.physicalSize = const Size(1600, 1200);
    addTearDown(tester.view.reset);
    final identity = FrostLayoutIdentity()..update(0, viewport: 200);
    await tester.pumpWidget(
      frostTestApp(
        Center(
          child: SizedBox(
            width: 200,
            height: 100,
            child: FrostLayoutCrossfade(
              layoutIdentity: identity,
              child: const ColoredBox(color: Color(0xFF3060C0)),
            ),
          ),
        ),
      ),
    );
    identity.update(Object(), viewport: 200);
    await tester.pump();
    final paint = find.descendant(of: find.byType(FrostLayoutCrossfade), matching: find.byType(CustomPaint)).first;
    expect(
      tester.renderObject<RenderCustomPaint>(paint),
      paints..drawImageRect(source: const Rect.fromLTWH(0, 0, 400, 200), destination: const Rect.fromLTWH(0, 0, 200, 100)),
    );
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
    identity.dispose();
  });
}
