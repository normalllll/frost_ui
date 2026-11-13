import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/social.dart';
import 'package:frost_ui/src/social/thread.dart' show FrostThreadRender;
import 'package:material_ui/material_ui.dart';

import 'support.dart';

FrostThread thread(int depth, {Key? key, String? author}) => FrostThread(
  style: FrostThreadStyle.lines,
  key: key,
  item: FrostThreadItem(
    avatar: SizedBox(
      key: ValueKey('avatar-$depth'),
      child: const FrostAvatar(semanticLabel: 'avatar'),
    ),
    author: author ?? 'Author $depth',
    meta: 'now',
    body: Text('Body $depth'),
  ),
  replies: depth < 5 ? [thread(depth + 1)] : [],
);
Widget frame(Widget child, {TextDirection direction = TextDirection.ltr}) => frostTestApp(
  Directionality(
    textDirection: direction,
    child: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(width: 400, child: child),
    ),
  ),
);
void main() {
  for (final direction in TextDirection.values) {
    testWidgets('thread real endpoints, 8 bend and depth cap $direction on first frame', (tester) async {
      await tester.pumpWidget(frame(thread(0), direction: direction));
      final parent = tester.getRect(find.byKey(const ValueKey('avatar-0')));
      final child = tester.getRect(find.byKey(const ValueKey('avatar-1')));
      expect(parent.size, const Size(32, 32));
      expect((child.center.dx - parent.center.dx).abs(), 40);
      final third = tester.getRect(find.byKey(const ValueKey('avatar-3')));
      final fourth = tester.getRect(find.byKey(const ValueKey('avatar-4')));
      expect(third.center.dx, fourth.center.dx);
      final root = tester.allRenderObjects.whereType<FrostThreadRender>().first;
      final paths = root.connections;
      expect(paths, hasLength(2));
      final branch = paths[1].getBounds();
      final rootGlobal = root.localToGlobal(Offset.zero);
      expect(branch.bottom + rootGlobal.dy, child.center.dy);
      expect(paths[0].getBounds().top + rootGlobal.dy, parent.bottom + 4);
      expect(branch.height, 8);
      if (direction == TextDirection.ltr) {
        expect(branch.right + rootGlobal.dx, child.left - 4);
      } else {
        expect(branch.left + rootGlobal.dx, child.right + 4);
      }
      final capped = tester.allRenderObjects.whereType<FrostThreadRender>().firstWhere((render) => render.indent == 0 && render.replyCount > 0);
      expect(capped.connections, hasLength(1));
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('new reply Presence expands its gap and line with real height', (tester) async {
    var replies = <FrostThread>[];
    StateSetter? update;
    await tester.pumpWidget(
      frame(
        StatefulBuilder(
          builder: (_, setState) {
            update = setState;
            return FrostThread(
              style: FrostThreadStyle.lines,
              item: const FrostThreadItem(
                avatar: FrostAvatar(semanticLabel: 'root'),
                author: 'Root',
                body: Text('Root body'),
              ),
              replies: replies,
              collapsedReplyCount: 2,
              onShowReplies: () {},
            );
          },
        ),
      ),
    );
    expect(find.text('L.showReplies(2)'), findsOneWidget);
    final replyInk = tester
        .renderObject<RenderParagraph>(find.descendant(of: find.text('L.showReplies(2)'), matching: find.byType(RichText)))
        .text
        .style!
        .color;
    expect(replyInk, FrostThemeTokens.of(tester.element(find.byType(FrostThread).first)).accentInk);
    final original = tester.getSize(find.byType(FrostThread).first).height;
    update!(
      () => replies = [
        const FrostThread(
          style: FrostThreadStyle.lines,
          key: ValueKey('new'),
          item: FrostThreadItem(
            avatar: FrostAvatar(semanticLabel: 'child'),
            author: 'New',
            body: Text('Reply'),
          ),
        ),
      ],
    );
    await tester.pump();
    expect(tester.getSize(find.byType(FrostThread).first).height, original);
    await tester.pump(const Duration(milliseconds: 80));
    final middle = tester.getSize(find.byType(FrostThread).first).height;
    expect(middle, greaterThan(original));
    final root = tester.allRenderObjects.whereType<FrostThreadRender>().first;
    final lineEnd = root.connections.last.getBounds().bottom;
    expect(lineEnd, lessThanOrEqualTo(middle));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(FrostThread).first).height, greaterThan(middle));
  });
  testWidgets('thread parent click does not consume action and context menu', (tester) async {
    var parent = 0, action = 0;
    await tester.pumpWidget(
      frame(
        FrostThread(
          style: FrostThreadStyle.lines,
          item: FrostThreadItem(
            avatar: const FrostAvatar(semanticLabel: 'A'),
            author: 'A',
            body: const Text('Body'),
            onPressed: () => parent++,
            contextMenu: [FrostMenuAction('Menu', onSelected: () {})],
            actions: FrostButton(label: 'Action', onPressed: () => action++),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Action'));
    await tester.pump();
    expect(action, 1);
    expect(parent, 0);
    await tester.tap(find.text('Body'));
    await tester.pump();
    expect(parent, 1);
  });
}
