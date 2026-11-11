import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/navigation/window_caption.dart' show FrostCaptionButtons;

import 'support.dart';
import 'window_caption_test.dart' show FakeWindow;

const _brandKey = ValueKey('brand');
const _searchKey = ValueKey('search');
Finder get _back => find.byKey(const ValueKey('frost-shell-back'));

/// A window in each caption arrangement the title row handles.
enum _Window {
  windows(TargetPlatform.windows),
  mac(TargetPlatform.macOS),
  linuxRight(TargetPlatform.linux),
  linuxLeft(TargetPlatform.linux);

  const _Window(this.platform);
  final TargetPlatform platform;

  static const _traffic = Rect.fromLTWH(12, 12, 52, 16);

  FakeWindow fake() => FakeWindow()
    ..current = switch (this) {
      windows => const FrostCaptionState(maximized: false, active: true, maximizeHovered: false, maximizePressed: false, failed: false),
      mac => const FrostCaptionState(
        maximized: false,
        active: true,
        maximizeHovered: false,
        maximizePressed: false,
        failed: false,
        mode: FrostCaptionMode.nativeControls,
        rightButtons: [],
        nativeControls: _traffic,
      ),
      linuxRight => const FrostCaptionState(
        maximized: false,
        active: true,
        maximizeHovered: false,
        maximizePressed: false,
        failed: false,
        style: FrostCaptionStyle.adwaita,
        rightButtons: [FrostCaptionAction.close],
      ),
      linuxLeft => const FrostCaptionState(
        maximized: false,
        active: true,
        maximizeHovered: false,
        maximizePressed: false,
        failed: false,
        style: FrostCaptionStyle.adwaita,
        leftButtons: [FrostCaptionAction.close, FrostCaptionAction.minimize],
        rightButtons: [],
      ),
    };
}

Widget _shell(_Window window, {bool expanded = true, bool search = false}) => frostTestApp(
  FrostWindowCaptionScope(
    window: window.fake(),
    child: FrostShell(
      destinations: const [
        FrostNavDestination(icon: FrostIconData.glyph(Icons.home), label: 'Browse'),
        FrostNavDestination(icon: FrostIconData.glyph(Icons.tag), label: 'Tags'),
      ],
      selectedIndex: 0,
      atDestinationRoot: false,
      canGoBack: true,
      onBack: () {},
      onDestinationSelected: (_) {},
      showsMobileNavigation: true,
      initiallyExpanded: expanded,
      brand: const FrostShellBrand(expanded: FrostText('BooruFlow', key: _brandKey)),
      titleBarSearch: search ? const SizedBox(key: _searchKey, height: 28) : null,
      titleBarSearchPlacement: FrostCaptionSearchPlacement.end,
      child: FrostShellDestination(
        child: Scaffold(
          body: Column(
            children: [
              FrostPageHeader(title: FrostText('Post 42')),
              const Expanded(child: SizedBox.expand()),
            ],
          ),
        ),
      ),
    ),
  ),
  platform: window.platform,
);

Future<void> _pump(WidgetTester tester, Widget app) async {
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(app);
  await tester.pumpAndSettle();
}

Rect _title(WidgetTester tester) => tester.getRect(
  find.text('Post 42').evaluate().where((e) => e.findAncestorWidgetOfExactType<Opacity>()?.opacity != 0).map((e) => find.byWidget(e.widget)).single,
);

void main() {
  for (final window in _Window.values) {
    testWidgets('${window.name}: Back, then the page title, in the title row, and Back holds its place as the sidebar collapses', (tester) async {
      await _pump(tester, _shell(window));
      final back = tester.getRect(_back);
      final title = _title(tester);
      expect(back.center.dy, lessThan(48), reason: 'Back is in the title row, not a sidebar row');
      expect(title.left, greaterThanOrEqualTo(back.right));
      expect(title.center.dy, closeTo(back.center.dy, 2));
      switch (window) {
        case _Window.mac:
          expect(back.left, greaterThanOrEqualTo(_Window._traffic.right), reason: 'after the traffic lights');
          expect(find.byKey(_brandKey), findsNothing, reason: 'no app name in a macOS window');
        case _Window.linuxLeft:
          expect(back.left, greaterThanOrEqualTo(tester.getRect(find.byType(FrostCaptionButtons)).right), reason: 'after the window buttons');
        case _Window.windows || _Window.linuxRight:
          expect(back.left, 0, reason: 'at the row\'s leading edge');
          expect(tester.getRect(find.byKey(_brandKey)).left, greaterThanOrEqualTo(back.right));
      }
      await _pump(tester, _shell(window, expanded: false));
      expect(tester.getRect(_back), back, reason: 'the same place with the sidebar collapsed');
      expect(tester.takeException(), isNull);
    });

    testWidgets('${window.name}: the order is Back, title, search', (tester) async {
      await _pump(tester, _shell(window, search: true));
      final back = tester.getRect(_back), title = _title(tester), search = tester.getRect(find.byKey(_searchKey));
      expect(back.right, lessThanOrEqualTo(title.left));
      expect(title.right, lessThanOrEqualTo(search.left));
      expect(tester.takeException(), isNull);
    });
  }
}
