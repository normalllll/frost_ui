import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/social.dart';
import 'package:frost_ui/src/social/thread.dart' show FrostThreadRender;

import 'support.dart';

FrostThreadItem _item(String name, {String? time, bool actions = true}) => FrostThreadItem(
  avatar: FrostAvatar(initials: name, semanticLabel: name),
  author: name,
  badge: 'LV5',
  body: Text('Body $name'),
  time: time,
  like: actions ? FrostThreadAction(icon: testIcons.image, label: 'Like', count: '12', onPressed: () {}) : null,
  reply: actions ? FrostThreadAction(icon: testIcons.image, label: 'Reply', onPressed: () {}) : null,
);

Future<void> _pump(WidgetTester tester, Widget child, {TargetPlatform platform = TargetPlatform.windows}) async {
  tester.view.physicalSize = const Size(600, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    frostTestApp(
      Align(
        alignment: Alignment.topLeft,
        child: SizedBox(width: 400, child: child),
      ),
      platform: platform,
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  group('FrostThread block style', () {
    testWidgets('time, like and reply share one small tertiary footer row, with no full-size buttons', (tester) async {
      await _pump(tester, FrostThread(item: _item('A', time: '2d')));
      expect(find.byType(FrostButton), findsNothing);
      final tokens = FrostThemeTokens.of(tester.element(find.byType(FrostThread)));
      final time = tester.getRect(find.text('2d'));
      final like = tester.getRect(find.text('12'));
      expect((time.center.dy - like.center.dy).abs(), lessThan(2));
      final style = tester.renderObject<RenderParagraph>(find.text('2d')).text.style!;
      expect(style.color, tokens.textTertiary);
      expect(style.fontSize, lessThan(13));
      final icons = tester.widgetList<FrostIcon>(find.descendant(of: find.byType(FrostThread), matching: find.byType(FrostIcon)));
      expect(icons.map((icon) => icon.size), everyElement(16));
      expect(tester.getRect(find.text('Body A')).bottom, lessThan(time.top + 2));
    });

    testWidgets('replies sit in a module block on the parent text column with smaller avatars', (tester) async {
      await _pump(
        tester,
        FrostThread(
          item: _item('P'),
          replies: [FrostThread(item: _item('R'))],
          collapsedReplyCount: 3,
          onShowReplies: () {},
        ),
      );
      final text = tester.getRect(find.text('Body P'));
      final block = find.descendant(of: find.byType(FrostThread).first, matching: find.byType(FrostSurface));
      expect(block, findsOneWidget);
      expect(tester.getRect(block).left, closeTo(text.left, .5), reason: 'the block starts on the parent text column');
      expect(tester.getSize(find.byType(FrostAvatar).first).width, 32);
      expect(tester.getSize(find.byType(FrostAvatar).last).width, 24);
      expect(find.text('L.showReplies(3)'), findsOneWidget);
      expect(tester.getRect(find.text('L.showReplies(3)')).top, greaterThan(tester.getRect(find.text('Body R')).bottom));
      expect(find.byWidgetPredicate((w) => w.runtimeType.toString() == '_ThreadLayout'), findsNothing, reason: 'no connector lines by default');
    });

    testWidgets('the lines style remains available for deeper threads', (tester) async {
      await _pump(
        tester,
        FrostThread(
          style: FrostThreadStyle.lines,
          item: _item('P'),
          replies: [FrostThread(style: FrostThreadStyle.lines, item: _item('R'))],
        ),
      );
      expect(find.byWidgetPredicate((w) => w.runtimeType.toString() == '_ThreadLayout'), findsWidgets);
      expect(find.byType(FrostSurface), findsNothing);
    });

    testWidgets('top-level threads draw a rule from the text column, except at the end of a column', (tester) async {
      await _pump(
        tester,
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FrostThread(item: _item('One', actions: false)),
            FrostThread(item: _item('Two', actions: false)),
          ],
        ),
      );
      final tokens = FrostThemeTokens.of(tester.element(find.byType(FrostThread).first));
      final rules = find.byWidgetPredicate((w) => w is ColoredBox && w.color == tokens.separator);
      expect(rules, findsOneWidget, reason: 'one rule between the two comments, none after the last');
      expect(tester.getRect(rules).left, closeTo(tester.getRect(find.text('Body One')).left, .5));
      final one = tester.getRect(find.byType(FrostThread).first);
      final aboveName = tester.getRect(find.text('One')).top - one.top;
      final belowBody = tester.getRect(rules).top - tester.getRect(find.text('Body One')).bottom;
      expect(aboveName, closeTo(12, 1));
      expect(belowBody, closeTo(12, 1));
    });
  });
  testWidgets('siblings share one stem ending at actual final avatar', (tester) async {
    await tester.pumpWidget(
      frostTestApp(
        Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 400,
            child: FrostThread(
              style: FrostThreadStyle.lines,
              item: const FrostThreadItem(
                avatar: FrostAvatar(semanticLabel: 'Root'),
                author: 'Root',
                body: Text('Root'),
              ),
              replies: [
                const FrostThread(
                  style: FrostThreadStyle.lines,
                  item: FrostThreadItem(
                    avatar: FrostAvatar(semanticLabel: 'A'),
                    author: 'A',
                    body: Text('Long\nreply\nbody'),
                  ),
                ),
                const FrostThread(
                  style: FrostThreadStyle.lines,
                  item: FrostThreadItem(
                    avatar: FrostAvatar(key: ValueKey('last'), semanticLabel: 'B'),
                    author: 'B',
                    body: Text('Last'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    final root = tester.allRenderObjects.whereType<FrostThreadRender>().firstWhere((render) => render.replyCount == 2);
    expect(root.connections, hasLength(3));
    final end = root.connections.last.getBounds().bottom + root.localToGlobal(Offset.zero).dy;
    expect(end, tester.getCenter(find.byKey(const ValueKey('last'))).dy);
  });
  for (final style in FrostThreadStyle.values) {
    testWidgets('a thread with an unknown reply count words its row without a number ($style)', (tester) async {
      final semantics = tester.ensureSemantics();
      var shown = 0;
      await _pump(tester, FrostThread(item: _item('Ann'), collapsedRepliesLabel: 'Show more replies', onShowReplies: () => shown++, style: style));
      expect(find.textContaining('L.showReplies'), findsNothing);
      expect(find.bySemanticsLabel('Show more replies'), findsOneWidget);
      await tester.tap(find.text('Show more replies'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(shown, 1);
      semantics.dispose();
      expect(tester.takeException(), isNull);
    });
  }
}
