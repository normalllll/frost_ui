import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/layout/window_caption_scope.dart' show FrostHitKind;
import 'support.dart';
import 'window_caption_test.dart' show FakeWindow;

void main() {
  testWidgets('icon axis stays aligned through sidebar spring in LTR and RTL', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    for (final direction in TextDirection.values) {
      await tester.pumpWidget(
        frostTestApp(
          Directionality(
            textDirection: direction,
            child: FrostWindowCaptionScope(
              // Native window buttons stay on the right, where a right-to-left
              // caption row would put Back; without them Back sits on the axis.
              window: direction == TextDirection.ltr ? FakeWindow() : null,
              child: FrostShell(
                key: ValueKey(direction),
                destinations: const [FrostNavDestination(icon: FrostIconData.glyph(Icons.home), label: 'Home')],
                selectedIndex: 0,
                atDestinationRoot: true,
                canGoBack: false,
                onBack: () {},
                onDestinationSelected: (_) {},
                showsMobileNavigation: true,
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ),
      );
      double axis(Finder item) => tester.getCenter(find.descendant(of: item, matching: find.byType(FrostIcon))).dx;
      final back = find.byKey(const ValueKey('frost-shell-back'));
      final nav = find.byType(FrostNavItem);
      expect(axis(nav), axis(back));
      await tester.tap(findFrostTooltip('L.expandNavigation'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      expect(axis(nav), closeTo(axis(back), 1e-6));
      await tester.pumpAndSettle();
      expect(axis(nav), closeTo(axis(back), 1e-6));
      expect(tester.takeException(), isNull);
    }
  });
  for (final platform in [TargetPlatform.windows, TargetPlatform.linux, TargetPlatform.macOS]) {
    for (final expanded in [false, true]) {
      testWidgets('Back shares stationary icon column $platform expanded=$expanded', (tester) async {
        tester.view.physicalSize = const Size(1440, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final window = platform == TargetPlatform.windows ? FakeWindow() : null;
        var canBack = false;
        FrostNavigationPlacement? placement;
        late StateSetter update;
        await tester.pumpWidget(
          frostTestApp(
            StatefulBuilder(
              builder: (_, setState) {
                update = setState;
                return FrostWindowCaptionScope(
                  window: window,
                  child: FrostShell(
                    navigationPlacement: placement,
                    destinations: const [FrostNavDestination(icon: FrostIconData.glyph(Icons.home), label: 'Home')],
                    selectedIndex: 0,
                    atDestinationRoot: !canBack,
                    canGoBack: canBack,
                    onBack: () {},
                    onDestinationSelected: (_) {},
                    showsMobileNavigation: true,
                    initiallyExpanded: expanded,
                    brand: const FrostShellBrand(expanded: Text('Brand', key: ValueKey('brand'))),
                    child: const SizedBox.expand(key: ValueKey('content')),
                  ),
                );
              },
            ),
            platform: platform,
            density: FrostDensity.compact,
          ),
        );
        final back = find.byKey(const ValueKey('frost-shell-back'));
        final arrow = find.descendant(of: back, matching: find.byType(FrostIcon));
        final navigation = find.byType(FrostNavItem);
        final icon = find.descendant(of: navigation, matching: find.byType(FrostIcon));
        expect(tester.getCenter(arrow).dx, tester.getCenter(icon).dx);
        expect(tester.getCenter(arrow).dx, 30);
        final brand = window == null ? null : tester.getRect(find.byKey(const ValueKey('brand')));
        final rect = tester.getRect(back);
        if (window != null) {
          expect(rect.size, const Size(60, 40));
          expect(rect.left, 0);
          expect(rect.top, 0);
          expect(tester.getSize(arrow), const Size(20, 20));
          expect(rect.right, lessThanOrEqualTo(brand!.left));
        } else {
          // The sidebar back is a plain icon button in the rail's first row.
          expect(rect.size, const Size(36, 36));
          expect(find.byKey(const ValueKey('brand')), findsOneWidget);
          // The button is centred in the 40-high row, whose top matches the content's.
          expect(tester.getTopLeft(find.byKey(const ValueKey('content'))).dy, tester.getTopLeft(back).dy - 2);
          expect(tester.widget<FrostButton>(back).onPressed, isNull);
        }
        update(() => canBack = true);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 70));
        expect(tester.getRect(back), rect);
        if (window != null) {
          expect(tester.getRect(find.byKey(const ValueKey('brand'))), brand);
          expect(window.calls.last.where((r) => r.kind == FrostHitKind.caption).any((r) => r.rect.contains(rect.center)), isFalse);
          expect(window.calls.last.where((r) => r.kind == FrostHitKind.caption).any((r) => r.rect.contains(brand!.center)), isTrue);
          // Pointer windows keep a sidebar on resize. Exercise the same
          // bottom-mode alignment assertions through the explicit App choice.
          update(() => placement = FrostNavigationPlacement.bottom);
          tester.view.physicalSize = const Size(390, 900);
          await tester.pumpAndSettle();
          expect(back, findsNothing);
          expect(tester.getTopLeft(find.byKey(const ValueKey('content'))).dy, 40);
        }
        expect(tester.takeException(), isNull);
      });
    }
  }
}
