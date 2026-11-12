import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';

import 'support.dart';

class _Page extends StatefulWidget {
  const _Page({this.choices = 1});

  /// How many choices the first section carries; the second carries none.
  final int choices;
  @override
  State<_Page> createState() => _PageState();
}

class _PageState extends State<_Page> with SingleTickerProviderStateMixin {
  late final tabs = FrostTabController(length: 2, vsync: this);
  var kind = 0, visibility = 0;

  @override
  void dispose() {
    tabs.dispose();
    super.dispose();
  }

  FrostToolbarItem _picker(String label, List<String> options, int value, ValueChanged<int> onChanged) => FrostToolbarItem.picker<int>(
    label: label,
    value: value,
    onChanged: onChanged,
    choices: [for (final (index, option) in options.indexed) FrostPickerOption(value: index, label: option)],
  );

  Widget? _controls() => tabs.index != 0
      ? null
      : FrostToolbar(
          trailing: [
            _picker('Kind', ['Works', 'Novels'], kind, (value) => setState(() => kind = value)),
            if (widget.choices > 1) _picker('Visibility', ['Public', 'Private'], visibility, (value) => setState(() => visibility = value)),
            if (widget.choices > 2)
              FrostToolbarItem.menu(
                label: 'Tag',
                valueLabel: 'All tags',
                entries: [FrostMenuAction('Sky', onSelected: () {})],
              ),
          ],
        );

  @override
  Widget build(BuildContext context) => FrostPinnedChrome(
    chrome: const FrostPageHeader(),
    body: NestedScrollView(
      headerSliverBuilder: (context, _) => [
        ListenableBuilder(
          listenable: tabs,
          builder: (context, _) => FrostSliverSectionsHeader(
            lead: const SizedBox(key: ValueKey('lead'), height: 240),
            tabs: FrostTabBar(
              controller: tabs,
              scrollable: true,
              tabs: const [
                FrostTab(label: 'Bookmarks'),
                FrostTab(label: 'Profile'),
              ],
            ),
            trailing: _controls(),
          ),
        ),
      ],
      body: FrostTabView(
        controller: tabs,
        children: [
          for (final section in ['a', 'b'])
            Builder(
              builder: (context) => CustomScrollView(
                key: PageStorageKey(section),
                primary: true,
                slivers: [
                  SliverOverlapInjector(handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context)),
                  SliverList.builder(itemCount: 100, itemBuilder: (_, i) => SizedBox(height: 50, child: Text('$section$i'))),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}

void _window(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> _scroll(WidgetTester tester, double by) async {
  await tester.dragFrom(const Offset(200, 600), Offset(0, -by));
  await tester.pumpAndSettle();
}

Rect _rect(WidgetTester tester, String text) => tester.getRect(find.text(text).hitTestable());

void main() {
  testWidgets('controls that fit sit at the end of the tabs row and stay reachable once the tabs stick', (tester) async {
    _window(tester, const Size(1147, 717));
    await tester.pumpWidget(frostTestApp(const _Page()));
    await tester.pumpAndSettle();
    final tab = _rect(tester, 'Bookmarks'), choice = _rect(tester, 'Works');
    expect(choice.center.dy, moreOrLessEquals(tab.center.dy, epsilon: 1));
    expect(choice.left, greaterThan(tab.right));

    await _scroll(tester, 600);
    final stuck = _rect(tester, 'Bookmarks');
    expect(stuck.top, lessThan(tab.top));
    expect(_rect(tester, 'Works').center.dy, moreOrLessEquals(stuck.center.dy, epsilon: 1));
    await tester.tap(find.text('Novels').hitTestable());
    await tester.pumpAndSettle();
    expect(tester.state<_PageState>(find.byType(_Page)).kind, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('at 390 wide three choices take a row below the tabs that sticks with them, overflowing into a menu', (tester) async {
    _window(tester, const Size(390, 844));
    await tester.pumpWidget(frostTestApp(const _Page(choices: 3)));
    await tester.pumpAndSettle();
    await _scroll(tester, 600);
    final tab = _rect(tester, 'Bookmarks');
    final toolbar = tester.getRect(find.descendant(of: find.byType(FrostSliverSectionsHeader), matching: find.byType(FrostToolbar)));
    expect(toolbar.top, greaterThanOrEqualTo(tab.bottom - .5));
    // Each choice is in the row or behind its More.
    final more = findFrostTooltip('L.more').hitTestable();
    final shown = [
      for (final label in ['Works', 'Public', 'All tags']) find.text(label).hitTestable().evaluate().isNotEmpty,
    ];
    expect(shown.every((visible) => visible) || more.evaluate().isNotEmpty, isTrue);
    if (more.evaluate().isNotEmpty) {
      await tester.tap(more);
      await tester.pumpAndSettle();
      for (final (index, label) in ['Kind', 'Visibility', 'Tag'].indexed) {
        if (!shown[index]) expect(find.textContaining(label), findsWidgets);
      }
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('switching sections shows that section\'s controls, and none for a section without any', (tester) async {
    _window(tester, const Size(1147, 717));
    await tester.pumpWidget(frostTestApp(const _Page(choices: 2)));
    await tester.pumpAndSettle();
    final tabsHeight = tester.getSize(find.byType(FrostTabBar)).height;
    final sectionToolbar = find.descendant(of: find.byType(FrostSliverSectionsHeader), matching: find.byType(FrostToolbar));
    expect(sectionToolbar, findsOneWidget);
    final tabBar = tester.state(find.byType(FrostTabBar));
    await tester.tap(find.text('Profile').hitTestable());
    await tester.pumpAndSettle();
    expect(find.text('Works'), findsNothing);
    expect(find.text('Public'), findsNothing);
    expect(sectionToolbar, findsNothing);
    expect(tester.getSize(find.byType(FrostTabBar)).height, tabsHeight);
    // The tabs are not rebuilt from scratch when the controls go.
    expect(identical(tester.state(find.byType(FrostTabBar)), tabBar), isTrue);
    await tester.tap(find.text('Bookmarks').hitTestable());
    await tester.pumpAndSettle();
    expect(find.text('Works').hitTestable(), findsOneWidget);
    expect(identical(tester.state(find.byType(FrostTabBar)), tabBar), isTrue);
    expect(tester.takeException(), isNull);
  });
}
