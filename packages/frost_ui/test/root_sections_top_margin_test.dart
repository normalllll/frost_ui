import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:material_ui/material_ui.dart';

import 'support.dart';

class _Page extends StatefulWidget {
  const _Page({required this.tabs});
  final bool tabs;
  @override
  State<_Page> createState() => _PageState();
}

class _PageState extends State<_Page> with SingleTickerProviderStateMixin {
  late final _tabs = FrostTabController(length: 2, vsync: this);
  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const header = FrostPageHeader(title: FrostText('Home page'));
    return FrostPinnedChrome(
      key: const ValueKey('page'),
      chrome: widget.tabs
          ? FrostHeaderSections(
              header: header,
              tabs: FrostTabBar(
                controller: _tabs,
                scrollable: true,
                tabs: const [
                  FrostTab(label: 'Illust'),
                  FrostTab(label: 'Manga'),
                ],
              ),
            )
          : header,
      body: const CustomScrollView(
        slivers: [
          FrostChromeSpacer(),
          SliverToBoxAdapter(
            child: FrostContentColumn(
              maxWidth: double.infinity,
              child: SizedBox(key: ValueKey('content'), height: 40),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _pump(WidgetTester tester, {required bool tabs}) async {
  tester.view.physicalSize = const Size(1147, 717);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    frostTestApp(
      FrostShell(
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
        brand: const FrostShellBrand(expanded: Text('Application')),
        child: FrostShellDestination(child: _Page(tabs: tabs)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  const content = ValueKey('content');

  testWidgets('section tabs below a title-only root header start at the content top, on the content edge', (tester) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester, tabs: true);
    final page = tester.getTopLeft(find.byKey(const ValueKey('page')));
    final tabs = tester.getRect(find.byType(FrostTabBar));
    expect(tabs.top, page.dy);
    expect(tester.getTopLeft(find.text('Illust')).dx, moreOrLessEquals(tester.getTopLeft(find.byKey(content)).dx, epsilon: .5));
    expect(tester.getTopLeft(find.byKey(content)).dy, tabs.bottom);
    expect(tester.getSemantics(find.bySemanticsLabel('Home page')).getSemanticsData().flagsCollection.isHeader, isTrue);
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });

  testWidgets('a title-only root header without tabs keeps the top margin', (tester) async {
    await _pump(tester, tabs: false);
    final context = tester.element(find.byType(FrostPageHeader));
    final page = tester.getTopLeft(find.byKey(const ValueKey('page')));
    expect(tester.getTopLeft(find.byKey(content)).dy - page.dy, FrostGap.of(context).page);
    expect(tester.takeException(), isNull);
  });
}
