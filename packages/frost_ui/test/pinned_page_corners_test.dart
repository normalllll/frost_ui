import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/primitives/_page_outline.dart';
import 'package:frost_ui/src/surface/_window_background.dart';
import 'package:material_ui/material_ui.dart';

import 'shell_test.dart' show shell;
import 'support.dart';
import 'window_caption_test.dart' show FakeWindow;

void main() {
  for (final brightness in Brightness.values) {
    for (final solid in [false, true]) {
      testWidgets('page corners exclude pinned glass in $brightness solid=$solid', (tester) async {
        tester.view.physicalSize = const Size(1000, 700);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final boundary = GlobalKey();
        final controller = ScrollController();
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          frostTestApp(
            RepaintBoundary(
              key: boundary,
              child: FrostWindowBackgroundScope(
                hasAmbient: true,
                background: const Color(0xff9f6584),
                child: shell(
                  child: FrostPinnedChrome(
                    chrome: const SizedBox(height: 52),
                    body: CustomScrollView(
                      controller: controller,
                      slivers: const [
                        FrostChromeSpacer(),
                        SliverToBoxAdapter(child: SizedBox(height: 3000)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            brightness: brightness,
            reduceTransparency: solid,
          ),
        );
        await tester.pumpAndSettle();
        final pane = tester.getRect(find.byType(FrostContentViewport));
        Future<List<int>> pixels() async {
          final image = await (boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary).toImage();
          final data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
          final result = <int>[];
          for (final x in [pane.left.toInt(), pane.right.toInt() - 9]) {
            final index = (pane.top.toInt() * image.width + x) * 4;
            result.addAll(data.buffer.asUint8List().sublist(index, index + 4));
          }
          image.dispose();
          return result;
        }

        final before = await tester.runAsync(pixels);
        for (final offset in [12.0, 24.0, 100.0]) {
          controller.jumpTo(offset);
          await tester.pumpAndSettle();
          final after = await tester.runAsync(pixels);
          expect(after, before, reason: 'Glass must not paint outside the rounded left page corner, offset=$offset.');
        }
        final band = tester.widget<FrostSurface>(
          find.descendant(
            of: find.byType(FrostPinnedChromeGlass),
            matching: find.byWidgetPredicate((w) => w is FrostSurface && w.role == FrostSurfaceRole.chrome),
          ),
        );
        expect(band.borderRadius, const BorderRadius.vertical(top: Radius.circular(FrostRadius.lg)));
        expect(pane.right, 1000, reason: 'Viewport includes the physical-right scrollbar channel.');
        expect(FrostPageOutline.channelOf(tester.element(find.byType(FrostContentViewport))), 8);
        expect(tester.takeException(), isNull);
      });
    }
  }
  for (final direction in TextDirection.values) {
    testWidgets('the shell retains the panel edge across resize and caption state: $direction', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1440, 900);
      addTearDown(tester.view.reset);
      final window = FakeWindow();
      addTearDown(window.dispose);
      var initializations = 0;
      await tester.pumpWidget(
        frostTestApp(
          Directionality(
            textDirection: direction,
            child: FrostWindowCaptionScope(
              window: window,
              child: shell(child: _Probe(onInit: () => initializations++)),
            ),
          ),
        ),
      );

      final panel = find.byWidgetPredicate((w) => w is FrostSurface && w.role == FrostSurfaceRole.panel);
      final squareRight = (tester.widget<FrostSurface>(panel).borderRadius as BorderRadius).topRight == Radius.zero;
      expect(squareRight, isFalse);
      void check(double width) {
        final pane = tester.getRect(find.byType(FrostContentViewport));
        // The page runs to the window edge opposite the sidebar.
        expect(direction == TextDirection.rtl ? pane.left : pane.right, direction == TextDirection.rtl ? 0 : width);
        expect(FrostPageOutline.channelOf(tester.element(find.byType(FrostContentViewport))), 8);
        expect(pane.bottom, 892);
        final radius = tester.widget<FrostSurface>(panel).borderRadius as BorderRadius;
        expect(radius.topLeft, const Radius.circular(FrostRadius.lg));
        expect(radius.bottomLeft, const Radius.circular(FrostRadius.lg));
        expect(radius.topRight, const Radius.circular(FrostRadius.lg));
        expect(radius.bottomRight, radius.topRight);
        expect(initializations, 1);
      }

      check(1440);
      await tester.tap(findFrostTooltip('L.expandNavigation'));
      await tester.pumpAndSettle();
      check(1440);
      for (final width in [1024.0, 900.0, 1920.0]) {
        tester.view.physicalSize = Size(width, 900);
        await tester.pumpAndSettle();
        check(width);
      }
      window.change(maximized: true);
      await tester.pumpAndSettle();
      check(1920);
      window.change();
      await tester.pumpAndSettle();
      check(1920);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}

class _Probe extends StatefulWidget {
  const _Probe({required this.onInit});
  final VoidCallback onInit;
  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  @override
  void initState() {
    super.initState();
    widget.onInit();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}
