import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/social.dart';

import 'baseline.dart';

void _noop() {}

const _filledIcon = FrostIconData.glyph(IconData(0xe011));
const _like = FrostThreadAction(icon: baselineIcon, label: 'Like', count: '12', onPressed: _noop);
const _reply = FrostThreadAction(icon: baselineIcon, label: 'Reply', onPressed: _noop);

FrostThreadItem _item(String author, String text, {bool liked = false}) => FrostThreadItem(
  avatar: FrostAvatar(initials: author.substring(0, 2).toUpperCase(), semanticLabel: author),
  author: author,
  body: FrostText(text),
  time: '3 hours ago',
  like: liked ? const FrostThreadAction(icon: _filledIcon, label: 'Like', count: '13', selected: true, onPressed: _noop) : _like,
  reply: _reply,
);

FrostThread _reply1() => FrostThread(item: _item('Ben', 'A reply to the comment, long enough to wrap onto a second line in a narrow column.'));
FrostThread _reply2() => FrostThread(item: _item('Cho', 'Another reply.', liked: true));
FrostThread _nested() => FrostThread(
  item: _item('Ben', 'A reply with its own replies.'),
  replies: [
    FrostThread(
      item: _item('Dan', 'A reply to the reply.'),
      replies: [FrostThread(item: _item('Eli', 'And a third level.'))],
    ),
  ],
);

FrostThread _root({List<FrostThread> replies = const [], int collapsed = 0, VoidCallback? onShowReplies, FrostThreadStyle style = FrostThreadStyle.block}) =>
    FrostThread(
      item: _item('Mika', 'The top comment of the conversation.'),
      replies: replies,
      collapsedReplyCount: collapsed,
      onShowReplies: onShowReplies,
      style: style,
    );

void main() {
  baselineGroup('FrostThread', [
    BaselineCase('FrostThread/required', (_) => FrostThread(item: _item('Mika', 'The top comment of the conversation.')), envs: BaselineEnv.all),
    BaselineCase(
      'FrostThread/replies',
      (_) => _root(replies: [_reply1(), _reply2()]),
      envs: [BaselineEnv.standard, BaselineEnv.light, BaselineEnv.touch, BaselineEnv.narrow],
    ),
    BaselineCase('FrostThread/replies=nested', (_) => _root(replies: [_nested()]), envs: [BaselineEnv.standard]),
    BaselineCase('FrostThread/collapsedReplyCount', (_) => _root(collapsed: 5)),
    BaselineCase(
      'FrostThread/collapsedReplyCount+onShowReplies',
      (_) => _root(collapsed: 5, onShowReplies: _noop),
      envs: [BaselineEnv.standard, BaselineEnv.light, BaselineEnv.touch],
    ),
    BaselineCase(
      'FrostThread/collapsedReplyCount+onShowReplies#hover',
      (_) => _root(collapsed: 5, onShowReplies: _noop),
      act: (tester, subject) => baselineHover(tester, find.descendant(of: subject, matching: find.text('L.showReplies(5)'))),
    ),
    BaselineCase('FrostThread/replies+collapsedReplyCount+onShowReplies', (_) => _root(replies: [_reply1()], collapsed: 3, onShowReplies: _noop)),
    BaselineCase(
      'FrostThread/style=block',
      (_) => _root(replies: [_reply1(), _reply2()], style: FrostThreadStyle.block),
      envs: BaselineEnv.themes,
    ),
    BaselineCase(
      'FrostThread/style=lines',
      (_) => _root(replies: [_reply1(), _reply2()], style: FrostThreadStyle.lines),
      envs: [BaselineEnv.standard, BaselineEnv.light, BaselineEnv.touch, BaselineEnv.narrow],
    ),
    BaselineCase(
      'FrostThread/style=lines+nested',
      (_) => _root(replies: [_nested()], style: FrostThreadStyle.lines),
      envs: [BaselineEnv.standard, BaselineEnv.narrow],
    ),
    BaselineCase(
      'FrostThread/style=lines+collapsedReplyCount+onShowReplies',
      (_) => _root(replies: [_reply1()], collapsed: 3, onShowReplies: _noop, style: FrostThreadStyle.lines),
    ),
  ]);
}
