import 'package:flutter/widgets.dart';

import '../foundation/metrics.dart';
import '../foundation/spacing.dart';
import '../foundation/tokens.dart';
import '../primitives/divider.dart';
import '../primitives/keyline.dart';
import '_content_padding.dart';
import 'column_placement.dart';
import 'content_viewport.dart';
import 'pinned_chrome.dart';

// The navigation column and content limit include their own page insets. The
// smallest column and content limit apply to narrow windows and set where the
// split turns wide; wider windows grow both, up to their larger limits.
const frostColumnNavigationWidth = 236.0, frostColumnContentMaxWidth = 640.0;
const _navigationMaxWidth = 320.0, _navigationFraction = .22;
const _contentGrowsFrom = 1200.0, _contentGrowsTo = 1600.0, _contentLargestMaxWidth = 800.0;
// The content keyline is 32 points beyond the one-physical-pixel divider.
const frostColumnContentInset = 32.0;
// Navigation plus a readable form column and their real keyline gap.
const _minimumContentWidth = 320.0;

/// Whether [width] fits the navigation column beside readable content.
bool frostColumnSplitIsWide(BuildContext context, double width) =>
    width >= frostColumnNavigationWidth + frostColumnContentInset + _minimumContentWidth + FrostGap.of(context).page;

/// The navigation column's width in a layout [width] wide: 22% of it, held
/// between 236 and 320 points, on a whole logical pixel so the hairline and the
/// content edge stay crisp.
double frostColumnNavigationWidthFor(double width) => (width * _navigationFraction).roundToDouble().clamp(frostColumnNavigationWidth, _navigationMaxWidth);

/// The content limit in a layout [width] wide: 640 points up to 1200, then
/// growing evenly to 800 at 1600.
double frostColumnContentMaxWidthFor(double width) {
  final grown = ((width - _contentGrowsFrom) / (_contentGrowsTo - _contentGrowsFrom)).clamp(0.0, 1.0);
  return frostColumnContentMaxWidth + (_contentLargestMaxWidth - frostColumnContentMaxWidth) * grown;
}

/// The navigation column, a hairline and the content pane. Narrow layouts give
/// [navigation] the full width and keep [content] mounted but offstage, so
/// narrowing a window never disposes the content that was built while wide.
class FrostColumnPanes extends StatelessWidget {
  const FrostColumnPanes({required this.wide, required this.width, required this.navigation, required this.content, super.key});
  final bool wide;

  /// The available width the layout was measured at.
  final double width;
  final Widget navigation;

  /// Null until a wide layout has built the content once.
  final Widget? content;

  @override
  Widget build(BuildContext context) {
    final dividerWidth = 1 / MediaQuery.devicePixelRatioOf(context);
    final navigationWidth = frostColumnNavigationWidthFor(width);
    return FrostBleedBoundary(
      child: Stack(
        children: [
          PositionedDirectional(start: 0, top: 0, bottom: 0, width: wide ? navigationWidth : width, child: navigation),
          if (wide)
            PositionedDirectional(
              start: navigationWidth,
              top: 0,
              bottom: 0,
              width: dividerWidth,
              child: const FrostDivider(axis: Axis.vertical),
            ),
          // Keep the same content slot and bounded geometry even while hidden.
          PositionedDirectional(
            key: const ValueKey('settings-section-content'),
            start: wide ? navigationWidth + dividerWidth : 0,
            end: 0,
            top: 0,
            bottom: 0,
            child: Offstage(
              offstage: !wide,
              child: FrostColumnPlacement(
                alignment: Directionality.of(context) == TextDirection.ltr ? FrostColumnAlignment.start : FrostColumnAlignment.end,
                maxWidth: frostColumnContentMaxWidthFor(width) + frostColumnContentInset + FrostMetrics.browseInset(width),
                child: FrostContentPadding(
                  padding: EdgeInsetsDirectional.only(start: frostColumnContentInset, end: FrostMetrics.browseInset(width)),
                  child: content ?? const SizedBox.shrink(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// [panes] under an optional pinned [header], or [narrowPage] in their place
/// on narrow layouts. Narrow layouts paint the canvas; wide ones let the
/// window's material show through.
class FrostColumnBody extends StatelessWidget {
  const FrostColumnBody({required this.wide, required this.panes, this.header, this.narrowPage, this.retainsPanes = false, super.key});
  final bool wide;
  final Widget panes;
  final Widget? header, narrowPage;

  /// Keeps [header] and [panes] mounted, offstage, while [narrowPage] shows,
  /// so the column's scroll offset, focus and state survive the page.
  final bool retainsPanes;

  @override
  Widget build(BuildContext context) {
    final showsPage = !wide && narrowPage != null;
    var split = panes;
    if (header case final header?) {
      split = FrostPinnedChrome(
        chrome: FrostContentColumn(maxWidth: double.infinity, child: header),
        body: Builder(
          builder: (context) => Padding(
            padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top),
            child: panes,
          ),
        ),
      );
    }
    final Widget body;
    if (retainsPanes) {
      // One structure in every layout: the split keeps its slot under the page.
      body = Stack(
        fit: StackFit.expand,
        children: [
          Offstage(
            offstage: showsPage,
            child: TickerMode(
              enabled: !showsPage,
              child: ExcludeFocus(
                excluding: showsPage,
                child: ExcludeSemantics(excluding: showsPage, child: split),
              ),
            ),
          ),
          ?(showsPage ? narrowPage : null),
        ],
      );
    } else {
      body = showsPage ? narrowPage! : split;
    }
    return ColoredBox(
      color: FrostThemeTokens.of(context).canvas.withValues(alpha: wide ? 0 : 1),
      child: body,
    );
  }
}
