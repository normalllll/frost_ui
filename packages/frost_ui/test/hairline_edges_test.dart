import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/controls/_field_frame.dart';

import 'support.dart';

BorderSide _side(WidgetTester tester, Finder owner) =>
    tester.renderObject<RenderFrostFieldPaint>(find.descendant(of: owner, matching: find.byType(FrostFieldPaint))).side;

void main() {
  const ratios = [1.0, 1.25, 1.5, 2.0];

  for (final ratio in ratios) {
    group('device pixel ratio $ratio', () {
      Future<void> pump(WidgetTester tester, Widget child) async {
        tester.view.devicePixelRatio = ratio;
        tester.view.physicalSize = Size(1600, 1200) * ratio;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(frostTestApp(Align(alignment: Alignment.topCenter, child: SizedBox(width: 360, height: 48, child: child))));
      }

      testWidgets('a focused text field paints a 2 physical pixel edge', (tester) async {
        final focus = FocusNode();
        addTearDown(focus.dispose);
        await pump(tester, FrostTextField(focusNode: focus, placeholder: 'Input'));
        expect(_side(tester, find.byType(FrostTextField)).width * ratio, closeTo(1, 1e-9));
        focus.requestFocus();
        await tester.pumpAndSettle();
        final side = _side(tester, find.byType(FrostTextField));
        expect(side.width, closeTo(2 / ratio, 1e-9));
        expect(side.strokeAlign, BorderSide.strokeAlignInside);
      });

      testWidgets('an invalid text field paints the same edge', (tester) async {
        await pump(tester, const FrostTextField(error: 'Wrong', placeholder: 'Input'));
        await tester.pumpAndSettle();
        expect(_side(tester, find.byType(FrostTextField)).width, closeTo(2 / ratio, 1e-9));
      });

      testWidgets('a focused search input paints a 2 physical pixel edge', (tester) async {
        final focus = FocusNode();
        final controller = TextEditingController();
        addTearDown(focus.dispose);
        addTearDown(controller.dispose);
        await pump(tester, FrostSearchInput(controller: controller, focusNode: focus, placeholder: 'Search', onSubmitted: (_) {}));
        focus.requestFocus();
        await tester.pumpAndSettle();
        expect(_side(tester, find.byType(FrostSearchInput)).width, closeTo(2 / ratio, 1e-9));
      });

      testWidgets('a focused caption search paints a 2 physical pixel edge', (tester) async {
        final focus = FocusNode();
        final controller = TextEditingController();
        addTearDown(focus.dispose);
        addTearDown(controller.dispose);
        await pump(tester, FrostCaptionSearch(controller: controller, focusNode: focus, placeholder: 'Search', onSubmitted: (_) {}));
        focus.requestFocus();
        await tester.pumpAndSettle();
        expect(_side(tester, find.byType(FrostCaptionSearch)).width, closeTo(2 / ratio, 1e-9));
      });
    });
  }

  // The fill and edge are painted outside the clip; only the content is inside it.
  void expectOnlyContentClipped(WidgetTester tester) {
    final clip = find.descendant(of: find.byType(FrostButton), matching: find.byType(ClipPath));
    expect(clip, findsOneWidget);
    final fills = find.descendant(of: clip, matching: find.byWidgetPredicate((w) => w is DecoratedBox && w.decoration is ShapeDecoration));
    expect(fills, findsNothing, reason: 'no fill layer inside the clip');
  }

  testWidgets('a hovered iconOnMedia paints one circle; only its content is clipped', (tester) async {
    await tester.pumpWidget(
      frostTestApp(Center(child: FrostButton.iconOnMedia(icon: testIcons.chevronRight, label: 'Next', onPressed: () {}))),
    );
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.byType(FrostButton)));
    await tester.pumpAndSettle();
    expect(tester.renderObject(find.byType(FrostButton)), paintsExactlyCountTimes(#drawCircle, 1));
    expectOnlyContentClipped(tester);
    final clipper = tester.widget<ClipPath>(find.descendant(of: find.byType(FrostButton), matching: find.byType(ClipPath))).clipper! as ShapeBorderClipper;
    expect(clipper.shape, isA<CircleBorder>());
  });

  testWidgets('a hovered outlined button folds its wash into one fill and keeps one unclipped edge', (tester) async {
    await tester.pumpWidget(frostTestApp(Center(child: FrostButton.outlined(label: 'Edit', onPressed: () {}))));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.byType(FrostButton)));
    await tester.pumpAndSettle();
    expect(tester.renderObject(find.byType(FrostButton)), paintsExactlyCountTimes(#drawRSuperellipse, 2));
    expectOnlyContentClipped(tester);
  });

  for (final circular in [false, true]) {
    testWidgets('content reaching past the edge is clipped to the ${circular ? 'circular' : 'rounded'} shape', (tester) async {
      final key = GlobalKey();
      const overflow = OverflowBox(
        maxWidth: 400,
        maxHeight: 400,
        child: SizedBox.square(dimension: 300, child: ColoredBox(color: Color(0xFFFF0000))),
      );
      await tester.pumpWidget(
        frostTestApp(
          Center(
            child: RepaintBoundary(
              key: key,
              child: circular
                  ? FrostButton.iconOnMedia(icon: testIcons.chevronRight, label: 'Next', onPressed: () {})
                  : FrostButton.outlined(label: 'Edit', labelWidget: overflow, onPressed: () {}),
            ),
          ),
        ),
      );
      final clipper = tester.widget<ClipPath>(find.descendant(of: find.byType(FrostButton), matching: find.byType(ClipPath))).clipper! as ShapeBorderClipper;
      final size = tester.getSize(find.byType(FrostButton));
      final path = clipper.shape.getOuterPath(Offset.zero & size);
      expect(path.contains(Offset.zero), isFalse);
      expect(path.contains(size.center(Offset.zero)), isTrue);
      if (!circular) {
        // The overflowing red box covers the whole button; its corners stay outside the shape.
        final pixels = await tester.runAsync(() async {
          final image = await tester.renderObject<RenderRepaintBoundary>(find.byKey(key)).toImage();
          final data = (await image.toByteData())!;
          final alpha = data.getUint8(3);
          final centre = data.getUint8((((image.height ~/ 2) * image.width) + image.width ~/ 2) * 4 + 3);
          image.dispose();
          return (alpha, centre);
        });
        expect(pixels!.$1, 0, reason: 'corner pixel');
        expect(pixels.$2, 255, reason: 'centre pixel');
      }
    });
  }
}
