import 'package:frost_ui/frost_ui.dart';
import 'package:material_ui/material_ui.dart';

/// A page of a pinned header over one scrolling body, composed from the public
/// pieces: the header in a content column and the slivers in a sliver column
/// under the chrome spacer.
Widget pinnedPage({
  required Widget header,
  required List<Widget> slivers,
  Widget? tabs,
  Widget? trailing,
  double maxWidth = double.infinity,
  ScrollController? controller,
}) => FrostPinnedChrome(
  chrome: FrostContentColumn(
    maxWidth: maxWidth,
    child: tabs == null ? header : FrostHeaderSections(header: header, tabs: tabs, trailing: trailing),
  ),
  body: FrostLoadingScrollView(
    controller: controller,
    slivers: [
      const FrostChromeSpacer(),
      FrostSliverContentColumn(
        maxWidth: maxWidth,
        sliver: SliverMainAxisGroup(slivers: slivers),
      ),
    ],
  ),
);

/// A page of a pinned header with section tabs over one tab-view body per
/// section, each kept alive and marked active only while on screen; each section
/// may pull to refresh on its own.
Widget sectionedPage({
  required Widget header,
  required Widget tabs,
  required int sections,
  required List<Widget> Function(BuildContext context, int section) slivers,
  Widget? trailing,
  double maxWidth = double.infinity,
  FrostTabController? controller,
  FrostRefreshAction? Function(int section)? onRefresh,
}) => FrostPinnedChrome(
  chrome: FrostContentColumn(
    maxWidth: maxWidth,
    child: FrostHeaderSections(header: header, tabs: tabs, trailing: trailing),
  ),
  body: Builder(
    builder: (context) {
      final tabController = controller ?? FrostDefaultTabController.of(context);
      return ListenableBuilder(
        listenable: tabController,
        builder: (context, _) => FrostTabView(
          controller: tabController,
          children: [
            for (var section = 0; section < sections; section++)
              FrostKeepAlive(
                child: FrostChromeActiveBody(
                  active: tabController.index == section,
                  child: Builder(
                    builder: (context) {
                      Widget view(Widget? refreshHeader) => FrostLoadingScrollView(
                        slivers: [
                          const FrostChromeSpacer(),
                          if (refreshHeader != null) FrostSliverContentColumn(maxWidth: maxWidth, sliver: refreshHeader),
                          FrostSliverContentColumn(
                            maxWidth: maxWidth,
                            sliver: SliverMainAxisGroup(slivers: slivers(context, section)),
                          ),
                        ],
                      );
                      final refresh = onRefresh?.call(section);
                      return refresh == null
                          ? view(null)
                          : FrostRefreshView(onRefresh: refresh, builder: (context, physics, locators) => view(locators.sliverHeader));
                    },
                  ),
                ),
              ),
          ],
        ),
      );
    },
  ),
);
