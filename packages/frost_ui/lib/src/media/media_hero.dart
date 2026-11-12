import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../foundation/metrics.dart';
import '../foundation/scope.dart';
import '../motion/_page_curve.dart';
import '_hero_radius.dart';
import 'media_stage.dart';

/// Pairs a card instance with the detail it opened, using object identity.
/// Do not derive tags from a work ID: the same work can occupy several cards.
final class FrostMediaHeroTag {
  FrostMediaHeroTag({required this.image, required double aspectRatio}) : assert(aspectRatio > 0 && aspectRatio < double.infinity), _aspectRatio = aspectRatio;

  /// The card's already decoded preview, used for both push and return flights.
  /// The tag keeps this provider for its lifetime; it owns no decoded image.
  final ImageProvider image;
  double _aspectRatio;
  double get aspectRatio => _aspectRatio;

  /// The rect Hero placed this tag's shuttle at, recorded by [_FlightRectTween].
  final _flightRect = ValueNotifier<Rect?>(null);
}

/// Publishes each rect Hero evaluates. Hero keeps one shuttle when a push
/// interrupts a return flight, and only this tween follows that diversion.
class _FlightRectTween extends RectTween {
  _FlightRectTween(this._rect, {super.begin, super.end});
  final ValueNotifier<Rect?> _rect;
  @override
  Rect? transform(double t) => _rect.value = super.transform(t);
}

/// Holds one tag while this card represents the same [identity].
/// Source geometry can update without changing the identity of an open flight.
class FrostMediaHeroSource extends StatefulWidget {
  const FrostMediaHeroSource({required this.image, required this.builder, required this.aspectRatio, this.identity, super.key})
    : assert(aspectRatio > 0 && aspectRatio < double.infinity);
  final ImageProvider image;
  final Widget Function(BuildContext context, FrostMediaHeroTag tag) builder;
  final double aspectRatio;
  final Object? identity;
  @override
  State<FrostMediaHeroSource> createState() => _FrostMediaHeroSourceState();
}

class _FrostMediaHeroSourceState extends State<FrostMediaHeroSource> {
  late FrostMediaHeroTag _tag = _newTag();
  FrostMediaHeroTag _newTag() => FrostMediaHeroTag(image: widget.image, aspectRatio: widget.aspectRatio);
  @override
  void didUpdateWidget(FrostMediaHeroSource oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.identity != widget.identity) {
      _tag = _newTag();
    } else {
      _tag._aspectRatio = widget.aspectRatio;
    }
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _tag);
}

/// Places the same tag around the card and its detail stage.
/// Resting content can include loading and interaction widgets. Flights create
/// one plain Image from the tag preview; they never mount the source child.
/// Network loading and decoded-image ownership remain with the app.
/// Use [HeroMode] outside this widget when a stage switches to another image.
///
/// The corners come from the media area around it: the enclosing media card's
/// frame, a detail stage, or the media radius. The flight runs from the card's
/// corners to the stage's.
class FrostMediaHero extends StatefulWidget {
  const FrostMediaHero({required this.tag, required this.child, this.fit = BoxFit.cover, super.key});
  final FrostMediaHeroTag tag;
  final Widget child;
  final BoxFit fit;
  @override
  State<FrostMediaHero> createState() => _FrostMediaHeroState();
}

class _FrostMediaHeroState extends State<FrostMediaHero> with SingleTickerProviderStateMixin {
  late final _fade = AnimationController(vsync: this, duration: FrostMotion.reducedFade, value: 1, animationBehavior: AnimationBehavior.preserve);
  bool _initialized = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      final route = ModalRoute.of(context);
      if (MediaQuery.disableAnimationsOf(context) && route != null && !route.isFirst) _fade.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    return HeroMode(
      enabled: !reduced,
      child: Hero(
        tag: widget.tag,
        // Shared media routes keep native route progress continuous at commit.
        transitionOnUserGestures: true,
        // Rect and canvas interpolation share Flutter's non-overshooting curve.
        curve: frostPageCurve,
        reverseCurve: frostPageReverseCurve,
        createRectTween: (begin, end) => _FlightRectTween(widget.tag._flightRect, begin: begin, end: end),
        flightShuttleBuilder: _flight,
        child: FadeTransition(
          opacity: reduced ? _fade : const AlwaysStoppedAnimation(1),
          child: _HeroFrame(
            radius: FrostMediaHeroRadius.of(context),
            ratio: FrostMediaStageGeometry.maybeOf(context) ?? widget.tag.aspectRatio,
            fit: widget.fit,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

Widget _flight(BuildContext context, Animation<double> animation, HeroFlightDirection direction, BuildContext fromContext, BuildContext toContext) {
  final from = fromContext.findAncestorWidgetOfExactType<FrostMediaHero>()!;
  final to = toContext.findAncestorWidgetOfExactType<FrostMediaHero>()!;
  final (source, destination) = direction == HeroFlightDirection.push ? (from, to) : (to, from);
  // Animation is 0 at the card and 1 at the detail, including on pop.
  final ratio = FrostMediaStageGeometry.maybeOf(direction == HeroFlightDirection.push ? toContext : fromContext) ?? source.tag.aspectRatio;
  final sourceRadius = FrostMediaHeroRadius.of(direction == HeroFlightDirection.push ? fromContext : toContext, listen: false);
  final targetRadius = FrostMediaHeroRadius.of(direction == HeroFlightDirection.push ? toContext : fromContext, listen: false);
  Size canvas(BuildContext endpoint, BoxFit fit) {
    final box = endpoint.findRenderObject()! as RenderBox;
    final fitted = applyBoxFit(fit, Size(ratio, 1), box.size);
    return Size(ratio * fitted.destination.width / fitted.source.width, fitted.destination.height / fitted.source.height);
  }

  // Snapshot endpoint geometry once. Flight frames only interpolate canvas size
  // and radius between them, without querying render trees or fitting again.
  final cardSize = ((direction == HeroFlightDirection.push ? fromContext : toContext).findRenderObject()! as RenderBox).size;
  final detailSize = ((direction == HeroFlightDirection.push ? toContext : fromContext).findRenderObject()! as RenderBox).size;
  final cardCanvas = canvas(direction == HeroFlightDirection.push ? fromContext : toContext, source.fit);
  final detailCanvas = canvas(direction == HeroFlightDirection.push ? toContext : fromContext, destination.fit);
  final flightRect = source.tag._flightRect;
  final span = Offset(detailSize.width - cardSize.width, detailSize.height - cardSize.height);
  return ListenableBuilder(
    // The route's animation stops describing the flight once a push diverts it,
    // so the frame comes from the rect Hero placed and the rest follows that.
    listenable: Listenable.merge([animation, flightRect]),
    child: Image(image: source.tag.image, fit: BoxFit.fill),
    builder: (context, child) {
      final frame = flightRect.value?.size ?? Size.lerp(cardSize, detailSize, animation.value)!;
      final progress = span == Offset.zero
          ? animation.value
          : (((frame.width - cardSize.width) * span.dx + (frame.height - cardSize.height) * span.dy) / span.distanceSquared).clamp(0.0, 1.0);
      return _FlightFrame(
        frame: frame,
        radius: BorderRadius.lerp(sourceRadius, targetRadius, progress)!,
        canvas: Size.lerp(cardCanvas, detailCanvas, progress)!,
        child: child!,
      );
    },
  );
}

class _FlightFrame extends StatelessWidget {
  const _FlightFrame({required this.frame, required this.radius, required this.canvas, required this.child});
  final Size frame;
  final BorderRadius radius;
  final Size canvas;
  final Widget child;
  @override
  Widget build(BuildContext context) => OverflowBox(
    // Hero's Positioned uses the Navigator size captured at take-off. A shell
    // bottom bar can resize that Overlay during pop; retain the flight's own
    // interpolated rectangle instead of cropping its canvas to the new height.
    alignment: Alignment.topLeft,
    minWidth: frame.width,
    maxWidth: frame.width,
    minHeight: frame.height,
    maxHeight: frame.height,
    child: ClipRRect(
      borderRadius: radius,
      child: OverflowBox(
        alignment: Alignment.center,
        minWidth: canvas.width,
        maxWidth: canvas.width,
        minHeight: canvas.height,
        maxHeight: canvas.height,
        child: child,
      ),
    ),
  );
}

class _HeroFrame extends StatelessWidget {
  const _HeroFrame({required this.radius, required this.ratio, required this.fit, required this.child});
  final BorderRadius radius;
  final double ratio;
  final BoxFit fit;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final content = _HeroCanvas(ratio: ratio, fit: fit, child: child);
    return FrostScope.configOf(context).continuousCorners
        ? ClipRSuperellipse(borderRadius: radius, clipBehavior: Clip.antiAlias, child: content)
        : ClipRRect(borderRadius: radius, clipBehavior: Clip.antiAlias, child: content);
  }
}

/// Fills a bounded frame and lays its child out at the image's fitted canvas,
/// centred and overflowing where the fit crops. Unbounded, the child sizes it.
class _HeroCanvas extends SingleChildRenderObjectWidget {
  const _HeroCanvas({required this.ratio, required this.fit, required super.child});
  final double ratio;
  final BoxFit fit;
  @override
  RenderObject createRenderObject(BuildContext context) => _RenderHeroCanvas(ratio, fit);
  @override
  void updateRenderObject(BuildContext context, _RenderHeroCanvas renderObject) => renderObject.update(ratio, fit);
}

class _RenderHeroCanvas extends RenderShiftedBox {
  _RenderHeroCanvas(this._ratio, this._fit) : super(null);
  double _ratio;
  BoxFit _fit;
  void update(double ratio, BoxFit fit) {
    if (ratio == _ratio && fit == _fit) return;
    _ratio = ratio;
    _fit = fit;
    markNeedsLayout();
  }

  @override
  void performLayout() {
    final child = this.child!;
    final data = child.parentData! as BoxParentData;
    if (!constraints.hasBoundedWidth || !constraints.hasBoundedHeight) {
      child.layout(constraints, parentUsesSize: true);
      size = child.size;
      data.offset = Offset.zero;
      return;
    }
    size = constraints.biggest;
    final image = Size(_ratio, 1);
    final fitted = applyBoxFit(_fit, image, size);
    final canvas = fitted.source.isEmpty
        ? Size.zero
        : Size(image.width * fitted.destination.width / fitted.source.width, image.height * fitted.destination.height / fitted.source.height);
    child.layout(BoxConstraints.tight(canvas), parentUsesSize: true);
    data.offset = Alignment.center.alongOffset(size - canvas as Offset);
  }
}
