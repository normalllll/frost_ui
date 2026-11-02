import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/social.dart';

void main() {
  test('thread public API needs only widgets and frost_ui', () {
    const item = FrostThreadItem(
      avatar: SizedBox(),
      author: 'Author',
      meta: 'Meta',
      body: FrostRichText(text: 'Body'),
      actions: SizedBox(),
    );
    final thread = FrostThread(item: item, replies: const [], collapsedReplyCount: 2, onShowReplies: () {});
    expect(thread.item, item);
  });
}
