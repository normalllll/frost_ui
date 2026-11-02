import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/display/stat.dart' show FrostStatStrip;

import 'support.dart';

void main() {
  group('FrostProfileHeader', () {
    Future<void> pump(WidgetTester tester, double width, {bool actions = true}) => tester.pumpWidget(
      frostTestApp(
        Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: width,
            child: FrostProfileHeader(
              avatar: const FrostAvatar(initials: 'A', semanticLabel: 'avatar'),
              title: 'Name',
              subtitle: 'Detail',
              stats: const [
                FrostStat(value: '1', caption: 'One'),
                FrostStat(value: '2', caption: 'Two'),
              ],
              actions: actions ? [FrostButton(label: 'Follow', onPressed: () {})] : const [],
              moreAction: FrostButton.icon(icon: testIcons.image, label: 'More', onPressed: () {}),
            ),
          ),
        ),
      ),
    );

    testWidgets('wide: 72px avatar, stats under the name, actions at the end', (tester) async {
      tester.view.physicalSize = const Size(1000, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pump(tester, 900);
      final avatar = tester.getRect(find.byType(FrostAvatar));
      final title = tester.getRect(find.text('Name'));
      final stats = tester.getRect(find.byType(FrostStatStrip));
      expect(avatar.size, const Size(72, 72));
      expect(stats.left, title.left);
      expect(stats.top, greaterThan(title.bottom));
      expect(tester.getRect(find.byType(FrostButton).last).right, closeTo(900, 1));
    });

    testWidgets('narrow: everything centred, actions in one row, more at the corner without actions', (tester) async {
      await pump(tester, 400);
      expect(tester.getCenter(find.byType(FrostAvatar)).dx, closeTo(200, 1));
      expect(tester.getCenter(find.text('Name')).dx, closeTo(200, 1));
      expect(tester.getCenter(find.byType(FrostStatStrip)).dx, closeTo(200, 1));
      expect(tester.getCenter(find.text('Follow')).dy, closeTo(tester.getCenter(find.byType(FrostButton).last).dy, 1));
      await pump(tester, 400, actions: false);
      expect(tester.getRect(find.byType(FrostButton)).right, closeTo(400, 1));
      expect(tester.getRect(find.byType(FrostButton)).top, lessThan(tester.getRect(find.text('Name')).top));
    });
  });

  group('FrostFloatingActionLayer', () {
    testWidgets('collapses to its icon on scroll down, returns on scroll up, and clears the last item', (tester) async {
      tester.view.physicalSize = const Size(400, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        frostTestApp(
          FrostFloatingActionLayer(
            label: 'Post',
            icon: testIcons.image,
            onPressed: () {},
            child: ListView(
              controller: controller,
              children: [for (var i = 0; i < 30; i++) SizedBox(height: 80, child: Text('Item $i'))],
            ),
          ),
        ),
      );
      expect(find.text('Post'), findsOneWidget);
      controller.jumpTo(300);
      await tester.pumpAndSettle();
      expect(find.text('Post'), findsNothing);
      controller.jumpTo(controller.position.maxScrollExtent);
      await tester.pumpAndSettle();
      final button = tester.getRect(
        find
            .ancestor(
              of: find.descendant(of: find.byType(FrostFloatingActionLayer), matching: find.byType(FrostIcon)),
              matching: find.byType(PositionedDirectional),
            )
            .first,
      );
      final last = tester.getRect(find.text('Item 29'));
      expect(last.bottom, lessThanOrEqualTo(button.top), reason: 'the last item scrolls clear of the button');
      controller.jumpTo(controller.position.maxScrollExtent - 200);
      await tester.pumpAndSettle();
      expect(find.text('Post'), findsOneWidget);
    });
  });

  testWidgets('FrostRowLeadingExtent starts every row text at the same place', (tester) async {
    await tester.pumpWidget(
      frostTestApp(
        FrostRowLeadingExtent(
          extent: 44,
          child: Column(
            children: [
              FrostListRow(title: 'Avatar row', leading: FrostLeading.custom(const SizedBox.square(dimension: 44)), onPressed: () {}),
              FrostListRow(title: 'Icon row', leading: FrostGlyph.icon(testIcons.image), onPressed: () {}),
            ],
          ),
        ),
      ),
    );
    expect(tester.getRect(find.text('Icon row')).left, tester.getRect(find.text('Avatar row')).left);
  });

  testWidgets('media grid reserves a second title line and the metadata row only when needed', (tester) async {
    late BuildContext context;
    await tester.pumpWidget(frostTestApp(Builder(builder: (c) => (context = c) is Element ? const SizedBox() : const SizedBox())));
    double extent({int titleLines = 2, bool metadata = true}) =>
        (FrostMediaCard.gridDelegate(context, 800, titleLines: titleLines, metadata: metadata) as SliverGridDelegateWithFixedCrossAxisCount).mainAxisExtent!;
    expect(extent(titleLines: 1), lessThan(extent()));
    expect(extent(titleLines: 1, metadata: false), lessThan(extent(titleLines: 1)));
    expect(FrostMediaCard.titleLinesFor(context, 800, ['Short', 'Also short']), 1);
    expect(FrostMediaCard.titleLinesFor(context, 400, ['A title that is certainly far too long to fit on a single line of a narrow media card ' * 3]), 2);
  });
}
