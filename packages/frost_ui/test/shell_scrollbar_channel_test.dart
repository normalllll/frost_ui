import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/controls/_search_options.dart';
import 'package:frost_ui/src/layout/_page_scroll_behavior.dart';
import 'package:frost_ui/src/primitives/_page_outline.dart';

import 'shell_test.dart' show shell;
import 'support.dart';

void main() {
  for (final dpr in [1.0, 1.5, 2.0]) {
    for (final direction in TextDirection.values) {
      testWidgets('normal scrollbar uses the page channel at DPR $dpr/$direction', (tester) async {
        tester.view.physicalSize = Size(1440 * dpr, 900 * dpr);
        tester.view.devicePixelRatio = dpr;
        addTearDown(tester.view.reset);
        final controller = ScrollController();
        addTearDown(controller.dispose);
        const media = ValueKey('edge media');
        await tester.pumpWidget(
          frostTestApp(
            Builder(
              builder: (context) => Theme(
                data: Theme.of(context).copyWith(scrollbarTheme: const ScrollbarThemeData(thumbVisibility: WidgetStatePropertyAll(true))),
                child: Directionality(
                  textDirection: direction,
                  child: shell(
                    child: PrimaryScrollController(
                      controller: controller,
                      automaticallyInheritForPlatforms: TargetPlatform.values.toSet(),
                      child: FrostPinnedChrome(
                        chrome: const FrostContentColumn(child: FrostPageHeader(title: Text('Header'))),
                        body: const FrostLoadingScrollView(
                          slivers: [
                            FrostChromeSpacer(),
                            SliverToBoxAdapter(
                              child: ColoredBox(key: media, color: Colors.red, child: SizedBox(height: 3000)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final page = find.byType(FrostPinnedChrome);
        final viewport = tester.getRect(find.descendant(of: page, matching: find.byType(Viewport)));
        // The page runs up to the sidebar's rail on the right in right-to-left text.
        final edge = direction == TextDirection.rtl ? 1440.0 - 60 : 1440.0;
        expect(viewport.right, edge);
        expect(controller.positions, hasLength(1));
        expect(
          find.descendant(of: page, matching: find.byType(Scrollbar)),
          findsOneWidget,
          reason: 'the scroll view owns its ordinary automatic scrollbar',
        );
        final clip = tester.widget<ClipPath>(find.byWidgetPredicate((w) => w is ClipPath && w.clipper is FrostPageViewportClip));
        final size = tester.getSize(find.byWidget(clip));
        final outline = clip.clipper!.getClip(size);
        expect(outline.contains(const Offset(1, 1)), false);
        expect(outline.contains(Offset(size.width - 9, 1)), false, reason: 'the panel keeps its upper-right rounded corner');
        expect(outline.contains(Offset(size.width - 1, 1)), true, reason: 'the same clip includes the physical-right scrollbar channel');
        expect(outline.contains(Offset(size.width - 9, size.height - 1)), false, reason: 'the panel keeps its lower-right rounded corner');
        expect(outline.contains(Offset(size.width - 1, size.height - 1)), true);
        final surface = find.byWidgetPredicate((w) => w is FrostSurface && w.role == FrostSurfaceRole.panel);
        final background = find.descendant(
          of: surface,
          matching: find.byWidgetPredicate((w) => w is DecoratedBox && w.decoration is ShapeDecoration && (w.decoration as ShapeDecoration).color != null),
        );
        expect(tester.getRect(background.first).right, edge - 8, reason: 'only the viewport expands; the painted panel keeps its 8-point margin');
        final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await gesture.addPointer(location: Offset(edge - 2, 600));
        await tester.pump();
        await gesture.down(Offset(edge - 2, 600));
        await gesture.up();
        await tester.pumpAndSettle();
        expect(controller.offset, greaterThan(0), reason: 'the channel is a working scrollbar track');
        await gesture.removePointer();
        expect(tester.takeException(), isNull);
      });
    }
  }
  testWidgets('body suggestions keep their viewport full-width and align rows and footer inside the channel', (tester) async {
    tester.view.physicalSize = const Size(560, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final controller = TextEditingController(text: 'query'), focus = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focus.dispose);
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(
      frostTestApp(
        shell(
          child: FrostSearchInput.suggesting(
            controller: controller,
            focusNode: focus,
            placeholder: 'Search',
            onSubmitted: (_) {},
            content: searchContent([
              FrostSearchSection(
                children: [FrostSearchSuggestionRow(label: 'First', onSelected: () {})],
              ),
            ], message: 'Status'),
            placement: FrostSuggestionPlacement.inline,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    focus.requestFocus();
    await tester.pumpAndSettle();
    expect(focus.hasFocus, isTrue, reason: 'field must retain focus to show suggestions');
    expect(find.text('First'), findsOneWidget);
    final list = find.ancestor(of: find.byType(FrostSearchContentRoot), matching: find.byType(SingleChildScrollView));
    expect(tester.getRect(list).right, 560);
    final row = tester.getRect(find.byType(FrostListRow));
    expect(row.right, tester.getRect(find.byType(FrostTextField)).right);
    expect(row.right, lessThanOrEqualTo(548));
    expect(tester.getTopLeft(find.text('Status')).dx, row.left);
    expect(tester.takeException(), isNull);
  });
  for (final continuous in [true, false]) {
    test('viewport clip uses the configured panel corners, continuous=$continuous', () {
      final clip = FrostPageViewportClip(radius: FrostRadius.borderRadius(FrostRadius.lg), continuous: continuous, channel: 8).getClip(const Size(400, 300));
      expect(clip.contains(const Offset(1, 1)), false);
      expect(clip.contains(const Offset(391, 299)), false);
      expect(clip.contains(const Offset(399, 299)), true);
      expect(clip.contains(const Offset(200, 150)), true);
    });
  }
  testWidgets('page decoration preserves inherited suppression, input and physics', (tester) async {
    final physics = const NeverScrollableScrollPhysics();
    final parent = const MaterialScrollBehavior().copyWith(
      scrollbars: false,
      dragDevices: {PointerDeviceKind.mouse},
      physics: physics,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
    );
    final behavior = FrostPageScrollBehavior(parent);
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      frostTestApp(
        FrostPageOutline(
          radius: BorderRadius.zero,
          scrollbarChannel: 8,
          child: Builder(
            builder: (context) {
              const child = SizedBox();
              expect(behavior.buildScrollbar(context, child, ScrollableDetails(direction: AxisDirection.down, controller: controller)), same(child));
              expect(behavior.dragDevices, {PointerDeviceKind.mouse});
              expect(behavior.getScrollPhysics(context), same(physics));
              expect(behavior.getKeyboardDismissBehavior(context), ScrollViewKeyboardDismissBehavior.onDrag);
              return child;
            },
          ),
        ),
      ),
    );
  });
}
