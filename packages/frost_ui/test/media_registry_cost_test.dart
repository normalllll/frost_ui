import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/surface/_window_background.dart';
import 'package:material_ui/material_ui.dart';

import 'support.dart';

void main() {
  testWidgets('a frame reads the window rects of on-screen media only, none in the scroll cache or a covered page', (tester) async {
    final navigator = GlobalKey<NavigatorState>();
    final grid = ScrollController();
    addTearDown(grid.dispose);
    await tester.pumpWidget(
      frostTestApp(
        FrostAmbientBackdropHost(
          image: null,
          child: Stack(
            children: [
              Navigator(
                key: navigator,
                onGenerateRoute: (_) => MaterialPageRoute<void>(
                  builder: (_) => GridView.builder(
                    controller: grid,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4),
                    itemCount: 200,
                    itemBuilder: (_, _) => const FrostMediaCard(aspectRatio: 1, media: ColoredBox(color: Color(0xFF808080))),
                  ),
                ),
              ),
              const Positioned(
                left: 0,
                top: 0,
                right: 0,
                height: 52,
                child: FrostSurface(role: FrostSurfaceRole.chrome, child: SizedBox.expand()),
              ),
            ],
          ),
        ),
        brightness: Brightness.dark,
      ),
    );
    grid.jumpTo(130);
    await tester.pumpAndSettle();

    final window = Offset.zero & (tester.view.physicalSize / tester.view.devicePixelRatio);
    final built = find.byType(FrostMediaCard, skipOffstage: false).evaluate().length;
    Rect rectOf(Element card) {
      final box = card.renderObject! as RenderBox;
      return box.localToGlobal(Offset.zero) & box.size;
    }

    final onScreen = find.byType(FrostMediaCard).evaluate().where((card) => rectOf(card).overlaps(window)).length;
    expect(built, greaterThan(onScreen), reason: 'the scroll cache holds cards that are laid out but not painted');

    // One scrolled frame: the chrome's paint and the check after the frame
    // share one reading per phase, and each reading skips the cache.
    FrostAmbientCardRegistry.debugRectEvaluations = 0;
    grid.jumpTo(140);
    await tester.pump();
    expect(FrostAmbientCardRegistry.debugRectEvaluations, inInclusiveRange(onScreen, onScreen * 2));
    final guard = tester.renderObject<FrostRenderChromeMediaGuard>(find.byType(FrostChromeMediaGuard));
    final overMedia = guard.debugEffectiveAlpha;
    expect(overMedia, greaterThan(.5), reason: 'the media under the chrome still counts');

    navigator.currentState!.push(MaterialPageRoute<void>(builder: (_) => const ColoredBox(color: Color(0xFF000000))));
    await tester.pumpAndSettle();
    FrostAmbientCardRegistry.debugRectEvaluations = 0;
    tester.binding.scheduleFrame();
    await tester.pump();
    expect(FrostAmbientCardRegistry.debugRectEvaluations, 0, reason: 'the covered page keeps its cards registered but paints none');
    await tester.pumpAndSettle();
    expect(guard.debugEffectiveAlpha, lessThan(overMedia), reason: 'the chrome eases back once the media is covered');
    expect(tester.takeException(), isNull);
  });
}
