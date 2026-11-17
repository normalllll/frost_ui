import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:material_ui/material_ui.dart';

import 'support.dart';

class _Page extends StatefulWidget {
  const _Page();
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
  Widget build(BuildContext context) => FrostPinnedChrome(
    chrome: const FrostPageHeader(title: FrostText('Name')),
    body: NestedScrollView(
      headerSliverBuilder: (context, _) => [
        FrostSliverSectionsHeader(
          maxWidth: 680,
          lead: const SizedBox(height: 300),
          tabs: FrostTabBar(
            controller: _tabs,
            scrollable: true,
            tabs: const [
              FrostTab(label: 'Posts'),
              FrostTab(label: 'Likes'),
            ],
          ),
          trailing: FrostButton(label: 'Filter', onPressed: () {}),
        ),
      ],
      body: FrostTabView(
        controller: _tabs,
        children: [
          for (final section in ['a', 'b'])
            Builder(
              builder: (context) => CustomScrollView(
                key: PageStorageKey(section),
                primary: true,
                slivers: [
                  SliverOverlapInjector(handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context)),
                  FrostSliverContentColumn(
                    maxWidth: 680,
                    sliver: SliverToBoxAdapter(child: SizedBox(key: ValueKey('body-$section'), height: 5000)),
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
  testWidgets('lead, tabs and trailing sit on the edges of a content column below while the stuck glass spans the page', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(frostTestApp(const _Page()));
    await tester.pumpAndSettle();

    final column = tester.getRect(find.byKey(const ValueKey('body-a')));
    expect(column.width, lessThan(680));
    expect(tester.getTopLeft(find.byType(FrostTabBar)).dx, column.left);
    expect(tester.getTopRight(find.byType(FrostButton)).dx, column.right);

    tester.state<NestedScrollViewState>(find.byType(NestedScrollView)).outerController.jumpTo(600);
    await tester.pump();
    await tester.pump();
    final glass = tester.getRect(find.byType(FrostPinnedChromeGlass).first);
    expect(glass.left, 0);
    expect(glass.width, 1280);
    expect(tester.getRect(find.byType(FrostPageHeader)).width, 1280);
    expect(tester.takeException(), isNull);
  });
}
