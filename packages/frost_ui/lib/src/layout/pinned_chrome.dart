import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:frost_ui/src/foundation/metrics.dart';
import 'package:frost_ui/src/foundation/tokens.dart';
import 'package:frost_ui/src/layout/auto_scaffold.dart';
import 'package:frost_ui/src/layout/column_placement.dart';
import 'package:frost_ui/src/navigation/shell_navigation_scope.dart';
import 'package:frost_ui/src/surface/ambient_backdrop.dart';
import 'package:frost_ui/src/surface/surface.dart';

/// A bar pinned over the top of a scrolling body. The body scrolls beneath
/// the bar, and the bar's glass material appears once content is actually
/// underneath it, so a page at rest keeps one continuous backdrop.
///
/// The body receives the bar's height as its top [MediaQuery] padding, which
/// insets the scrollbar; scroll views add [FrostChromeSpacer] as their first
/// sliver so the first item starts below the bar.
///
/// Scrolling over the bar scrolls the list beneath it: wheel and drag input
/// that no control in the bar takes goes to the vertical scroll view under
/// the pointer.
class FrostPinnedChrome extends StatefulWidget {
  const FrostPinnedChrome({required this.chrome, required this.body, this.extent, this.estimatedExtent = kToolbarHeight, this.columnMaxWidth, super.key});

  /// Fixed height of the bar, including any top safe area it covers. When
  /// null the bar is measured, starting from [estimatedExtent].
  final double? extent;
  final double estimatedExtent;
  final Widget chrome;
  final Widget body;

  /// The width of the page's content column; see
  /// [FrostPinnedChromeGlass.columnMaxWidth].
  final double? columnMaxWidth;

  @override
  State<FrostPinnedChrome> createState() => _FpPinnedChromeState();
}

class _FpPinnedChromeState extends State<FrostPinnedChrome> {
  /// How much of the glass is showing: it follows the first [_revealDistance]
  /// of scrolling, so the bar stops wherever the finger stops instead of
  /// snapping in at a threshold.
  double _coverage = 0;
  double? _measured;
  final _bodyKey = GlobalKey();

  /// Vertical scroll views in the body, gathered from their metrics
  /// notifications; input over the bar goes to the one under the pointer.
  final _scrollables = <ScrollableState>{};
  Drag? _drag;

  static const _revealDistance = 24.0;

  bool _handleMetrics(ScrollMetricsNotification notification) {
    _track(notification.context);
    return false;
  }

  void _track(BuildContext? context) {
    final scrollable = context?.findAncestorStateOfType<ScrollableState>();
    if (scrollable != null && scrollable.position.axis == Axis.vertical) _scrollables.add(scrollable);
  }

  /// The deepest visible vertical scroll view in the body at [global].
  ScrollPosition? _scrollTargetAt(Offset global) {
    final body = _bodyKey.currentContext?.findRenderObject();
    if (body is! RenderBox || !body.hasSize) return null;
    final result = BoxHitTestResult();
    if (!body.hitTest(result, position: body.globalToLocal(global))) return null;
    final depth = <HitTestTarget, int>{};
    for (final (index, entry) in result.path.indexed) {
      depth.putIfAbsent(entry.target, () => index);
    }
    _scrollables.removeWhere((scrollable) => !scrollable.mounted);
    ScrollableState? target;
    var targetDepth = result.path.length;
    for (final scrollable in _scrollables) {
      final index = depth[scrollable.context.findRenderObject()];
      if (index != null && index < targetDepth && scrollable.position.axis == Axis.vertical) {
        target = scrollable;
        targetDepth = index;
      }
    }
    return target?.position;
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    final position = _scrollTargetAt(event.position);
    if (position == null || !position.hasPixels) return;
    final delta = axisDirectionIsReversed(position.axisDirection) ? -event.scrollDelta.dy : event.scrollDelta.dy;
    final target = (position.pixels + delta).clamp(position.minScrollExtent, position.maxScrollExtent);
    if (delta == 0 || target == position.pixels) return;
    // A control in the bar that scrolls registered first and keeps the event.
    GestureBinding.instance.pointerSignalResolver.register(event, (_) => position.pointerScroll(delta));
  }

  void _handleDragStart(DragStartDetails details) {
    final position = _scrollTargetAt(details.globalPosition);
    if (position == null) return;
    _drag = position.drag(details, () => _drag = null);
  }

  @override
  void dispose() {
    _drag?.cancel();
    super.dispose();
  }

  bool _handleScroll(ScrollNotification notification) {
    _track(notification.context);
    final metrics = notification.metrics;
    if (metrics.axis != Axis.vertical) return false;
    final coverage = (metrics.extentBefore / _revealDistance).clamp(0.0, 1.0);
    if (coverage != _coverage) setState(() => _coverage = coverage);
    return false;
  }

  void _handleChromeSize(Size size) {
    if (widget.extent != null || size.height == _measured) return;
    // Layout cannot rebuild the body; apply the new inset on the next frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && size.height != _measured) setState(() => _measured = size.height);
    });
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final extent = widget.extent ?? _measured ?? widget.estimatedExtent;
    return Stack(
      children: [
        MediaQuery(
          key: _bodyKey,
          data: media.copyWith(
            padding: media.padding.copyWith(top: extent),
            viewPadding: media.viewPadding.copyWith(top: extent),
          ),
          // Until the bar is measured the body would sit at the estimated
          // inset and then shift; keep it invisible for that one frame so it
          // first appears at its final position.
          child: Opacity(
            opacity: widget.extent != null || _measured != null ? 1 : 0,
            child: NotificationListener<ScrollMetricsNotification>(
              onNotification: _handleMetrics,
              child: NotificationListener<ScrollNotification>(onNotification: _handleScroll, child: widget.body),
            ),
          ),
        ),
        Positioned(
          left: 0,
          top: 0,
          right: 0,
          height: widget.extent,
          child: _SizeReporter(
            onSize: _handleChromeSize,
            child: Listener(
              onPointerSignal: _handlePointerSignal,
              child: RawGestureDetector(
                gestures: {
                  VerticalDragGestureRecognizer: GestureRecognizerFactoryWithHandlers<VerticalDragGestureRecognizer>(
                    () => VerticalDragGestureRecognizer(supportedDevices: ScrollConfiguration.of(context).dragDevices),
                    (recognizer) => recognizer
                      ..supportedDevices = ScrollConfiguration.of(context).dragDevices
                      ..onStart = _handleDragStart
                      ..onUpdate = ((details) => _drag?.update(details))
                      ..onEnd = ((details) => _drag?.end(details))
                      ..onCancel = (() => _drag?.cancel()),
                  ),
                },
                child: FrostPinnedChromeGlass(
                  opacity: _coverage,
                  columnMaxWidth: widget.columnMaxWidth,
                  // The value already follows the scroll position frame by frame.
                  animate: false,
                  child: widget.extent != null ? SizedBox.expand(child: widget.chrome) : widget.chrome,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SizeReporter extends SingleChildRenderObjectWidget {
  const _SizeReporter({required this.onSize, required super.child});

  final ValueChanged<Size> onSize;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderSizeReporter(onSize);

  @override
  void updateRenderObject(BuildContext context, _RenderSizeReporter renderObject) => renderObject.onSize = onSize;
}

class _RenderSizeReporter extends RenderProxyBox {
  _RenderSizeReporter(this.onSize);

  ValueChanged<Size> onSize;

  @override
  void performLayout() {
    super.performLayout();
    onSize(size);
  }
}

/// First sliver of a scroll view under [FrostPinnedChrome].
class FrostChromeSpacer extends StatelessWidget {
  const FrostChromeSpacer({super.key});

  @override
  Widget build(BuildContext context) => SliverToBoxAdapter(child: SizedBox(height: MediaQuery.paddingOf(context).top));
}

/// A page's refresh header preceded by [FrostChromeSpacer], for bodies that
/// take a single leading sliver.
Widget frostChromeSliverHeader(Widget? header) => SliverMainAxisGroup(slivers: [const FrostChromeSpacer(), ?header]);

/// Which outer corners a [FrostPinnedChromeGlass] rounds. Bars that are pinned
/// directly above one another share one outline: the upper one rounds its
/// top corners, the lower one its bottom corners.
enum FrostPinnedChromeCorners { all, top, bottom }

/// The glass behind a pinned bar, shown while content passes beneath it,
/// with the bar's own content as [child].
///
/// With the floating desktop sidebar the bar floats the same way: rounded,
/// and inset so it sits the sidebar's margin away from both the sidebar and
/// the window edge. The bar's content keeps its full-width layout but is
/// clipped to the glass shape, so hover highlights never spill past the
/// rounded corners; outside the shape the window background covers whatever
/// scrolls beneath, so no sliver of content shows around the panel.
/// Beside a flush sidebar the bar is flush too: a square band of glass over
/// the page's content column only, closed by a hairline below.
/// Compact layouts keep an edge-to-edge bar under the status bar.
class FrostPinnedChromeGlass extends StatelessWidget {
  const FrostPinnedChromeGlass({
    required this.opacity,
    this.child,
    this.animate = true,
    this.corners = FrostPinnedChromeCorners.all,
    this.columnMaxWidth,
    super.key,
  });

  final double opacity;
  final Widget? child;

  /// Ease [opacity] changes; pass false when it already follows scrolling.
  final bool animate;
  final FrostPinnedChromeCorners corners;

  /// The width of the content column beneath a flush bar. The glass covers
  /// only the column, centred like it, so a narrow column does not get a
  /// window-wide band. Null covers the full width.
  final double? columnMaxWidth;

  /// Gap between floating panels and between a panel and the window edge.
  static const floatingMargin = 8.0;

  /// The page already starts this far to the right of the sidebar.
  static const _sidebarGutter = 4.0;

  static const _insets = EdgeInsetsDirectional.only(start: floatingMargin - _sidebarGutter, end: floatingMargin);

  /// How far the glass sits inside the bar's edges: the floating margins on
  /// desktop, none on compact edge-to-edge bars. Content anchored to the
  /// bar's ends (a back or action button, a title) adds this to its usual
  /// inset so it keeps the same distance from the glass edge as it would
  /// from a screen edge. Rows already on the content column need nothing.
  static EdgeInsetsDirectional insetsOf(BuildContext context) => _floats(context) ? _insets : EdgeInsetsDirectional.zero;

  static bool _floats(BuildContext context) =>
      FrostAutoScaffold.usesHorizontalLayoutOf(context) && (FrostShellNavigationScope.maybeOf(context)?.floatingChrome ?? true);

  BorderRadius get _radius {
    const radius = Radius.circular(FrostMetrics.groupRadius + 4);
    return switch (corners) {
      FrostPinnedChromeCorners.all => const BorderRadius.all(radius),
      FrostPinnedChromeCorners.top => const BorderRadius.vertical(top: radius),
      FrostPinnedChromeCorners.bottom => const BorderRadius.vertical(bottom: radius),
    };
  }

  @override
  Widget build(BuildContext context) {
    final floating = _floats(context);
    final Widget material;
    if (floating) {
      final shape = _InsetShape(insets: _insets.resolve(Directionality.of(context)), borderRadius: _radius);
      material = Stack(
        fit: StackFit.expand,
        children: [
          // Window background around the panel, so content scrolling under
          // the bar does not peek through the margins and corner cut-outs.
          ClipPath(clipper: shape.outside(), child: const FrostAmbientBackdrop()),
          Padding(
            padding: _insets,
            child: FrostSurface(
              role: FrostSurfaceRole.chrome,
              borderRadius: _radius,
              join: switch (corners) {
                FrostPinnedChromeCorners.all => FrostSurfaceJoin.none,
                FrostPinnedChromeCorners.top => FrostSurfaceJoin.below,
                FrostPinnedChromeCorners.bottom => FrostSurfaceJoin.above,
              },
              child: const SizedBox.expand(),
            ),
          ),
        ],
      );
      final layer = IgnorePointer(
        child: animate
            ? AnimatedOpacity(opacity: opacity, duration: FrostMotion.duration(context, FrostMotion.hover), child: material)
            : Opacity(opacity: opacity, child: material),
      );
      return Stack(
        fit: StackFit.passthrough,
        children: [
          Positioned.fill(child: layer),
          if (child case final child?) ClipPath(clipper: shape, child: child),
        ],
      );
    }
    const band = FrostSurface(
      role: FrostSurfaceRole.chrome,
      borderRadius: BorderRadius.zero,
      edge: FrostSurfaceEdge.none,
      elevated: false,
      child: SizedBox.expand(),
    );
    if (FrostAutoScaffold.usesHorizontalLayoutOf(context)) {
      // Flush beside a flush sidebar: the column's band, closed below by a
      // hairline unless another bar continues it.
      final line = FrostThemeTokens.of(context).line;
      final columnMaxWidth = this.columnMaxWidth;
      material = Align(
        alignment: FrostColumnPlacement.alignmentOf(context),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: columnMaxWidth == null ? double.infinity : FrostColumnPlacement.columnWidth(context, columnMaxWidth)),
          child: DecoratedBox(
            position: DecorationPosition.foreground,
            decoration: BoxDecoration(
              border: corners == FrostPinnedChromeCorners.top ? null : Border(bottom: BorderSide(color: line)),
            ),
            child: band,
          ),
        ),
      );
    } else {
      material = band;
    }
    final layer = IgnorePointer(
      child: animate
          ? AnimatedOpacity(opacity: opacity, duration: FrostMotion.duration(context, FrostMotion.hover), child: material)
          : Opacity(opacity: opacity, child: material),
    );
    return Stack(
      fit: StackFit.passthrough,
      children: [
        Positioned.fill(child: layer),
        ?child,
      ],
    );
  }
}

/// The floating glass shape: the bar's rect inset by [insets], rounded by
/// [borderRadius]. [outside] clips to everything in the bar except it.
class _InsetShape extends CustomClipper<Path> {
  const _InsetShape({required this.insets, required this.borderRadius, this.inverse = false});

  final EdgeInsets insets;
  final BorderRadius borderRadius;
  final bool inverse;

  _InsetShape outside() => _InsetShape(insets: insets, borderRadius: borderRadius, inverse: true);

  @override
  Path getClip(Size size) {
    final panel = Path()..addRRect(borderRadius.toRRect(insets.deflateRect(Offset.zero & size)));
    if (!inverse) return panel;
    return Path.combine(PathOperation.difference, Path()..addRect(Offset.zero & size), panel);
  }

  @override
  bool shouldReclip(_InsetShape oldClipper) => insets != oldClipper.insets || borderRadius != oldClipper.borderRadius || inverse != oldClipper.inverse;
}
