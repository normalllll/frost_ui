// IntrinsicHeight and IntrinsicWidth must agree with the real layout at the
// widths a shrink-wrapped parent can actually give, with real content.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/media.dart';

import 'support.dart';

const _subject = ValueKey('subject');

Future<Size> _lay(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    frostTestApp(
      Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: KeyedSubtree(key: _subject, child: child),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
  expect(tester.takeException(), isNull);
  return (tester.element(find.byKey(_subject)).findRenderObject()! as RenderBox).size;
}

/// At each width, IntrinsicHeight gives what the content really takes, and
/// IntrinsicWidth gives room for the content at its full, unfolded height.
void _agrees(String name, Widget Function() build, {List<double> widths = const [1200, 500, 300], bool checkWidth = true}) {
  testWidgets('$name reports the size it takes', (tester) async {
    tester.view.physicalSize = const Size(2800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    for (final width in widths) {
      final real = await _lay(tester, SizedBox(width: width, child: build()));
      await tester.pumpWidget(const SizedBox());
      final shrunk = await _lay(
        tester,
        SizedBox(
          width: width,
          child: IntrinsicHeight(child: build()),
        ),
      );
      await tester.pumpWidget(const SizedBox());
      expect(shrunk.height, closeTo(real.height, 1), reason: 'IntrinsicHeight at $width');
    }
    if (!checkWidth) return;
    final wide = await _lay(tester, SizedBox(width: 2600, child: build()));
    await tester.pumpWidget(const SizedBox());
    final fitted = await _lay(tester, IntrinsicWidth(child: build()));
    await tester.pumpWidget(const SizedBox());
    expect(fitted.width, lessThanOrEqualTo(2800));
    expect(fitted.height, closeTo(wide.height, 1), reason: 'IntrinsicWidth leaves the content folded or wrapped');
  });
}

void main() {
  final actions = [
    for (final label in ['Delete everything', 'Move to folder', 'Archive items', 'Share selection'])
      FrostSelectionAction(label: label, icon: testIcons.delete, onPressed: () {}),
  ];
  _agrees('FrostSelectionBar', () => FrostSelectionBar<int>(selection: FrostSelection<int>()..enter(), allItems: const [1, 2, 3], actions: actions));

  _agrees(
    'FrostProfileHeader',
    () => FrostProfileHeader(
      avatar: const FrostAvatar(initials: 'AB', semanticLabel: 'a'),
      title: 'Name',
      subtitle: 'A rather long subtitle that is much wider than the title itself and wraps',
      stats: const [
        FrostStat(value: '123456', caption: 'Followers'),
        FrostStat(value: '123456', caption: 'Following'),
        FrostStat(value: '123456', caption: 'Illustrations'),
      ],
      actions: [
        for (final label in ['Follow this user', 'Send a message', 'Add to a list']) FrostButton(label: label, onPressed: () {}),
      ],
    ),
    widths: const [900, 500, 320],
  );

  _agrees(
    'FrostProfileHeader with only a more action',
    () => FrostProfileHeader(
      avatar: const FrostAvatar(initials: 'AB', semanticLabel: 'a'),
      title: 'A name',
      moreAction: FrostButton.icon(label: 'More', icon: testIcons.more, onPressed: () {}),
    ),
    widths: const [900, 320],
    // Its natural width is under the wide arrangement's minimum, so it stacks there.
    checkWidth: false,
  );

  _agrees(
    'FrostKeyValueList',
    () => FrostKeyValueList(
      entries: [
        const FrostKeyValue.copyable(label: 'Checksum', value: 'abcdef0123456789 abcdef0123456789 abcdef0123456789', monospace: true),
        FrostKeyValue.link(label: 'Source', value: 'https://example.com/a/rather/long/link/that/needs/room', onPressed: () {}),
        const FrostKeyValue.path(label: 'Path', value: 'C:/some/rather/long/path/that/wraps/in/the/value/column/file.txt'),
        const FrostKeyValue(label: 'A label that is itself rather long', value: 'A value that also goes on for quite a while before ending'),
      ],
      dividers: true,
    ),
    widths: const [800, 300],
  );

  _agrees(
    'FrostInlinePageHeading',
    () => FrostInlinePageHeading(
      title: 'Heading',
      actions: [FrostButton(label: 'Wide action button', onPressed: () {})],
    ),
    widths: const [500],
  );

  _agrees(
    'FrostContentColumn',
    () => const FrostContentColumn(child: Text('Words that wrap once the column is narrow enough to need it, as this one will be')),
    widths: const [1200, 300],
  );

  _agrees(
    'FrostToolbar',
    () => FrostToolbar(
      title: const Text('A rather long toolbar title here'),
      trailing: [
        FrostToolbarItem.action(icon: testIcons.add, label: 'Add item', onPressed: () {}),
        FrostToolbarItem.action(icon: testIcons.edit, label: 'Edit item', onPressed: () {}),
      ],
    ),
    widths: const [600, 200],
  );

  testWidgets('FrostToolbar in IntrinsicWidth keeps its title and labels whole', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await _lay(
      tester,
      IntrinsicWidth(
        child: FrostToolbar(
          title: const Text('A rather long toolbar title here'),
          trailing: [FrostToolbarItem.action(icon: testIcons.add, label: 'Add item', onPressed: () {})],
        ),
      ),
    );
    final title = tester.renderObject<RenderParagraph>(find.text('A rather long toolbar title here'));
    expect(title.didExceedMaxLines, isFalse);
  });

  _agrees(
    'FrostPageHeader',
    () => FrostPageHeader(
      title: const Text('Page title'),
      actions: [FrostToolbarItem.action(icon: testIcons.add, label: 'Add item', onPressed: () {})],
    ),
    widths: const [800, 400],
  );

  _agrees(
    'FrostInlineBanner',
    () => FrostInlineBanner(tone: FrostBannerTone.info, message: List.filled(20, 'word').join(' '), actionLabel: 'Retry', onAction: () {}),
    checkWidth: false,
  );

  _agrees(
    'FrostExpandableText expanded',
    () => FrostExpandableText(text: List.filled(30, 'lorem ipsum').join(' '), maxLines: 2, expanded: true, onExpandedChanged: (_) {}),
    widths: const [600, 300],
    checkWidth: false,
  );

  _agrees(
    'FrostExpandableText collapsed',
    () => FrostExpandableText(text: List.filled(30, 'lorem ipsum').join(' '), maxLines: 2),
    widths: const [600, 300],
    checkWidth: false,
  );

  _agrees(
    'FrostMediaRow',
    () => FrostMediaRow(
      title: 'A rather long media title that runs across two lines at narrow widths',
      metadata: const ['Channel', '12 views'],
      media: const ColoredBox(color: Colors.red),
    ),
    widths: const [600, 300],
    checkWidth: false,
  );

  _agrees(
    'FrostGrid',
    () => const FrostGrid(minItemWidth: 120, children: [Text('One long tile of text that wraps'), Text('Two'), Text('Three'), Text('Four')]),
    widths: const [900, 300],
    checkWidth: false,
  );
}
