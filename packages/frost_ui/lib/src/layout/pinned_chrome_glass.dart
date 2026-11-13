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
      _bodies = null,
      _bodiesMoved = null;

  const FrostPinnedChromeGlass._({
    required this.opacity,
    required this._hiddenExtent,
    this.child,
    this.animate = true,
    this.corners = FrostPinnedChromeCorners.all,
    this._bodies,
    this._bodiesMoved,
  });

  /// The bodies of a group under the bar that have content beneath it, each
  /// with how much glass its own scrolling shows. The glass over a body is
  /// that body's own and stays across the body's width wherever the body is,
  /// so two sections side by side mid-swipe each keep theirs. Null draws one
  /// glass at [opacity].
  final List<(RenderBox, double)>? _bodies;

  /// Tells when the bodies move sideways.
  final Listenable? _bodiesMoved;

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
      borderRadius: corners == FrostPinnedChromeCorners.bottom
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
    Widget layer(double opacity) => IgnorePointer(
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
    final channel = FrostPageOutline.channelOf(context);
    return Stack(
      fit: StackFit.passthrough,
      children: [
        if (_bodies case final bodies?)
          for (final (body, coverage) in bodies)
            Positioned.fill(
              key: ObjectKey(body),
              right: channel,
              bottom: _hiddenExtent,
              child: _BodyGlassClip(body: body, moved: _bodiesMoved!, child: layer(coverage)),
            )
        else
          Positioned.fill(right: channel, bottom: _hiddenExtent, child: layer(opacity)),
        ?child,
      ],
    );
  }
}

/// Shows its child only across the width [body] takes on screen.
class _BodyGlassClip extends SingleChildRenderObjectWidget {
  const _BodyGlassClip({required this.body, required this.moved, required super.child});
  final RenderBox body;
  final Listenable moved;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderBodyGlassClip(body, moved);

  @override
  void updateRenderObject(BuildContext context, _RenderBodyGlassClip renderObject) => renderObject
    ..body = body
    ..moved = moved;
}

class _RenderBodyGlassClip extends RenderProxyBox {
  _RenderBodyGlassClip(this._body, this._moved);

  RenderBox _body;
  set body(RenderBox value) {
    if (identical(_body, value)) return;
    _body = value;
    markNeedsPaint();
  }

  Listenable _moved;
  set moved(Listenable value) {
    if (identical(_moved, value)) return;
    if (attached) _moved.removeListener(markNeedsPaint);
    _moved = value;
    if (attached) _moved.addListener(markNeedsPaint);
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _moved.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _moved.removeListener(markNeedsPaint);
    super.detach();
  }

  /// The body's span in this box, read at paint: the body is laid out by
  /// then, so the glass moves in the same frame as the body.
  Rect? _span() {
    if (!_body.attached || !_body.hasSize) return null;
    final inverse = Matrix4.tryInvert(getTransformTo(null));
    if (inverse == null) return null;
    final body = MatrixUtils.transformRect(inverse, MatrixUtils.transformRect(_body.getTransformTo(null), Offset.zero & _body.size));
    final left = math.max(0.0, body.left), right = math.min(size.width, body.right);
    return right > left ? Rect.fromLTRB(left, 0, right, size.height) : null;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final span = _span();
    if (span == null) {
      layer = null;
    } else if (span.width >= size.width) {
      layer = null;
      super.paint(context, offset);
    } else {
      layer = context.pushClipRect(needsCompositing, offset, span, super.paint, oldLayer: layer as ClipRectLayer?);
    }
  }
}
