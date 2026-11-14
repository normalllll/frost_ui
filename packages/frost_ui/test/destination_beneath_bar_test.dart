import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/layout/content_viewport.dart' show FrostSliverFillPage;

import 'support.dart';

const _home = FrostIconData.glyph(IconData(0xe101));
const _library = FrostIconData.glyph(IconData(0xe102));

Widget _shell(Widget page) => FrostInputFeedback(
  child: frostTestApp(
    FrostShell(
      destinations: [
        FrostNavDestination(icon: _home, label: 'Home'),
        FrostNavDestination(icon: _library, label: 'Library'),
      ],
      selectedIndex: 0,
      atDestinationRoot: true,
      onDestinationSelected: (_) {},
      canGoBack: false,
      onBack: () {},
      showsMobileNavigation: true,
      child: FrostShellDestination(child: page),
    ),
    platform: TargetPlatform.android,
  ),
);

void _window(WidgetTester tester, double width, double height) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Widget _list({ScrollController? controller}) => FrostPinnedChrome(
  chrome: const FrostPageHeader(title: FrostText('Browse')),
  body: FrostLoadingScrollView(
    controller: controller,
    slivers: [
      SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => SizedBox(key: ValueKey('row $index'), height: 60, child: FrostText('Row $index')),
          childCount: 40,
        ),
      ),
    ],
  ),
);

/// The bottom navigation bar's surface.
Finder _bar() => find.ancestor(of: find.text('Library'), matching: find.byType(FrostSurface)).first;

Rect _barRect(WidgetTester tester) => tester.getRect(_bar());

void main() {
  testWidgets('a root page scrolls beneath the bottom bar and its last item ends above it', (tester) async {
    _window(tester, 400, 800);
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_shell(_list(controller: controller)));
    await tester.pumpAndSettle();

    final bar = _barRect(tester);
    expect(bar.bottom, 800);
    expect(bar.height, greaterThan(0));
    final viewport = tester.getRect(find.byType(Scrollable).first);
    expect(viewport.bottom, bar.bottom, reason: 'the viewport runs beneath the bar');

    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byKey(const ValueKey('row 39'))).bottom, lessThanOrEqualTo(bar.top + .01));
    expect(tester.getRect(find.byKey(const ValueKey('row 39'))).bottom, greaterThan(bar.top - 1));
  });

  testWidgets('the bar and the pinned header share one backdrop read', (tester) async {
    _window(tester, 400, 800);
    await tester.pumpWidget(_shell(_list()));
    await tester.pumpAndSettle();
    final barFilter = tester.renderObject<RenderBackdropFilter>(find.descendant(of: _bar(), matching: find.byType(BackdropFilter)).first);
    // The pinned header's glass lies behind its row, not around it.
    final others = tester.renderObjectList<RenderBackdropFilter>(find.byType(BackdropFilter)).where((filter) => filter != barFilter).toList();
    expect(barFilter.backdropKey, isNotNull);
    expect(others, isNotEmpty);
    for (final filter in others) {
      expect(filter.backdropKey, same(barFilter.backdropKey));
    }
  });

  testWidgets('an empty state is placed in the area above the bar and does not scroll', (tester) async {
    _window(tester, 400, 800);
    await tester.pumpWidget(
      _shell(
        const FrostLoadingScrollView(
          slivers: [FrostSliverFillPage(child: FrostEmptyState(title: 'Nothing here'))],
        ),
      ),
    );
    await tester.pumpAndSettle();
    final bar = _barRect(tester);
    final title = tester.getRect(find.text('Nothing here'));
    // The summary starts a quarter down the height above the bar.
    expect(title.top, moreOrLessEquals(bar.top * .25, epsilon: 1));
    final position = tester.state<ScrollableState>(find.byType(Scrollable).first).position;
    expect(position.maxScrollExtent, 0);
  });

  testWidgets('a toast and a floating action stay above the bar', (tester) async {
    _window(tester, 400, 800);
    await tester.pumpWidget(_shell(FrostFloatingActionLayer(label: 'Add', icon: _home, onPressed: () {}, child: const SizedBox.expand())));
    await tester.pumpAndSettle();
    final bar = _barRect(tester);
    final action = tester.getRect(find.bySemanticsLabel('Add').first);
    expect(action.bottom, lessThan(bar.top));
    expect(action.bottom, greaterThan(bar.top - 40));

    FrostToast.info('Saved');
    await tester.pumpAndSettle();
    final toast = tester.getRect(find.text('Saved'));
    expect(toast.bottom, lessThan(bar.top));
    expect(toast.bottom, greaterThan(bar.top - 80));
    await tester.pumpAndSettle(const Duration(seconds: 10));
  });

  testWidgets('with the sidebar the page keeps its bottom edge and padding', (tester) async {
    _window(tester, 1400, 800);
    late EdgeInsets padding;
    await tester.pumpWidget(
      _shell(
        Builder(
          builder: (context) {
            padding = MediaQuery.paddingOf(context);
            return const SizedBox.expand();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(padding.bottom, 0);
  });
}
