import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/layout/window_caption_scope.dart' show FrostHitKind;
import 'package:material_ui/material_ui.dart';

import 'support.dart';
import 'window_caption_test.dart' show FakeWindow;

const _destinations = [
  FrostNavDestination(icon: FrostIconData.glyph(Icons.home), label: 'Home'),
  FrostNavDestination(icon: FrostIconData.glyph(Icons.search), label: 'Find'),
];

void _window(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Widget _shell(
  WidgetTester tester, {
  double textScale = 1,
  Widget? search,
  FrostNavigationPlacement placement = FrostNavigationPlacement.automatic,
  FrostShellBrand? brand,
  Widget page = const SizedBox.expand(),
  List<FrostShellAction> actions = const [],
  FakeWindow? window,
}) {
  window ??= FakeWindow();
  addTearDown(window.dispose);
  return frostTestApp(
    Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
        child: FrostWindowCaptionScope(
          window: window,
          child: FrostShell(
            navigationPlacement: placement,
            destinations: _destinations,
            selectedIndex: 0,
            atDestinationRoot: true,
            onDestinationSelected: (_) {},
            canGoBack: false,
            onBack: () {},
            showsMobileNavigation: true,
            titleBarSearch: search,
            brand: brand,
            titleBarActions: actions,
            child: FrostShellDestination(child: page),
          ),
        ),
      ),
    ),
  );
}

Widget _search(WidgetTester tester) {
  final controller = TextEditingController(), focus = FocusNode();
  addTearDown(controller.dispose);
  addTearDown(focus.dispose);
  return FrostCaptionSearch(controller: controller, focusNode: focus, placeholder: 'Search', onSubmitted: (_) {});
}

/// The height of the title row: the top of the page content below it.
double _rowHeight(WidgetTester tester) => tester.getTopLeft(find.byType(FrostShellDestination)).dy;

void main() {
  group('title-bar search without tabs', () {
    testWidgets('at double text the row grows and keeps the search', (tester) async {
      _window(tester, const Size(1400, 900));
      await tester.pumpWidget(_shell(tester, textScale: 2, search: _search(tester)));
      await tester.pumpAndSettle();
      expect(find.byType(FrostCaptionSearch), findsOneWidget);
      final field = tester.getRect(find.byType(EditableText));
      expect(field.height, greaterThan(0));
      expect(_rowHeight(tester), greaterThanOrEqualTo(tester.getSize(find.byType(FrostCaptionSearch)).height));
      // Hit-testable at its centre.
      await tester.tap(find.byType(EditableText));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('at normal text the row keeps the height it has without search', (tester) async {
      _window(tester, const Size(1400, 900));
      await tester.pumpWidget(_shell(tester));
      await tester.pumpAndSettle();
      final plain = _rowHeight(tester);
      await tester.pumpWidget(_shell(tester, search: _search(tester)));
      await tester.pumpAndSettle();
      expect(find.byType(FrostCaptionSearch), findsOneWidget);
      expect(_rowHeight(tester), plain);
    });
  });

  group('brand under bottom navigation', () {
    const brand = FrostShellBrand(expanded: FrostText('Brandname'));
    const page = FrostPinnedChrome(
      chrome: FrostContentColumn(
        maxWidth: double.infinity,
        child: FrostPageHeader(title: FrostText('Settings')),
      ),
      body: SizedBox.expand(),
    );

    for (final search in [false, true]) {
      testWidgets('starts on the page header\'s leading edge (search: $search)', (tester) async {
        _window(tester, const Size(1265, 793));
        await tester.pumpWidget(_shell(tester, placement: FrostNavigationPlacement.bottom, brand: brand, page: page, search: search ? _search(tester) : null));
        await tester.pumpAndSettle();
        final label = tester.getRect(find.text('Brandname'));
        final title = tester.getRect(find.text('Settings'));
        expect(label.left, greaterThan(0));
        expect(label.left, moreOrLessEquals(title.left, epsilon: .5));
      });
    }

    testWidgets('the sidebar layout keeps the brand after Back', (tester) async {
      _window(tester, const Size(1265, 793));
      await tester.pumpWidget(_shell(tester, placement: FrostNavigationPlacement.sidebar, brand: brand, page: page));
      await tester.pumpAndSettle();
      final back = tester.getRect(find.byType(FrostShellNavigationScope).first);
      expect(tester.getRect(find.text('Brandname')).left, greaterThan(back.left));
    });
  });

  group('title-row actions', () {
    for (final placement in [FrostNavigationPlacement.sidebar, FrostNavigationPlacement.bottom]) {
      testWidgets('sit after the search and leave the rest of the row to dragging ($placement)', (tester) async {
        _window(tester, const Size(1265, 793));
        final window = FakeWindow();
        var pressed = 0;
        await tester.pumpWidget(
          _shell(
            tester,
            placement: placement,
            search: _search(tester),
            window: window,
            actions: [FrostShellAction(label: 'Cover again', icon: const FrostIconData.glyph(Icons.visibility_off), onPressed: () => pressed++)],
          ),
        );
        await tester.pumpAndSettle();
        final action = find.bySemanticsLabel('Cover again');
        expect(action, findsOneWidget);
        final rect = tester.getRect(action);
        expect(rect.bottom, lessThanOrEqualTo(_rowHeight(tester)));
        final sidebar = placement == FrostNavigationPlacement.sidebar;
        // The search is in the title row only beside a sidebar; there the
        // action follows it.
        final search = sidebar ? tester.getRect(find.byType(FrostCaptionSearch)) : null;
        if (search != null) expect(rect.left, greaterThanOrEqualTo(search.right));
        final caption = window.calls.last.where((region) => region.kind == FrostHitKind.caption);
        final empty = search == null ? Offset(rect.left - 40, rect.center.dy) : Offset(search.left - 20, search.center.dy);
        expect(caption.any((region) => region.rect.contains(empty)), isTrue);
        expect(caption.any((region) => region.rect.contains(rect.center)), isFalse);
        final button = find.byWidgetPredicate((widget) => widget is FrostButton && widget.label == 'Cover again');
        if (sidebar) await tester.tap(find.byType(EditableText));
        await tester.pump();
        var reached = false;
        for (var press = 0; press < 12 && !reached; press++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump();
          final focused = FocusManager.instance.primaryFocus?.context;
          reached = focused != null && find.descendant(of: button, matching: find.byElementPredicate((element) => element == focused)).evaluate().isNotEmpty;
        }
        expect(reached, isTrue, reason: 'Tab reaches the action');
        await tester.tap(action);
        expect(pressed, 1);
      });
    }

    testWidgets('without actions the row has none', (tester) async {
      _window(tester, const Size(1265, 793));
      await tester.pumpWidget(_shell(tester, search: _search(tester)));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Cover again'), findsNothing);
    });
  });
}
