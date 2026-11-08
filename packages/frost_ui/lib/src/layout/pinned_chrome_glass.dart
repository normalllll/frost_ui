part of 'pinned_chrome.dart';

/// How a [FrostPinnedChromeGlass] joins bars pinned directly above one another
/// into one band: the upper one ([top]) keeps the sheet's top corners and has
/// no separator; the lower one ([bottom]) has no corners and closes the band
/// with the separator.
enum FrostPinnedChromeCorners { all, top, bottom }

/// The glass behind a pinned bar, shown while content passes beneath it,
/// with the bar's own content as [child].
///
/// On desktop the glass is a band across the whole content sheet, closed by a
/// separator below and clipped by the sheet's upper corners. Compact layouts
/// keep an edge-to-edge bar under the status bar.
class FrostPinnedChromeGlass extends StatelessWidget {
  const FrostPinnedChromeGlass({required this.opacity, this.child, this.animate = true, this.corners = FrostPinnedChromeCorners.all, super.key})
    : _hiddenExtent = 0,
      _reach = 0;

  const FrostPinnedChromeGlass._({
    required this.opacity,
    required this._hiddenExtent,
    this.child,
    this.animate = true,
    this.corners = FrostPinnedChromeCorners.all,
    this._reach = 0,
  });

  final double opacity;

  /// How far a pinned bar's top row has slid away: the glass ends that much
  /// above the bar's bottom.
  final double _hiddenExtent;

  /// How far the glass extends above the bar, over a bar this one continues, so
  /// one blur runs across the joined band.
  final double _reach;
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
      borderRadius: corners == FrostPinnedChromeCorners.bottom && _reach == 0
          ? BorderRadius.zero
          : BorderRadius.only(topLeft: inheritedRadius.topLeft, topRight: inheritedRadius.topRight),
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
      clipBehavior: _reach > 0 ? Clip.none : Clip.hardEdge,
      children: [
        Positioned.fill(right: FrostPageOutline.channelOf(context), top: -_reach, bottom: _hiddenExtent, child: layer),
        ?child,
      ],
    );
  }
}
