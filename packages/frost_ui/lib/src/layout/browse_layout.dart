import 'dart:math' as math;

import 'package:flutter/material.dart' show DefaultTabController, TabController;
import 'package:flutter/widgets.dart';

import '../feedback/refresh_indicator.dart';
import '../feedback/refresh_view.dart';
import '../foundation/metrics.dart';
import '../primitives/_page_outline.dart';
import '_content_padding.dart';
import '_template_scroll.dart';
import 'column_placement.dart';
import 'content_viewport.dart';
import 'header_sections.dart';

/// Media collections can meet the panel edge while text keeps the page keyline.
enum FrostBrowseContentInset { keyline, edge }

typedef FrostBrowseSectionBuilder = FrostBrowseSection Function(BuildContext context, int index);

/// One section's body in [FrostBrowseLayout.sectioned]. The fields mean what
/// they mean on [FrostBrowseLayout], for this section alone.
class FrostBrowseSection {
  const FrostBrowseSection({required this.slivers, this.filterBar, this.empty, this.isEmpty = false, this.onRefresh});
  final List<Widget> slivers;
  final Widget? filterBar, empty;
  final bool isEmpty;

  /// Pull to refresh for this section; the layout places the refresh header
  /// below [filterBar], also while the section is empty. Do not wrap a
  /// sectioned layout in a FrostRefreshView: it would not hear the sections.
  final FrostRefreshAction? onRefresh;
}

/// A fixed page header above scrolling filters and application-owned slivers.
/// The template supplies the shared content column and its alignment keyline.
/// For selection, use Column(children: [Expanded(child: thisLayout),
/// FrostSelectionBar(selection: selection, allItems: items)]). Keep this
/// layout's key stable so bottom-slot resizing preserves its scroll position.
/// A Stack overlay instead requires the caller to reserve the bar's height.
class FrostBrowseLayout extends StatelessWidget {
  const FrostBrowseLayout({
    required this.header,
    required this.slivers,
    this.sections,
    this.filterBar,
    this.preloadExtent = 480,
    this.empty,
    this.isEmpty = false,
    this.maxWidth = double.infinity,
    this.contentInset = FrostBrowseContentInset.keyline,
    super.key,
  }) : sectionBuilder = null,
       controller = null,
       assert(maxWidth > 0);

  /// One body per section of [sections], each with its own scroll position,
  /// filters, refresh and empty state. [sectionBuilder] runs for a section
  /// once it is first shown; shown sections stay alive while this layout
  /// does, so switching never resets another section.
  ///
  /// On touch, swiping sideways pages between neighbouring sections and the
  /// tab indicator follows the finger; a mouse or trackpad switches by the
  /// tabs and their keys. An inner horizontal scroller, such as a thumbnail
  /// strip or zoomed media, takes the drag first. The header's one-row or
  /// two-row form does not depend on the section; its sliding row and glass
  /// follow the section on screen. Reduced motion jumps between sections.
  ///
  /// [controller] is the tabs' controller, usually the same one given to the
  /// [FrostTabBar] in [sections]; null uses the enclosing
  /// [DefaultTabController]. Its length is the number of sections.
  const FrostBrowseLayout.sectioned({
    required this.header,
    required FrostHeaderSections this.sections,
    required FrostBrowseSectionBuilder this.sectionBuilder,
    this.controller,
    this.preloadExtent = 480,
    this.maxWidth = double.infinity,
    this.contentInset = FrostBrowseContentInset.keyline,
    super.key,
  }) : slivers = const [],
       filterBar = null,
       empty = null,
       isEmpty = false,
       assert(maxWidth > 0);
  final Widget header;

  /// Section tabs that belong to [header], such as Latest / Popular: in the
  /// header row when they fit beside its actions, otherwise in a pinned row
  /// below it while the header row slides away with scrolling. See
  /// [FrostHeaderSections]. The [filterBar] scrolls with the content either way.
  final FrostHeaderSections? sections;

  /// Distance before a paged section end at which another page may load.
  final double preloadExtent;
  final Widget? filterBar, empty;
  final List<Widget> slivers;
  final bool isEmpty;

  /// Outer content-column limit shared by the header, filters and slivers.
  /// Use double.infinity for fluid media collections; page insets still apply.
  final double maxWidth;

  /// Edge removes only the media slivers' page inset, without negative margins.
  /// Header and filter text retain the keyline. Keep prose/status slivers in a
  /// FrostSliverContentColumn when mixing them into an edge media collection.
  final FrostBrowseContentInset contentInset;

  /// Set by [FrostBrowseLayout.sectioned]; [slivers], [filterBar], [empty]
  /// and [isEmpty] are then per section.
  final FrostBrowseSectionBuilder? sectionBuilder;
  final TabController? controller;

  @override
  Widget build(BuildContext context) {
    final sectionBuilder = this.sectionBuilder;
    return FrostTemplateScroll(
      header: header,
      sections: sections,
      maxWidth: maxWidth,
      layoutIdentity: isEmpty,
      scrollViewBuilder: (slivers) => FrostLoadingScrollView(slivers: slivers, preloadExtent: preloadExtent),
      insetSlivers: false,
      slivers: sectionBuilder == null ? _slivers(filterBar, isEmpty, empty, slivers) : const [],
      sectionBodies: sectionBuilder == null
          ? null
          : FrostTemplateSections(
              controller: controller,
              builder: (context, index) {
                final section = sectionBuilder(context, index);
                return FrostTemplateSection(
                  layoutIdentity: section.isEmpty,
                  onRefresh: section.onRefresh,
                  slivers: (refreshHeader) => _slivers(section.filterBar, section.isEmpty, section.empty, section.slivers, refreshHeader),
                );
              },
            ),
    );
  }

  List<Widget> _slivers(Widget? filterBar, bool isEmpty, Widget? empty, List<Widget> slivers, [Widget? refreshHeader]) => [
    FrostSliverContentColumn(
      maxWidth: maxWidth,
      sliver: SliverToBoxAdapter(child: FrostTemplateOptional(child: filterBar)),
    ),
    if (refreshHeader != null) FrostSliverContentColumn(maxWidth: maxWidth, sliver: refreshHeader),
    if (isEmpty)
      FrostSliverContentColumn(
        maxWidth: maxWidth,
        sliver: SliverFillRemaining(hasScrollBody: false, child: Center(child: empty)),
      )
    else if (contentInset == FrostBrowseContentInset.keyline)
      FrostSliverContentColumn(
        maxWidth: maxWidth,
        sliver: SliverMainAxisGroup(slivers: slivers),
      )
    else
      _EdgeSliverColumn(
        maxWidth: maxWidth,
        sliver: SliverMainAxisGroup(slivers: slivers),
      ),
  ];
}

/// Retain the configured width cap/placement; remove only the page text inset.
class _EdgeSliverColumn extends StatelessWidget {
  const _EdgeSliverColumn({required this.maxWidth, required this.sliver});
  final double maxWidth;
  final Widget sliver;
  @override
  Widget build(BuildContext context) => SliverLayoutBuilder(
    builder: (context, constraints) {
      final textInset = FrostMetrics.browseInset(FrostPageOutline.contentWidth(context, constraints.crossAxisExtent));
      final column = FrostColumnPlacement.columnPadding(context, constraints.crossAxisExtent, maxWidth: maxWidth);
      return SliverPadding(
        padding: EdgeInsets.only(left: math.max(0, column.left - textInset), right: math.max(0, column.right - textInset)),
        sliver: FrostPageOutline.content(context, FrostContentPadding(padding: null, child: sliver)),
      );
    },
  );
}
