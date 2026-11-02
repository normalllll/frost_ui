import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'support.dart';

void main() {
  for (final width in [1024.0, 1440.0, 2560.0]) {
    for (final alignment in [null, ...FrostColumnAlignment.values]) {
      testWidgets('box and sliver use the same capped first-frame column at $width/$alignment', (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        const body = Column(
          children: [
            FrostContentColumn(
              maxWidth: 760,
              child: SizedBox(key: ValueKey('box'), width: double.infinity, height: 52),
            ),
            Expanded(
              child: CustomScrollView(
                slivers: [
                  FrostSliverContentColumn(
                    maxWidth: 760,
                    sliver: SliverToBoxAdapter(
                      child: SizedBox(key: ValueKey('sliver'), width: double.infinity, height: 100),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
        await tester.pumpWidget(frostTestApp(alignment == null ? body : FrostColumnPlacement(alignment: alignment, child: body)));
        final box = tester.getRect(find.byKey(const ValueKey('box')));
        final sliver = tester.getRect(find.byKey(const ValueKey('sliver')));
        final expectedLeft =
            24 +
            switch (alignment) {
              FrostColumnAlignment.start => 0,
              FrostColumnAlignment.end => width - 760,
              _ => (width - 760) / 2,
            };
        expect(box.left, expectedLeft);
        expect(box.width, 712);
        expect(sliver.left, box.left);
        expect(sliver.width, box.width);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
