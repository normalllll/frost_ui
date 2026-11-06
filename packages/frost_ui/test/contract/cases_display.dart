// Non-interactive display and layout components. Constructors that differ get
// their own case; slivers are placed in a scroll view.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/media.dart';
import 'package:frost_ui/social.dart';

import '../support.dart' show testIcons;
import 'harness.dart';

const _sliver = {'intrinsic': 'a sliver is placed in a viewport, which has no intrinsic size'};
const _scroll = {'intrinsic': 'a lazy scroll view cannot answer intrinsic sizes; the component is a viewport itself'};

const _box = SizedBox(width: 120, height: 40, child: ColoredBox(color: Colors.red));

/// A slivers-only component, hosted in a scroll view of bounded height.
Widget _inScroll(Widget sliver) => SizedBox(height: 400, width: 400, child: CustomScrollView(slivers: [sliver]));

Widget _gridItem(BuildContext context, int value, int index) => SizedBox(child: Text('Item $value'));

final _icon = testIcons.empty;

final displayCases = _exempt(_cases);

final _cases = <DisplayCase>[
  // display/
  DisplayCase('FrostAvatar.new', FrostAvatar, (_) => const FrostAvatar(initials: 'AB', semanticLabel: 'Avatar')),
  DisplayCase('FrostAvatar.person', FrostAvatar, (_) => const FrostAvatar.person(name: 'Alice', semanticLabel: 'Alice')),
  DisplayCase('FrostAvatar.skeleton', FrostAvatar, (_) => FrostAvatar.skeleton(size: FrostAvatarSize.regular)),
  DisplayCase('FrostBadge.new', FrostBadge, (_) => const FrostBadge(label: longLabel)),
  DisplayCase('FrostCodeBlock.new', FrostCodeBlock, (_) => const FrostCodeBlock(text: 'final a = 1;')),
  DisplayCase('FrostCountBadge.new', FrostCountBadge, (_) => const FrostCountBadge(count: 5)),
  DisplayCase('FrostDataDot.new', FrostDataDot, (_) => const FrostDataDot(0)),
  DisplayCase('FrostExpandableText.new', FrostExpandableText, (_) => const FrostExpandableText(text: 'A long text that goes on and on and on and on and on.')),
  DisplayCase(
    'FrostFilterBar.new',
    FrostFilterBar,
    (_) => const FrostFilterBar(
      chips: [
        FrostFilterChip(label: longLabel),
        FrostFilterChip(label: longLabel),
      ],
    ),
  ),
  DisplayCase(
    'FrostKeyValueList.new',
    FrostKeyValueList,
    (_) => const FrostKeyValueList(
      entries: [
        FrostKeyValue(label: longLabel, value: 'Value'),
        FrostKeyValue(label: longLabel, value: 'More'),
      ],
    ),
  ),
  DisplayCase('FrostLabeledContent.new', FrostLabeledContent, (_) => const FrostLabeledContent(label: longLabel, value: 'Value')),
  DisplayCase('FrostMetaLine.new', FrostMetaLine, (_) => const FrostMetaLine(items: [longLabel, longLabel, longLabel])),
  DisplayCase('FrostMeter.new', FrostMeter, (_) => const FrostMeter(value: 0.4, semanticLabel: 'Meter')),
  DisplayCase('FrostRichText.new', FrostRichText, (_) => const FrostRichText(text: 'Hello @someone #tag https://example.com')),
  DisplayCase('FrostStat.new', FrostStat, (_) => const FrostStat(value: '123456', caption: longLabel)),
  DisplayCase('FrostStat.skeleton', FrostStat, (_) => FrostStat.skeleton(value: '123456', unit: null, caption: longLabel)),
  DisplayCase('FrostStatusDot.new', FrostStatusDot, (_) => const FrostStatusDot(tone: FrostStatusTone.positive, label: longLabel)),

  // feedback/
  DisplayCase('FrostActivityIndicator.new', FrostActivityIndicator, (_) => const FrostActivityIndicator(semanticLabel: 'Loading')),
  DisplayCase('FrostCompactMessage.new', FrostCompactMessage, (_) => FrostCompactMessage(icon: _icon, message: longLabel, actionLabel: longLabel)),
  DisplayCase('FrostCompactMessage.error', FrostCompactMessage, (_) => const FrostCompactMessage.error(error: 'broken')),
  DisplayCase('FrostEmptyState.new', FrostEmptyState, (_) => FrostEmptyState(icon: _icon, title: longLabel, message: longLabel)),
  DisplayCase('FrostEmptyState.search', FrostEmptyState, (_) => FrostEmptyState.search(query: 'abc', onClear: () {})),
  DisplayCase('FrostErrorContent.new', FrostErrorContent, (_) => const FrostErrorContent(message: longLabel, details: 'Details', onRetry: null)),
  DisplayCase('FrostErrorContent.fromError', FrostErrorContent, (_) => const FrostErrorContent.fromError(error: 'broken', onRetry: null)),
  DisplayCase('FrostErrorDetails.new', FrostErrorDetails, (_) => const FrostErrorDetails(details: 'Details')),
  DisplayCase('FrostErrorDetails.quiet', FrostErrorDetails, (_) => const FrostErrorDetails.quiet(details: 'Details')),
  DisplayCase('FrostInlineBanner.new', FrostInlineBanner, (_) => const FrostInlineBanner(tone: FrostBannerTone.info, message: longLabel)),
  DisplayCase('FrostLoadingGate.new', FrostLoadingGate, (_) => FrostLoadingGate(loading: false, builder: (context, loading) => _box)),
  DisplayCase('FrostProgressBar.new', FrostProgressBar, (_) => const FrostProgressBar(value: 0.4, semanticLabel: 'Progress')),
  DisplayCase('FrostProgressRing.new', FrostProgressRing, (_) => const FrostProgressRing(value: 0.4, semanticLabel: 'Progress')),
  DisplayCase('FrostRefreshDots.new', FrostRefreshDots, (_) => const FrostRefreshDots()),
  DisplayCase(
    'FrostLoadingScrollView.new',
    FrostLoadingScrollView,
    (_) => hosted(height: 300, child: FrostLoadingScrollView(slivers: [])),
    skip: _scroll,
  ),
  DisplayCase(
    'FrostNestedRefreshView.new',
    FrostNestedRefreshView,
    (_) => hosted(height: 300, width: 400, child: FrostNestedRefreshView(builder: (context, refresh) => _scrollable())),
    skip: _scroll,
  ),
  DisplayCase(
    'FrostRefreshView.new',
    FrostRefreshView,
    (_) => hosted(
      height: 300,
      width: 400,
      child: FrostRefreshView(builder: (context, physics, locators) => _scrollable(physics: physics)),
    ),
    skip: _scroll,
  ),

  // layout/
  DisplayCase(
    'FrostAutoScaffold.new',
    FrostAutoScaffold,
    (_) => hosted(height: 300, width: 400, child: FrostAutoScaffold(builder: (context, layout, orientation, horizontal) => _box)),
  ),
  DisplayCase('FrostColumnPlacement.new', FrostColumnPlacement, (_) => const FrostColumnPlacement(alignment: FrostColumnAlignment.center, child: _box)),
  DisplayCase('FrostContentColumn.new', FrostContentColumn, (_) => const FrostContentColumn(child: _box)),
  DisplayCase(
    'FrostContentViewport.new',
    FrostContentViewport,
    (_) => const FrostContentViewport(child: _box),
    skip: const {'intrinsic': 'a page viewport: it passes its given size down as the measure of the page and has none of its own'},
  ),
  DisplayCase(
    'FrostSliverContentColumn.new',
    FrostSliverContentColumn,
    (_) => _inScroll(const FrostSliverContentColumn(sliver: SliverToBoxAdapter(child: _box))),
    skip: _sliver,
  ),
  DisplayCase('FrostFit.new', FrostFit, (_) => FrostFit(candidates: [(context) => _box, (context) => const SizedBox(width: 60, height: 20)])),
  DisplayCase('FrostGrid.new', FrostGrid, (_) => const FrostGrid(minItemWidth: 80, children: [_box, _box, _box])),
  DisplayCase(
    'FrostSliverGrid.new',
    FrostSliverGrid,
    (_) => _inScroll(FrostSliverGrid(minItemWidth: 80, aspectRatio: 1, itemCount: 4, itemBuilder: _listRow)),
    skip: _sliver,
  ),
  DisplayCase('FrostKeepAlive.new', FrostKeepAlive, (_) => const FrostKeepAlive(child: _box)),
  DisplayCase('FrostChromeSpacer.new', FrostChromeSpacer, (_) => _inScroll(const FrostChromeSpacer()), hasContent: false, skip: _sliver),
  DisplayCase(
    'FrostPinnedChrome.new',
    FrostPinnedChrome,
    (_) => hosted(
      height: 200,
      width: 300,
      child: FrostPinnedChrome(chrome: Text('Chrome'), body: _box),
    ),
    skip: const {'intrinsic': 'a page layout: chrome pinned over a scrolling body that fills what it is given'},
  ),
  DisplayCase('FrostPinnedChromeGlass.new', FrostPinnedChromeGlass, (_) => const FrostPinnedChromeGlass(opacity: 1, child: _box)),
  DisplayCase(
    'FrostSettingsSections.new',
    FrostSettingsSections,
    (_) => hosted(
      height: 300,
      width: 400,
      child: FrostSettingsSections(labels: const ['One', 'Two'], selectedIndex: 0, onSelected: (_) {}, sectionBuilder: (context, index) => _box),
    ),
    skip: const {'intrinsic': 'a page layout of section list and panes that fills what it is given'},
  ),
  DisplayCase('FrostShelf.new', FrostShelf, (_) => FrostShelf(title: longLabel, itemCount: 3, itemExtent: 80, height: 60, itemBuilder: _listRow)),
  DisplayCase(
    'FrostSliverExpand.new',
    FrostSliverExpand,
    (_) => _inScroll(const FrostSliverExpand(expanded: true, sliver: SliverToBoxAdapter(child: _box))),
    skip: _sliver,
  ),
  DisplayCase(
    'FrostWaterfallGrid.new',
    FrostWaterfallGrid<int>,
    (_) => hosted(
      height: 300,
      width: 400,
      child: FrostWaterfallGrid<int>(items: const [1, 2, 3], itemBuilder: _gridItem),
    ),
    skip: _scroll,
  ),
  DisplayCase(
    'FrostSliverWaterfallGrid.new',
    FrostSliverWaterfallGrid<int>,
    (_) => _inScroll(FrostSliverWaterfallGrid<int>(items: const [1, 2, 3], itemBuilder: _gridItem)),
    skip: _sliver,
  ),
  DisplayCase('FrostWrap.new', FrostWrap, (_) => const FrostWrap(children: [_box, _box, _box])),

  // lists/
  DisplayCase('FrostForm.new', FrostForm, (_) => FrostForm(onSubmit: () async => true, children: const [_box])),
  DisplayCase('FrostFormSection.new', FrostFormSection, (_) => const FrostFormSection(title: longLabel, children: [_box])),
  DisplayCase('FrostFormRow.new', FrostFormRow, (_) => const FrostFormRow(label: Text('Label'), control: _box)),
  DisplayCase(
    'FrostGroupedSection.new',
    FrostGroupedSection,
    (_) => FrostGroupedSection(
      header: 'Group',
      children: [FrostListRow(title: longLabel)],
    ),
  ),
  DisplayCase(
    'FrostList.new',
    FrostList<int>,
    (_) => hosted(
      height: 300,
      width: 400,
      child: FrostList<int>(
        items: const [1, 2, 3],
        itemBuilder: (context, item, selected) => FrostListRow(title: 'Row $item'),
      ),
    ),
    skip: _scroll,
  ),
  DisplayCase(
    'FrostReorderableList.new',
    FrostReorderableList<int>,
    (_) => hosted(
      height: 300,
      width: 400,
      child: FrostReorderableList<int>(
        items: const [1, 2, 3],
        itemBuilder: (context, item) => FrostListRow(title: 'Row $item'),
        onReorder: (_, _) {},
      ),
    ),
    skip: _scroll,
  ),
  DisplayCase(
    'FrostSelectableList.new',
    FrostSelectableList<int>,
    (_) => hosted(
      height: 300,
      width: 400,
      child: FrostSelectableList<int>(
        selection: FrostSelection<int>(),
        items: const [1, 2, 3],
        itemBuilder: (context, item, index) => FrostListRow(title: 'Row $item'),
      ),
    ),
    skip: _scroll,
  ),
  DisplayCase(
    'FrostSelectionBar.new',
    FrostSelectionBar<int>,
    (_) => FrostSelectionBar<int>(selection: FrostSelection<int>()..enter(), allItems: const [1, 2, 3]),
  ),
  DisplayCase('FrostSliverList.new', FrostSliverList, (_) => _inScroll(FrostSliverList(itemCount: 3, itemBuilder: _listRow)), skip: _sliver),
  DisplayCase(
    'FrostSliverList.columns',
    FrostSliverList,
    (_) => _inScroll(FrostSliverList.columns(itemCount: 3, itemBuilder: _listRow, minColumnWidth: 120)),
    skip: _sliver,
  ),
  DisplayCase('FrostSwipeActions.new', FrostSwipeActions, (_) => FrostSwipeActions(child: FrostListRow(title: longLabel))),
  DisplayCase(
    'FrostTable.new',
    FrostTable<int>,
    (_) => hosted(
      height: 300,
      width: 400,
      child: FrostTable<int>(
        columns: [FrostTableColumn<int>(label: longLabel, cell: (context, item) => Text('Item $item'))],
        rows: const [1, 2],
      ),
    ),
    skip: _scroll,
  ),

  // media/
  DisplayCase(
    'FrostMediaChrome.new',
    FrostMediaChrome,
    (_) => hosted(
      height: 200,
      width: 300,
      child: FrostMediaChrome(top: Text('Top'), bottom: Text('Bottom')),
    ),
    skip: const {'intrinsic': 'an overlay that fills the media frame it is stacked over; all its children are positioned against that frame'},
  ),
  DisplayCase(
    'FrostMediaHero.new',
    FrostMediaHero,
    (_) => FrostMediaHero(
      tag: FrostMediaHeroTag(image: _pictureProvider, aspectRatio: 1),
      child: _box,
    ),
  ),
  DisplayCase('FrostMediaImage.new', FrostMediaImage, (_) => _picture),
  DisplayCase('FrostMediaStage.new', FrostMediaStage, (_) => const FrostMediaStage(aspectRatio: 1.5, child: _box)),
  DisplayCase(
    'FrostMediaViewport.new',
    FrostMediaViewport,
    (_) => hosted(height: 200, width: 300, child: FrostMediaViewport(child: _box)),
    skip: const {'intrinsic': 'a zoom and pan viewport: the child is sized from the viewport, which fills what it is given'},
  ),
  DisplayCase(
    'FrostThumbnailStrip.new',
    FrostThumbnailStrip,
    (_) => FrostThumbnailStrip(itemCount: 3, itemBuilder: (context, index) => _picture, selectedIndex: 0, onSelected: (_) {}),
    skip: _scroll,
  ),
  DisplayCase(
    'FrostVideoFrame.new',
    FrostVideoFrame,
    (_) => hosted(
      height: 240,
      width: 400,
      child: FrostVideoFrame(
        video: _box,
        state: const FrostVideoState(playing: false, position: Duration.zero, duration: Duration(seconds: 60)),
        onPlayPause: () {},
        onSeek: (_) {},
      ),
    ),
  ),

  // motion/
  DisplayCase('FrostLayoutCrossfade.new', FrostLayoutCrossfade, (_) => const FrostLayoutCrossfade(layoutIdentity: 'a', child: _box)),
  DisplayCase('FrostLayoutCrossfade.media', FrostLayoutCrossfade, (_) => const FrostLayoutCrossfade.media(layoutIdentity: 'a', child: _box)),
  DisplayCase('FrostRollingText.new', FrostRollingText, (_) => const FrostRollingText('12345')),
  DisplayCase(
    'FrostSpringBuilder.new',
    FrostSpringBuilder,
    (_) => FrostSpringBuilder(value: 1, spring: FrostMotion.snappy, builder: (context, value, child) => _box),
  ),

  // navigation/
  DisplayCase('FrostInlinePageHeading.new', FrostInlinePageHeading, (_) => const FrostInlinePageHeading(title: longLabel)),
  DisplayCase(
    'FrostHeaderSections.new',
    FrostHeaderSections,
    (_) => const FrostHeaderSections(
      header: FrostPageHeader(title: Text('Header')),
      tabs: _box,
    ),
    skip: const {'intrinsic': 'a pinned-chrome row that measures its tabs against the width it is given and has no content size of its own'},
  ),
  DisplayCase('FrostPageHeader.new', FrostPageHeader, (_) => const FrostPageHeader(title: Text('Header'))),
  DisplayCase(
    'FrostPager.new',
    FrostPager,
    (_) => hosted(height: 200, width: 300, child: FrostPager(itemCount: 3, itemBuilder: (context, index) => Text('Page $index'))),
    skip: const {'intrinsic': 'a page viewport: pages take the size it is given, and a viewport cannot answer intrinsic sizes'},
  ),
  DisplayCase(
    'FrostSplitView.new',
    FrostSplitView,
    (_) => hosted(
      height: 200,
      width: 400,
      child: FrostSplitView(primary: _box, secondary: _box, onCloseSecondary: () {}),
    ),
    skip: const {'intrinsic': 'a page layout of two panes that divides the width it is given'},
  ),
  DisplayCase(
    'FrostToolbar.new',
    FrostToolbar,
    (_) => hosted(
      height: 56,
      width: 400,
      child: FrostToolbar(
        middle: const Text('Title'),
        trailing: [FrostToolbarItem.action(icon: _icon, label: longLabel, onPressed: () {})],
      ),
    ),
  ),

  // primitives/
  DisplayCase('FrostDivider.new', FrostDivider, (_) => hosted(width: 100, child: FrostDivider()), hasContent: false),
  DisplayCase('FrostIcon.new', FrostIcon, (_) => FrostIcon(_icon, semanticLabel: 'Icon')),
  DisplayCase('FrostBleed.new', FrostBleed, (_) => const FrostBleed(amount: 4, child: _box)),
  DisplayCase(
    'FrostKeyline.new',
    FrostKeyline,
    (_) => const FrostKeyline(leadingRoom: 0, trailingRoom: 0, edgeDistanceStart: 0, edgeDistanceEnd: 0, insideContainer: false, contentStart: 0, child: _box),
  ),
  DisplayCase('FrostMediaFrame.new', FrostMediaFrame, (_) => const FrostMediaFrame(aspectRatio: 1.5, child: _picture)),
  DisplayCase('FrostMediaFrame.skeleton', FrostMediaFrame, (_) => hosted(width: 100, child: FrostMediaFrame.skeleton(aspectRatio: 1.5))),
  DisplayCase('FrostPathText.new', FrostPathText, (_) => const FrostPathText('/home/user/some/long/path/file.txt')),
  DisplayCase('FrostStatusGlyph.new', FrostStatusGlyph, (_) => const FrostStatusGlyph(kind: FrostStatusGlyphKind.success, size: 20)),
  DisplayCase('FrostSurface.new', FrostSurface, (_) => const FrostSurface(role: FrostSurfaceRole.panel, child: _box)),
  DisplayCase('FrostText.new', FrostText, (_) => const FrostText('Hello world')),
  DisplayCase('FrostText.rich', FrostText, (_) => const FrostText.rich(TextSpan(text: longLabel))),

  // social/
  DisplayCase(
    'FrostThread.new',
    FrostThread,
    (_) => FrostThread(
      item: FrostThreadItem(
        author: 'Alice',
        body: const Text('Hello'),
        avatar: const FrostAvatar(initials: 'A', semanticLabel: 'a'),
      ),
    ),
  ),
  DisplayCase(
    'FrostMediaMosaic.new',
    FrostMediaMosaic,
    (_) => hosted(
      width: 300,
      child: FrostMediaMosaic(images: [_pictureProvider, _pictureProvider], sizes: [Size(100, 100), Size(100, 100)]),
    ),
  ),
  DisplayCase(
    'FrostMediaMosaic.skeleton',
    FrostMediaMosaic,
    (_) => hosted(width: 300, child: FrostMediaMosaic.skeleton(count: 2, sizes: [Size(100, 100), Size(100, 100)])),
  ),

  // surface/
  DisplayCase(
    'FrostAmbientBackdrop.new',
    FrostAmbientBackdrop,
    (_) => hosted(width: 100, height: 100, child: FrostAmbientBackdrop()),
    skip: const {'intrinsic': 'a window backdrop with no content: it paints whatever area it is given'},
  ),

  // overlays/
  DisplayCase('FrostTooltip.new', FrostTooltip, (_) => const FrostTooltip(message: longLabel, child: _box)),
  DisplayCase(
    'FrostContextMenuRegion.new',
    FrostContextMenuRegion,
    (_) => FrostContextMenuRegion(
      entries: [FrostMenuAction('Entry', onSelected: () {})],
      child: _box,
    ),
  ),
  DisplayCase(
    'FrostAdaptiveMenuAnchor.new',
    FrostAdaptiveMenuAnchor,
    (_) => FrostAdaptiveMenuAnchor(
      entries: [FrostMenuAction('Entry', onSelected: () {})],
      builder: (context, focus, toggle) => _box,
    ),
  ),
];

Widget _listRow(BuildContext context, int index) => SizedBox(height: 40, child: Text('Item $index'));

Widget _scrollable({ScrollController? controller, ScrollPhysics? physics}) =>
    ListView(controller: controller, physics: physics, children: const [_box, _box, _box]);

const _pictureProvider = _TestImage();
const _picture = FrostMediaImage(
  child: SizedBox(width: 160, height: 120, child: ColoredBox(color: Colors.red)),
);

class _TestImage extends ImageProvider<_TestImage> {
  const _TestImage();
  @override
  Future<_TestImage> obtainKey(ImageConfiguration configuration) => Future.value(this);
}

/// Components that only arrange or animate their children and read no Frost
/// theme, scope or configuration. The no-theme check asks for an error where a
/// component would otherwise use a missing environment; these use none.
const _layoutOnly = {
  'FrostKeepAlive.new',
  'FrostColumnPlacement.new',
  'FrostContentColumn.new',
  'FrostContentViewport.new',
  'FrostSliverContentColumn.new',
  'FrostFit.new',
  'FrostBleed.new',
  'FrostKeyline.new',
  'FrostLayoutCrossfade.new',
  'FrostLayoutCrossfade.media',
  'FrostSpringBuilder.new',
  'FrostSliverExpand.new',
  'FrostLoadingGate.new',
  'FrostChromeSpacer.new',
  'FrostWrap.new',
  'FrostGrid.new',
  'FrostSliverGrid.new',
  'FrostWaterfallGrid.new',
  'FrostSliverWaterfallGrid.new',
  'FrostSliverList.new',
  'FrostSliverList.columns',
  'FrostAutoScaffold.new',
  'FrostLoadingScrollView.new',
  'FrostForm.new',
  'FrostMediaViewport.new',
  'FrostFormRow.new',
  'FrostMediaImage.new',
  'FrostMediaStage.new',
  'FrostRollingText.new',
};

List<DisplayCase> _exempt(List<DisplayCase> cases) {
  for (final c in cases) {
    if (_layoutOnly.contains(c.id)) c.skip['no-theme'] = 'pure layout or animation: it reads no Frost theme, scope or configuration';
  }
  return cases;
}
