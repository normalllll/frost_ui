import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/navigation/window_caption.dart' show FrostCaptionButtons;

import 'support.dart';
import 'window_caption_test.dart' show FakeWindow, host;

void main() {
  void window(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Widget shell() => FrostShell(
    destinations: const [],
    selectedIndex: null,
    onDestinationSelected: (_) {},
    showsMobileNavigation: true,
    atDestinationRoot: true,
    canGoBack: false,
    onBack: () {},
    child: const SizedBox.expand(key: ValueKey('page')),
  );

  for (final (name, size) in [('wide', const Size(1147, 717)), ('narrow', const Size(390, 844))]) {
    testWidgets('a shell without destinations is only the title row over the page ($name)', (tester) async {
      window(tester, size);
      await tester.pumpWidget(host(FakeWindow(), shell()));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final page = tester.getRect(find.byKey(const ValueKey('page')));
      expect(page.left, 0);
      expect(page.right, size.width);
      expect(page.bottom, size.height);
      expect(find.byType(FrostCaptionButtons), findsOneWidget);
      final caption = tester.getRect(find.byType(FrostCaptionButtons));
      expect(page.top, greaterThanOrEqualTo(caption.bottom));
    });
  }

  testWidgets('a shell without a window and without destinations shows the page alone', (tester) async {
    window(tester, const Size(1147, 717));
    await tester.pumpWidget(frostTestApp(shell()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(tester.getRect(find.byKey(const ValueKey('page'))), const Rect.fromLTWH(0, 0, 1147, 717));
  });
}
