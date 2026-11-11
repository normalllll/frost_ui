import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/desktop.dart';
import 'package:frost_ui/frost_ui.dart';

import 'support.dart';

const _sidebar = Size(1147, 717);
final _desktop = TargetPlatformVariant.only(TargetPlatform.windows);

class _Host extends StatefulWidget {
  const _Host({required this.body, this.actions = const [], this.tabs, super.key});
  final Widget Function(FrostPageHeader header) body;
  final List<FrostToolbarItem> actions;

  /// Shell tabs take the caption, so headers draw their own titles.
  final FrostTabsController<String>? tabs;
  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  String? title;
  void show(String? value) => setState(() => title = value);

  @override
  Widget build(BuildContext context) => FrostShell(
    destinations: const [
      FrostNavDestination(icon: FrostIconData.glyph(Icons.home), label: 'Home'),
      FrostNavDestination(icon: FrostIconData.glyph(Icons.search), label: 'Find'),
    ],
    selectedIndex: 0,
    atDestinationRoot: false,
    onDestinationSelected: (_) {},
    canGoBack: true,
    onBack: () {},
    showsMobileNavigation: true,
    brand: const FrostShellBrand(expanded: Text('Application')),
    tabs: widget.tabs == null
        ? null
        : FrostShellTabs<String>(
            controller: widget.tabs!,
            label: (_, tab) => FrostTabLabel(title: tab),
            countLabel: (count) => '$count tabs',
            closeTooltip: 'Close tab',
            newTabTooltip: 'New tab',
          ),
    child: widget.body(FrostPageHeader(title: title == null ? null : FrostText(title!), actions: widget.actions)),
  );
}

Widget _list(FrostPageHeader header, ScrollController controller) => FrostPinnedChrome(
  key: const ValueKey('page'),
  chrome: header,
  body: CustomScrollView(
    controller: controller,
    slivers: [
      const FrostChromeSpacer(),
      SliverList.builder(
        itemCount: 100,
        itemBuilder: (_, i) => SizedBox(key: ValueKey('item $i'), height: 50),
      ),
    ],
  ),
);

class _Sections extends StatefulWidget {
  const _Sections({required this.header});
  final FrostPageHeader header;
  @override
  State<_Sections> createState() => _SectionsState();
}

class _SectionsState extends State<_Sections> with SingleTickerProviderStateMixin {
  late final _tabs = TabController(length: 2, vsync: this);
  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FrostPinnedChrome(
    key: const ValueKey('page'),
    chrome: widget.header,
    body: NestedScrollView(
      headerSliverBuilder: (context, _) => [
        FrostSliverSectionsHeader(
          lead: const SizedBox(key: ValueKey('lead'), height: 300),
          tabs: FrostTabBar(
            controller: _tabs,
            scrollable: true,
            tabs: const [
              FrostTab(label: 'Posts'),
              FrostTab(label: 'Likes'),
            ],
          ),
        ),
      ],
      body: TabBarView(
        controller: _tabs,
        children: [
          for (final section in ['a', 'b'])
            Builder(
              builder: (context) => CustomScrollView(
                key: PageStorageKey(section),
                primary: true,
                slivers: [
                  SliverOverlapInjector(handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context)),
                  SliverList.builder(
                    itemCount: 100,
                    itemBuilder: (_, i) => SizedBox(height: 50, child: Text('$section$i')),
                  ),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}

void main() {
  late GlobalKey<_HostState> host;
  late ScrollController scroll;
  setUp(() {
    host = GlobalKey<_HostState>();
    scroll = ScrollController();
  });
  tearDown(() {
    scroll.dispose();
  });

  Future<void> pump(
    WidgetTester tester, {
    Size size = _sidebar,
    List<FrostToolbarItem> actions = const [],
    bool sections = false,
    FrostTabsController<String>? tabs,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      frostTestApp(
        _Host(
          key: host,
          actions: actions,
          tabs: tabs,
          body: (header) => sections ? _Sections(header: header) : _list(header, scroll),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> title(WidgetTester tester, String? value) async {
    host.currentState!.show(value);
    await tester.pump();
    await tester.pump();
  }

  double pageTop(WidgetTester tester) => tester.getTopLeft(find.byKey(const ValueKey('page'))).dy;
  double itemTop(WidgetTester tester, int i) => tester.getTopLeft(find.byKey(ValueKey('item $i'))).dy;
  double gap(WidgetTester tester) => FrostGap.of(tester.element(find.byKey(const ValueKey('page')))).page;

  testWidgets('a pushed page with nothing in its header starts at the top margin', (tester) async {
    await pump(tester);
    expect(itemTop(tester, 0) - pageTop(tester), gap(tester));
    expect(gap(tester), lessThan(FrostPageHeader.horizontalHeight));
    expect(tester.takeException(), isNull);
  }, variant: _desktop);

  testWidgets('a title appearing over the scrolled body does not move it, nor does its going', (tester) async {
    await pump(tester);
    scroll.jumpTo(200);
    await tester.pump();
    final before = itemTop(tester, 10);

    await title(tester, 'Title');
    // The shell's top row draws the title; the header keeps an invisible copy for screen readers.
    expect(find.text('Title'), findsNWidgets(2));
    expect(tester.getSize(find.byType(FrostPageHeader)).height, gap(tester));
    expect(itemTop(tester, 10), before);

    await title(tester, null);
    expect(itemTop(tester, 10), before);
    expect(tester.takeException(), isNull);
  }, variant: _desktop);

  testWidgets('a title still shown when the body returns to the top leaves it at the top margin', (tester) async {
    await pump(tester);
    scroll.jumpTo(200);
    await tester.pump();
    await title(tester, 'Title');
    scroll.jumpTo(0);
    await tester.pump();
    await tester.pump();
    expect(itemTop(tester, 0) - pageTop(tester), gap(tester));
    expect(tester.takeException(), isNull);
  }, variant: _desktop);

  testWidgets('a title given at the top leaves the body at the top margin, the shell row drawing it', (tester) async {
    await pump(tester);
    await title(tester, 'Title');
    expect(itemTop(tester, 0) - pageTop(tester), gap(tester));
    expect(tester.takeException(), isNull);
  }, variant: _desktop);

  testWidgets('a header with actions keeps its row', (tester) async {
    await pump(
      tester,
      actions: [FrostToolbarItem.action(icon: testIcons.add, label: 'Sync', onPressed: () {})],
    );
    expect(itemTop(tester, 0) - pageTop(tester), FrostPageHeader.horizontalHeight);
    expect(tester.takeException(), isNull);
  }, variant: _desktop);

  testWidgets('a narrow page with its own Back keeps its row', (tester) async {
    await pump(tester, size: const Size(390, 717));
    expect(find.byType(FrostCompactBackButton), findsOneWidget);
    expect(itemTop(tester, 0) - pageTop(tester), FrostPageHeader.verticalHeight);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('where the shell row draws titles the tabs stick right under the top margin, still as the title comes and goes', (tester) async {
    await pump(tester, sections: true);
    final top = pageTop(tester), margin = gap(tester);
    expect(tester.getTopLeft(find.byKey(const ValueKey('lead'))).dy - top, margin);

    final outer = tester.state<NestedScrollViewState>(find.byType(NestedScrollView)).outerController;
    outer.jumpTo(outer.position.maxScrollExtent >= 1000 ? 1000 : outer.position.maxScrollExtent);
    await tester.pump();
    await tester.pump();
    final stuck = tester.getTopLeft(find.byType(FrostTabBar)).dy, first = tester.getTopLeft(find.text('a0')).dy;
    expect(stuck - top, margin - 12, reason: 'tucked under the margin, with no room kept for a row a title will not bring');

    await title(tester, 'Name');
    expect(tester.getSize(find.byType(FrostPageHeader)).height, margin);
    expect(tester.getTopLeft(find.byType(FrostTabBar)).dy, stuck);
    expect(tester.getTopLeft(find.text('a0')).dy, first);
    await title(tester, null);
    expect(tester.getTopLeft(find.byType(FrostTabBar)).dy, stuck);
    expect(tester.getTopLeft(find.text('a0')).dy, first);
    expect(tester.takeException(), isNull);
  }, variant: _desktop);

  testWidgets('where the header would draw the title the tabs stick under the row it brings, without moving when it comes', (tester) async {
    final tabs = FrostTabsController<String>.withBaseTab(baseTab: 'Home');
    addTearDown(tabs.dispose);
    await pump(tester, sections: true, tabs: tabs);
    final top = pageTop(tester), margin = gap(tester);
    expect(tester.getTopLeft(find.byKey(const ValueKey('lead'))).dy - top, margin);

    final outer = tester.state<NestedScrollViewState>(find.byType(NestedScrollView)).outerController;
    outer.jumpTo(outer.position.maxScrollExtent >= 1000 ? 1000 : outer.position.maxScrollExtent);
    await tester.pump();
    await tester.pump();
    final stuck = tester.getTopLeft(find.byType(FrostTabBar)).dy, first = tester.getTopLeft(find.text('a0')).dy;
    expect(stuck - top, FrostPageHeader.horizontalHeight - 12);

    await title(tester, 'Name');
    expect(find.text('Name'), findsOneWidget, reason: 'the header draws it');
    expect(tester.getTopLeft(find.byType(FrostTabBar)).dy, stuck);
    expect(tester.getTopLeft(find.text('a0')).dy, first);
    expect(tester.takeException(), isNull);
  }, variant: _desktop);
}
