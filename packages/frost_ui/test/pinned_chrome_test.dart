import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';

import 'support.dart';

void main() {
  testWidgets('wheel and drag over the pinned bar scroll the list beneath, and its controls still work', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    var tapped = 0;
    await tester.pumpWidget(
      frostTestApp(
        Scaffold(
          body: FrostPinnedChrome(
            extent: 56,
            // Like a scrollable tab bar, the row takes every pointer over the bar.
            chrome: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                TextButton(onPressed: () => tapped++, child: const Text('tab')),
                for (var i = 0; i < 20; i++) TextButton(onPressed: () {}, child: Text('tab $i')),
              ],
            ),
            body: CustomScrollView(
              controller: controller,
              slivers: [
                const FrostChromeSpacer(),
                SliverList.builder(itemCount: 100, itemBuilder: (context, index) => SizedBox(height: 40, child: Text('row $index'))),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final bar = tester.getTopLeft(find.byType(FrostPinnedChrome)) + const Offset(300, 28);

    final mouse = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(mouse.hover(bar));
    await tester.sendEventToBinding(mouse.scroll(const Offset(0, 120)));
    await tester.pump();
    expect(controller.offset, 120);

    await tester.dragFrom(bar, const Offset(0, -100), kind: PointerDeviceKind.touch);
    await tester.pumpAndSettle();
    expect(controller.offset, greaterThanOrEqualTo(200));

    await tester.tap(find.text('tab'));
    expect(tapped, 1);
  });
}
