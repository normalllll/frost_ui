import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';

import 'support.dart';

typedef _Page = Widget Function(String title, List<FrostToolbarItem> actions);

Widget _plain(String title, List<FrostToolbarItem> actions) => Column(
  children: [
    FrostPageHeader(title: FrostText(title), actions: actions),
    const Expanded(child: SizedBox.expand()),
  ],
);

Widget _app({bool pushed = false, bool secondary = false, List<FrostToolbarItem> actions = const [], _Page page = _plain}) => frostTestApp(
  FrostShell(
    destinations: [
      FrostNavDestination(icon: testIcons.image, label: 'Home'),
      FrostNavDestination(icon: testIcons.search, label: 'Activity'),
    ],
    selectedIndex: secondary ? null : 0,
    secondary: FrostShellSecondary(
      destinations: [FrostNavDestination(icon: testIcons.add, label: 'Downloads')],
      selectedIndex: secondary ? 0 : null,
      onSelected: (_) {},
    ),
    atDestinationRoot: !pushed && !secondary,
    onDestinationSelected: (_) {},
    canGoBack: pushed || secondary,
    onBack: () {},
    showsMobileNavigation: true,
    child: Navigator(
      pages: [
        FrostDetailPage<void>(
          key: const ValueKey('root'),
          child: FrostShellDestination(child: page('Home page', actions)),
        ),
        if (secondary) FrostDetailPage<void>.secondaryDestination(key: const ValueKey('downloads'), child: page('Downloads page', const [])),
        if (pushed) FrostDetailPage<void>(key: const ValueKey('ranking'), child: page('Ranking page', const [])),
      ],
      onDidRemovePage: (_) {},
    ),
  ),
);

void _window(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

const _sidebar = Size(1147, 717), _phone = Size(390, 844);

/// The side inset of a page in the sidebar layout.
const _inset = 24.0;

Widget _sectioned(String title, List<FrostToolbarItem> actions) => _SectionedPage(title: title, actions: actions);

class _SectionedPage extends StatefulWidget {
  const _SectionedPage({required this.title, required this.actions});
  final String title;
  final List<FrostToolbarItem> actions;
  @override
  State<_SectionedPage> createState() => _SectionedPageState();
}

class _SectionedPageState extends State<_SectionedPage> with SingleTickerProviderStateMixin {
  late final _tabs = TabController(length: 6, vsync: this);
  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FrostPinnedChrome(
    chrome: FrostHeaderSections(
      header: FrostPageHeader(title: FrostText(widget.title), actions: widget.actions),
      tabs: FrostTabBar(
        controller: _tabs,
        scrollable: true,
        tabs: [
          for (final label in const ['Illust', 'Manga', 'Novel', 'Series', 'Users', 'Tags']) FrostTab(label: label),
        ],
      ),
    ),
    body: CustomScrollView(
      slivers: [
        const FrostChromeSpacer(),
        FrostSliverContentColumn(
          sliver: SliverToBoxAdapter(child: FrostSectionHeader(title: 'Rankings ${widget.title}')),
        ),
      ],
    ),
  );
}

Widget _account(String title, List<FrostToolbarItem> actions) => FrostPinnedChrome(
  chrome: FrostPageHeader(title: FrostText(title), actions: actions),
  body: CustomScrollView(
    slivers: [
      const FrostChromeSpacer(),
      FrostSliverContentColumn(
        sliver: SliverToBoxAdapter(child: SizedBox(key: ValueKey('block $title'), height: 80)),
      ),
    ],
  ),
);

Widget _settings(String title, List<FrostToolbarItem> actions) => FrostSettingsSections(
  header: FrostPageHeader(title: FrostText(title), actions: actions),
  labels: const ['Appearance', 'Storage'],
  selectedIndex: 0,
  onSelected: (_) {},
  sectionBuilder: (_, _) => FrostContentColumn(child: SizedBox(key: ValueKey('block $title'), height: 80)),
);

void main() {
  testWidgets('in the sidebar layout a root page header leaves its title to the shell row and is only the top margin', (tester) async {
    final semantics = tester.ensureSemantics();
    _window(tester, _sidebar);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    expect(_inHeader('Home page'), isFalse);
    expect(_visible('Home page'), isTrue);
    expect(find.bySemanticsLabel('Home page'), findsOneWidget);
    expect(tester.getSemantics(find.bySemanticsLabel('Home page')).getSemanticsData().flagsCollection.isHeader, isTrue);
    expect(tester.getSize(find.byType(FrostPageHeader)).height, _inset);
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });

  testWidgets('a root header with actions keeps its row without the title', (tester) async {
    _window(tester, _sidebar);
    await tester.pumpWidget(
      _app(
        actions: [FrostToolbarItem.action(icon: testIcons.add, label: 'Sync', onPressed: () {})],
      ),
    );
    await tester.pumpAndSettle();
    expect(_inHeader('Home page'), isFalse);
    expect(tester.getSize(find.byType(FrostPageHeader)).height, greaterThan(_inset));
    expect(tester.takeException(), isNull);
  });

  testWidgets('with the bottom bar the root page keeps its title', (tester) async {
    _window(tester, _phone);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    expect(_visible('Home page'), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('in the sidebar layout the shell row draws the title of a pushed page and a root page, never the header', (tester) async {
    _window(tester, _sidebar);
    await tester.pumpWidget(_app(pushed: true));
    await tester.pumpAndSettle();
    expect(_inHeader('Ranking page'), isFalse);
    expect(_visible('Ranking page'), isTrue);
    await tester.pumpWidget(_app(secondary: true));
    await tester.pumpAndSettle();
    expect(_inHeader('Downloads page'), isFalse);
    await tester.pumpWidget(_app(secondary: true, pushed: true));
    await tester.pumpAndSettle();
    expect(_inHeader('Ranking page'), isFalse);
    expect(_visible('Ranking page'), isTrue);
    expect(tester.takeException(), isNull);
  });

  for (final actions in [false, true]) {
    testWidgets('a root page section tabs start on the content edge (actions: $actions)', (tester) async {
      _window(tester, _sidebar);
      await tester.pumpWidget(
        _app(
          page: _sectioned,
          actions: [if (actions) FrostToolbarItem.action(icon: testIcons.add, label: 'Sync', onPressed: () {})],
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.text('Illust')).dx, moreOrLessEquals(tester.getTopLeft(find.text('Rankings Home page')).dx, epsilon: .5));
      if (!actions) expect(tester.getTopLeft(find.byType(FrostTabBar)).dy, tester.getTopLeft(find.byType(FrostPinnedChrome)).dy);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('section tabs in a row of their own start on the content edge on a pushed page too', (tester) async {
    _window(tester, const Size(700, 717));
    await tester.pumpWidget(_app(page: _sectioned, pushed: true));
    await tester.pumpAndSettle();
    final header = tester.getRect(find.byType(FrostPageHeader).last);
    final tab = tester.getRect(find.text('Illust').last);
    // Too narrow for the tabs in the header row: they take a row below it.
    expect(tab.top, greaterThanOrEqualTo(header.bottom));
    expect(tab.left, moreOrLessEquals(tester.getTopLeft(find.text('Rankings Ranking page')).dx, epsilon: .5));
    expect(tester.takeException(), isNull);
  });

  for (final (name, page) in [('the account page', _account), ('the settings sections', _settings)]) {
    testWidgets('$name on a root page keep the margin under the header that a titled page has', (tester) async {
      _window(tester, _sidebar);
      await tester.pumpWidget(_app(page: page));
      await tester.pumpAndSettle();
      final header = tester.getRect(find.byType(FrostPageHeader));
      final root = tester.getTopLeft(find.byKey(const ValueKey('block Home page'))).dy - header.top;
      expect(root, greaterThan(_inset - 1));
      await tester.pumpWidget(_app(page: page, pushed: true));
      await tester.pumpAndSettle();
      final titled = tester.getTopLeft(find.byKey(const ValueKey('block Ranking page'))).dy - tester.getRect(find.byType(FrostPageHeader).last).bottom;
      expect(root, moreOrLessEquals(_inset + titled));
      expect(tester.takeException(), isNull);
    });
  }
}

/// Whether [text] is painted by the page header: present there and under no fully transparent layer.
bool _inHeader(String text) => _painted(find.descendant(of: find.byType(FrostPageHeader), matching: find.text(text)).evaluate());

/// Whether [text] is painted anywhere: the shell's top row or the page header.
bool _visible(String text) => _painted(find.text(text).evaluate());

bool _painted(Iterable<Element> found) => found.any((element) {
  var painted = true;
  element.visitAncestorElements((ancestor) {
    if (ancestor.widget case Opacity(opacity: 0)) painted = false;
    return painted;
  });
  return painted;
});
