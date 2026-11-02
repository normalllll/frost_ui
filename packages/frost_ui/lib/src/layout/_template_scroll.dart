import 'package:flutter/material.dart' show TabController;
import 'package:flutter/widgets.dart';

import '../feedback/refresh_view.dart';
import '../motion/layout_crossfade.dart';
import '../primitives/presence.dart';
import '_header_search_body.dart';
import '_section_pages.dart';
import 'column_placement.dart';
import 'content_viewport.dart';
import 'header_sections.dart';
import 'pinned_chrome.dart';

/// Shared page chrome and sliver column composition, without new materials.
///
/// On narrow windows a suggesting search field in [header] lists its
/// suggestions over the body: the body stays laid out underneath, hidden, and
/// comes back as it was when the suggestions close.
class FrostTemplateScroll extends StatefulWidget {
  const FrostTemplateScroll({
    required this.header,
    required this.slivers,
    this.sections,
    this.sectionBodies,
    this.layoutIdentity = false,
    this.scrollViewBuilder,
    this.insetSlivers = true,
    this.maxWidth = double.infinity,
    super.key,
  });
  final Widget header;

  /// Section tabs that belong to [header]; see [FrostHeaderSections].
  final FrostHeaderSections? sections;

  /// One body per section in place of [slivers], paged under the one header.
  final FrostTemplateSections? sectionBodies;
  final Widget Function(List<Widget> slivers)? scrollViewBuilder;
  final Object layoutIdentity;
  final List<Widget> slivers;
  final double maxWidth;
  final bool insetSlivers;

  @override
  State<FrostTemplateScroll> createState() => _TemplateScrollState();
}

class _TemplateScrollState extends State<FrostTemplateScroll> {
  final _search = FrostHeaderSearchBody();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final material = FrostPinnedChromeMaterial.enabledOf(context);
    // A new page controller owns a different content/offset cache. Recreate
    // only the viewport; header anchors/focus and open filters stay mounted.
    final viewport = ObjectKey(PrimaryScrollController.maybeOf(context));
    final sections = widget.sectionBodies;
    final body = sections == null
        ? FrostTimedLayoutCrossfade(key: viewport, layoutIdentity: widget.layoutIdentity, settleDuration: Duration.zero, child: _scrollView(widget.slivers))
        : FrostSectionPages(key: viewport, controller: sections.controller, itemBuilder: (context, index) => _section(sections.builder(context, index)));
    final chrome = FrostPinnedChrome(
      chrome: FrostContentColumn(
        maxWidth: widget.maxWidth,
        child: widget.sections == null ? widget.header : FrostSectionedHeader(header: widget.header, sections: widget.sections!),
      ),
      body: FrostHeaderSearchConcealed(
        link: _search,
        child: ListenableBuilder(
          listenable: _search,
          builder: (context, body) => ExcludeFocus(excluding: _search.showing, child: body!),
          child: body,
        ),
      ),
    );
    return FrostPageColumnWidth(
      width: widget.maxWidth,
      child: FrostHeaderSearchBodyScope(
        link: _search,
        child: FrostHeaderSearchPage(
          link: _search,
          child: ListenableBuilder(
            listenable: _search,
            // The header sits on the suggestions page, not over scrolled content.
            builder: (context, chrome) => FrostPinnedChromeMaterial(enabled: material && !_search.showing, child: chrome!),
            child: chrome,
          ),
        ),
      ),
    );
  }

  Widget _section(FrostTemplateSection section) {
    Widget view(Widget? refreshHeader) => _scrollView(section.slivers(refreshHeader));
    final onRefresh = section.onRefresh;
    return FrostTimedLayoutCrossfade(
      layoutIdentity: section.layoutIdentity,
      settleDuration: Duration.zero,
      // Each section pulls to refresh on its own: a refresh view around the
      // pages would not hear the scrolling inside them.
      child: onRefresh == null ? view(null) : FrostRefreshView(onRefresh: onRefresh, builder: (context, physics, locators) => view(locators.sliverHeader)),
    );
  }

  Widget _scrollView(List<Widget> slivers) {
    final column = [
      const FrostChromeSpacer(),
      for (final sliver in slivers)
        if (widget.insetSlivers) FrostSliverContentColumn(maxWidth: widget.maxWidth, sliver: sliver) else sliver,
    ];
    return widget.scrollViewBuilder?.call(column) ?? CustomScrollView(slivers: column);
  }
}

/// Library-only: one body per section for [FrostTemplateScroll]. The count is
/// [controller]'s length, or the enclosing DefaultTabController's.
class FrostTemplateSections {
  const FrostTemplateSections({required this.builder, this.controller});
  final TabController? controller;
  final FrostTemplateSection Function(BuildContext context, int index) builder;
}

/// Library-only: a section's slivers, given the refresh header to place
/// among them when [onRefresh] is set.
class FrostTemplateSection {
  const FrostTemplateSection({required this.slivers, this.layoutIdentity = false, this.onRefresh});
  final List<Widget> Function(Widget? refreshHeader) slivers;
  final Object layoutIdentity;
  final FrostRefreshAction? onRefresh;
}

/// Keeps the outgoing slot alive while Presence collapses its measured height.
class FrostTemplateOptional extends StatefulWidget {
  const FrostTemplateOptional({required this.child, super.key});
  final Widget? child;
  @override
  State<FrostTemplateOptional> createState() => _OptionalState();
}

class _OptionalState extends State<FrostTemplateOptional> {
  Widget? _last;
  @override
  void initState() {
    super.initState();
    _last = widget.child;
  }

  @override
  void didUpdateWidget(FrostTemplateOptional oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.child != null) _last = widget.child;
  }

  @override
  Widget build(BuildContext context) => FrostPresence(
    visible: widget.child != null,
    effect: FrostPresenceEffect.expand,
    alignment: AlignmentDirectional.topStart,
    child: _last ?? const SizedBox.shrink(),
  );
}
