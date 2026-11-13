import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:material_ui/material_ui.dart';

import 'support.dart';

void main() {
  for (final dpr in [1.0, 1.5, 2.0]) {
    testWidgets('divider actual thickness and paint are one physical pixel at $dpr', (tester) async {
      tester.view.devicePixelRatio = dpr;
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        frostTestApp(
          const Column(
            children: [
              FrostDivider(key: ValueKey('h')),
              FrostDivider(key: ValueKey('v'), axis: Axis.vertical, length: 40),
            ],
          ),
        ),
      );
      expect(tester.getSize(find.byKey(const ValueKey('h'))).height, closeTo(1 / dpr, 0.00001));
      expect(tester.getSize(find.byKey(const ValueKey('v'))), Size(1 / dpr, 40));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('keyline paint deducts existing padding and mirrors on the first frame', (tester) async {
    for (final rtl in [false, true]) {
      for (final padding in [0.0, 8.0, 20.0, 24.0]) {
        await tester.pumpWidget(
          frostTestApp(
            Directionality(
              textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
              child: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: 200,
                  child: FrostKeyline(
                    leadingRoom: 0,
                    trailingRoom: 0,
                    edgeDistanceStart: 0,
                    edgeDistanceEnd: 0,
                    insideContainer: true,
                    contentStart: 20,
                    child: Padding(
                      padding: EdgeInsetsDirectional.only(start: padding),
                      child: const FrostDivider(inset: FrostDividerInset.keyline),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        final divider = tester.renderObject<RenderBox>(
          find.descendant(of: find.byType(FrostDivider), matching: find.byWidgetPredicate((w) => w is LeafRenderObjectWidget)),
        );
        final inset = (20 - padding).clamp(0.0, 200.0);
        expect(divider.size.width, 200 - padding);
        expect(
          divider,
          paints..line(
            p1: Offset(rtl ? 0 : inset, .5 / tester.view.devicePixelRatio),
            p2: Offset((rtl ? 0 : inset) + 200 - padding - inset, .5 / tester.view.devicePixelRatio),
            strokeWidth: 0,
          ),
        );
        expect(tester.takeException(), isNull);
      }
    }
  });

  test('vertical keyline is rejected in debug mode', () {
    expect(() => FrostDivider(axis: Axis.vertical, inset: FrostDividerInset.keyline), throwsAssertionError);
  });

  testWidgets('unbounded vertical divider requires an explicit length', (tester) async {
    await tester.pumpWidget(frostTestApp(const SizedBox(height: 40, child: FrostDivider(axis: Axis.vertical))));
    final leaf = find.descendant(of: find.byType(FrostDivider), matching: find.byWidgetPredicate((w) => w is LeafRenderObjectWidget));
    // Probe the actual renderer detached, so an intentional assertion does not
    // cascade through a parent that expects its child to have a size.
    final render = _RenderProbe(tester.widget<LeafRenderObjectWidget>(leaf)).detached(tester.element(leaf));
    render.layout(const BoxConstraints(maxWidth: 100));
    expect(tester.takeException(), isAssertionError);
    render.dispose();
  });
}

class _RenderProbe extends LeafRenderObjectWidget {
  const _RenderProbe(this.source);
  final LeafRenderObjectWidget source;
  @override
  RenderObject createRenderObject(BuildContext context) => source.createRenderObject(context);
  RenderBox detached(BuildContext context) => createRenderObject(context) as RenderBox;
}
