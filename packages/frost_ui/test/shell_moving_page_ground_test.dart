import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:material_ui/material_ui.dart';

import 'ambient_transition_test.dart' show complete;
import 'media_frame_test.dart' show ControlledImage;
import 'support.dart';

final _paint = find.byWidgetPredicate((widget) => widget.runtimeType.toString() == '_AmbientPaint');

Future<GlobalKey<NavigatorState>> _app(WidgetTester tester, {required Size size, required TargetPlatform platform}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final navigator = GlobalKey<NavigatorState>();
  final art = ControlledImage();
  await tester.pumpWidget(
    frostTestApp(
      FrostAmbientBackdropHost(
        image: art,
        child: FrostShell(
          destinations: const [
            FrostNavDestination(icon: FrostIconData.glyph(Icons.home), label: 'Home'),
            FrostNavDestination(icon: FrostIconData.glyph(Icons.search), label: 'Find'),
          ],
          selectedIndex: 0,
          atDestinationRoot: true,
          onDestinationSelected: (_) {},
          canGoBack: false,
          onBack: () {},
          showsMobileNavigation: true,
          child: FrostShellDestination(
            child: Navigator(
              key: navigator,
              onGenerateRoute: (_) => PageRouteBuilder<void>(pageBuilder: (_, _, _) => const SizedBox.expand()),
            ),
          ),
        ),
      ),
      brightness: Brightness.dark,
      platform: platform,
    ),
  );
  await complete(tester, art, Colors.purple);
  await tester.pumpAndSettle();
  return navigator;
}

/// Ambient art painted inside the shell's navigator, under a moving page.
Finder _artIn(GlobalKey<NavigatorState> navigator) => find.descendant(of: find.byKey(navigator), matching: _paint);

/// The fill the shell's pages rest on, painted inside its navigator.
Finder _restingFillIn(WidgetTester tester, GlobalKey<NavigatorState> navigator) {
  final fill = FrostSurfaceScope.maybeOf(tester.element(find.byKey(navigator)))!.background;
  return find.descendant(
    of: find.byKey(navigator),
    matching: find.byWidgetPredicate((widget) => widget is ColoredBox && widget.color.a > 0 && widget.color.withValues(alpha: 1) == fill),
  );
}

void main() {
  for (final (layout, size) in [('the compact shell', const Size(400, 800)), ('the sidebar layout', const Size(1147, 717))]) {
    for (final media in [false, true]) {
      final kind = media ? 'media' : 'ordinary';
      testWidgets('in $layout a moving $kind page carries the fill it rests on', (tester) async {
        final navigator = await _app(tester, size: size, platform: media ? TargetPlatform.android : TargetPlatform.windows);
        expect(find.byType(FrostNavItem), size.width > 600 ? findsWidgets : findsNothing);
        final page = media ? const FrostDetailPage<void>.media(child: SizedBox.expand()) : const FrostDetailPage<void>(child: SizedBox.expand());
        navigator.currentState!.push(page.createRoute(navigator.currentContext!));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 80));
        expect(_artIn(navigator), findsNothing, reason: 'pushing in');
        expect(_restingFillIn(tester, navigator), findsWidgets);
        await tester.pumpAndSettle();
        expect(_artIn(navigator), findsNothing, reason: 'at rest');

        navigator.currentState!.pop();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 80));
        expect(_artIn(navigator), findsNothing, reason: 'popping');
        expect(_restingFillIn(tester, navigator), findsWidgets);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }
}
