part of 'pinned_chrome.dart';

/// Which outer corners a [FrostPinnedChromeGlass] rounds. Bars that are pinned
/// directly above one another share one outline: the upper one rounds its
/// top corners, the lower one its bottom corners.
enum FrostPinnedChromeCorners { all, top, bottom }

/// The glass behind a pinned bar, shown while content passes beneath it,
/// with the bar's own content as [child].
///
/// On desktop the glass is a band across the whole content sheet, closed by a
/// separator below and clipped by the sheet's upper corners. Compact layouts
/// keep an edge-to-edge bar under the status bar.
class FrostPinnedChromeGlass extends StatelessWidget {
  const FrostPinnedChromeGlass({required this.opacity, this.child, this.animate = true, this.corners = FrostPinnedChromeCorners.all, super.key})
    : _hiddenExtent = 0;

  const FrostPinnedChromeGlass._({required this.opacity, required this._hiddenExtent, this.child, this.animate = true})
    : corners = FrostPinnedChromeCorners.all;

  final double opacity;

  /// How far a pinned bar's top row has slid away: the glass ends that much
  /// above the bar's bottom.
  final double _hiddenExtent;
  final Widget? child;

  /// Ease [opacity] changes; pass false when it already follows scrolling.
  final bool animate;
  final FrostPinnedChromeCorners corners;

  @override
  Widget build(BuildContext context) {
    // The sampling surface needs the page's own outline. An ancestor clip alone
    // can leave a square backdrop-filter corner in native GPU composition.
    final inheritedRadius = FrostPageOutline.of(context);
    final band = FrostSurface(
      role: FrostSurfaceRole.chrome,
      borderRadius: BorderRadius.only(topLeft: inheritedRadius.topLeft, topRight: inheritedRadius.topRight),
      edge: FrostSurfaceEdge.none,
      elevated: false,
      child: SizedBox.expand(),
    );
    // A full-width band: the column's band, closed below by a hairline
    // unless another bar continues it.
    final line = FrostThemeTokens.of(context).separator;
    final material = Builder(
      builder: (context) {
        // The separator belongs to this material reveal, not to its content.
        // A normal decoration does not consume material-only reveal scopes.
        final progress = FrostMaterialRevealScope.maybeOf(context)?.progress ?? 1;
        return DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            border: corners == FrostPinnedChromeCorners.top
                ? null
                : Border(
                    bottom: BorderSide(
                      color: line.withValues(alpha: line.a * progress),
                      width: 1 / MediaQuery.devicePixelRatioOf(context),
                    ),
                  ),
          ),
          child: band,
        );
      },
    );
    final layer = IgnorePointer(
      child: animate
          ? FrostAnimatedMaterialReveal(
              materialOnly: true,
              contentOnly: false,
              opacity: opacity,
              duration: FrostMotion.duration(context, FrostMotion.hover),
              child: material,
            )
          : FrostMaterialReveal(materialOnly: true, opacity: opacity, child: material),
    );
    return Stack(
      fit: StackFit.passthrough,
      children: [
        Positioned.fill(right: FrostPageOutline.channelOf(context), bottom: _hiddenExtent, child: layer),
        ?child,
      ],
    );
  }
}
