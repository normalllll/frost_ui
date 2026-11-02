import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/navigation/_destination_status.dart' show FrostDestinationTrailing;

import 'support.dart';

const _library = FrostIconData.glyph(IconData(0xe101));
const _downloads = FrostIconData.glyph(IconData(0xe102));

Widget _shell({required double scale, FrostCountBadgeTone tone = FrostCountBadgeTone.accent, bool expanded = false}) => Builder(
  builder: (context) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: FrostShell(
      navigationPlacement: FrostNavigationPlacement.sidebar,
      destinations: [
        FrostNavDestination(icon: _library, label: 'Library'),
        FrostNavDestination(icon: _downloads, label: 'Downloads', badge: 3, badgeTone: tone),
      ],
      selectedIndex: 0,
      atDestinationRoot: true,
      onDestinationSelected: (_) {},
      canGoBack: false,
      onBack: () {},
      showsMobileNavigation: true,
      initiallyExpanded: expanded,
      child: const FrostShellDestination(child: SizedBox.expand()),
    ),
  ),
);

Rect _rect(WidgetTester tester, Element element) {
  final box = element.renderObject! as RenderBox;
  return box.localToGlobal(Offset.zero) & box.size;
}

void main() {
  for (final width in [1000.0, 390.0]) {
    testWidgets('an icon count stays on its own icon at 2x text width=$width', (tester) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      Rect? normal;
      for (final scale in [1.0, 2.0]) {
        await tester.pumpWidget(frostTestApp(_shell(scale: scale)));
        await tester.pumpAndSettle();
        final badge = find.byWidgetPredicate((widget) => widget is FrostCountBadge && widget.count == 3);
        final rect = _rect(tester, badge.evaluate().single);
        final icon = tester.getRect(find.byWidgetPredicate((widget) => widget is FrostIcon && widget.icon == _downloads));
        final library = tester.getRect(find.byWidgetPredicate((widget) => widget is FrostIcon && widget.icon == _library));
        normal ??= rect;
        // The same size as at 1x, centred on the icon's top trailing corner,
        // and clear of the destination above.
        expect(rect.size, normal.size, reason: 'scale $scale');
        expect(rect.center.dx, moreOrLessEquals(icon.right - 4), reason: 'scale $scale');
        expect(rect.center.dy, moreOrLessEquals(icon.top + 4), reason: 'scale $scale');
        expect(rect.top, greaterThan(library.bottom), reason: 'scale $scale');
      }
    });
  }

  testWidgets('a negative destination count uses the negative badge and expanded ink', (tester) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(frostTestApp(_shell(scale: 1, tone: FrostCountBadgeTone.negative)));
    await tester.pumpAndSettle();
    expect(
      tester.widget<FrostCountBadge>(find.byWidgetPredicate((widget) => widget is FrostCountBadge && widget.count == 3)).tone,
      FrostCountBadgeTone.negative,
    );

    tester.view.physicalSize = const Size(1400, 800);
    await tester.pumpWidget(frostTestApp(_shell(scale: 1, tone: FrostCountBadgeTone.negative, expanded: true)));
    await tester.pumpAndSettle();
    final count = tester.widget<FrostRollingText>(find.descendant(of: find.byType(FrostDestinationTrailing), matching: find.byType(FrostRollingText)));
    final tokens = FrostThemeTokens.of(tester.element(find.byType(FrostShell)));
    expect(count.style!.color, tokens.negativeInk);
  });
}
