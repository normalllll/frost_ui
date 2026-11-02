import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../feedback/skeleton.dart';
import '../foundation/metrics.dart';
import '../foundation/radius.dart';
import '../foundation/scope.dart';
import '../foundation/sizes.dart';
import '../foundation/tokens.dart';
import '../media/_hero_radius.dart';
import '../media/media_image.dart';
import '../surface/_window_background.dart';
import '_measured_layout_builder.dart';
import '_media_image_registry.dart';
import '_media_shape.dart';
import 'icon.dart';

/// A media boundary. Image loading belongs here only in provider mode.
class FrostMediaFrame extends StatelessWidget {
  /// Matches the media boundary's parent constraints when no ratio is given.
  /// Pass an explicit ratio, or null only with a finite parent height.
  /// Missing runtime geometry throws FlutterError in debug; no shape is guessed.
  factory FrostMediaFrame.skeleton({required double? aspectRatio, double radius = FrostRadius.lg}) => _SkeletonMediaFrame(aspectRatio, radius);
  const FrostMediaFrame({
    this.child,
    this.image,
    this.radius = FrostRadius.lg,
    this.aspectRatio,
    this.fit = BoxFit.cover,
    this.placeholderBuilder,
    this.errorBuilder,
    this.semanticLabel,
    super.key,
  }) : assert((child == null) != (image == null), 'Provide exactly one of child and image.'),
       assert(child == null || (placeholderBuilder == null && errorBuilder == null), 'Child mode owns its loading and error states.');

  /// Child mode preserves descendant semantics, including playback and retry
  /// controls, unless [semanticLabel] explicitly replaces the whole subtree's
  /// description. Image-provider mode supplies only the optional image label.
  final Widget? child;
  final ImageProvider? image;
  final double radius;
  final double? aspectRatio;
  final BoxFit fit;
  final Widget Function(BuildContext context, double? progress)? placeholderBuilder;
  final Widget Function(BuildContext context, Object error)? errorBuilder;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final tokens = FrostThemeTokens.of(context);
    final circle = FrostMediaCircle.of(context);
    final provider = image;
    // A hero inside the frame flies from, or to, the frame's corners.
    final hosted = child == null ? null : FrostMediaHeroRadius(radius: FrostRadius.borderRadius(radius), child: child!);
    Widget content = hosted ?? _ProviderImage(image: provider!, fit: fit, placeholderBuilder: placeholderBuilder, errorBuilder: errorBuilder);
    // One enclosing frame owns the media stroke, including a nested loading
    // placeholder. A card can already own it outside its hover transform.
    content = FrostMediaCircle(enabled: false, child: FrostMediaInnerStroke(enabled: false, child: content));
    final corners = FrostRadius.borderRadius(radius);
    content = circle
        ? ClipOval(clipBehavior: Clip.antiAlias, child: content)
        : FrostScope.configOf(context).continuousCorners
        ? ClipRSuperellipse(borderRadius: corners, clipBehavior: Clip.antiAlias, child: content)
        : ClipRRect(borderRadius: corners, clipBehavior: Clip.antiAlias, child: content);
    // Only the media is clipped. The stroke is painted after the clip as one
    // inset line, so the antialiased clip edge never cuts it, and only once an
    // image has produced a frame, never over a skeleton or placeholder.
    if (FrostMediaInnerStroke.of(context)) {
      content = _MediaInnerStroke(
        shape: circle ? const CircleBorder() : FrostRadius.shape(context, radius) as OutlinedBorder,
        color: tokens.mediaInnerStroke,
        width: 1 / MediaQuery.devicePixelRatioOf(context),
        textDirection: Directionality.of(context),
        child: content,
      );
    }
    if (aspectRatio != null) content = AspectRatio(aspectRatio: aspectRatio!, child: content);
    // Chrome over opaque media falls back to the black/white-safe fill.
    content = FrostAmbientMediaRegistration(child: content);
    final label = semanticLabel;
    if (provider == null) {
      return label == null
          ? content
          : Semantics(
              image: true,
              label: label,
              child: ExcludeSemantics(child: content),
            );
    }
    return label == null
        ? ExcludeSemantics(child: content)
        : Semantics(
            image: true,
            label: label,
            child: ExcludeSemantics(child: content),
          );
  }
}

class _SkeletonMediaFrame extends FrostMediaFrame {
  const _SkeletonMediaFrame(double? aspectRatio, double radius) : super(aspectRatio: aspectRatio, radius: radius, child: const SizedBox.expand());
  @override
  Widget build(BuildContext context) => FrostMeasuredLayoutBuilder(
    naturalSize: Size(FrostMetrics.gridExtent, FrostMetrics.gridExtent / (aspectRatio ?? 1)),
    heightForWidth: (width) => width / (aspectRatio ?? 1),
    builder: (context, constraints) {
      assert(() {
        if (aspectRatio == null && !constraints.hasBoundedHeight) {
          throw FlutterError('FrostMediaFrame.skeleton requires aspectRatio when the parent height is unbounded.');
        }
        return true;
      }());
      return FrostMediaFrame(
        aspectRatio: aspectRatio,
        radius: radius,
        semanticLabel: FrostScope.labelsOf(context).loading,
        // Clip the shading layer at the real media boundary. A leaf annotation
        // outside this clip can record a picture that escapes its canvas clip.
        child: FrostMediaImagePending(
          child: FrostSkeletonLeaf(
            child: ColoredBox(color: FrostThemeTokens.of(context).fill, child: const SizedBox.expand()),
          ).frostSkeleton(true),
        ),
      );
    },
  );
}

/// Paints the media's inner stroke above its clip unless an enclosed image has
/// not produced a frame (loading, failed or skeleton), at the opacity the
/// fading image has reached. The registry drives repaint only, so a late
/// arrival never rebuilds ancestors.
class _MediaInnerStroke extends StatefulWidget {
  const _MediaInnerStroke({required this.shape, required this.color, required this.width, required this.textDirection, required this.child});
  final OutlinedBorder shape;
  final Color color;
  final double width;
  final TextDirection textDirection;
  final Widget child;
  @override
  State<_MediaInnerStroke> createState() => _MediaInnerStrokeState();
}

class _MediaInnerStrokeState extends State<_MediaInnerStroke> {
  final _images = FrostMediaImageRegistry();

  @override
  void dispose() {
    _images.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FrostMediaImageRegistryScope(
    registry: _images,
    child: CustomPaint(foregroundPainter: _InnerStrokePainter(_images, widget.shape, widget.color, widget.width, widget.textDirection), child: widget.child),
  );
}

class _InnerStrokePainter extends CustomPainter {
  _InnerStrokePainter(this.images, this.shape, this.color, this.width, this.textDirection) : super(repaint: images);
  final FrostMediaImageRegistry images;
  final OutlinedBorder shape;
  final Color color;
  final double width;
  final TextDirection textDirection;
  @override
  void paint(Canvas canvas, Size size) {
    if (images.hasPending) return;
    shape
        .copyWith(
          side: BorderSide(
            color: color.withValues(alpha: color.a * images.reveal),
            width: width,
            strokeAlign: BorderSide.strokeAlignInside,
          ),
        )
        .paint(canvas, Offset.zero & size, textDirection: textDirection);
  }

  @override
  bool shouldRepaint(_InnerStrokePainter oldDelegate) =>
      images != oldDelegate.images ||
      shape != oldDelegate.shape ||
      color != oldDelegate.color ||
      width != oldDelegate.width ||
      textDirection != oldDelegate.textDirection;
}

/// An image loaded from a provider. Whatever stood in its place, the placeholder
/// or the image it replaces, stays until the new image has faded in over it.
class _ProviderImage extends StatefulWidget {
  const _ProviderImage({required this.image, required this.fit, required this.placeholderBuilder, required this.errorBuilder});
  final ImageProvider image;
  final BoxFit fit;
  final Widget Function(BuildContext context, double? progress)? placeholderBuilder;
  final Widget Function(BuildContext context, Object error)? errorBuilder;
  @override
  State<_ProviderImage> createState() => _ProviderImageState();
}

class _ProviderImageState extends State<_ProviderImage> {
  // Written from the image's builders, which never need a rebuild of their own.
  ImageProvider? _outgoing;
  bool _hasFrame = false;

  // The placeholder keeps its state when it moves under the fading image.
  final _standKey = GlobalKey();

  @override
  void didUpdateWidget(_ProviderImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.image == oldWidget.image) return;
    if (_hasFrame) _outgoing = oldWidget.image;
    _hasFrame = false;
  }

  Widget _stand(BuildContext context, double? progress) => KeyedSubtree(
    key: _standKey,
    child: widget.placeholderBuilder?.call(context, progress) ?? ColoredBox(color: FrostThemeTokens.of(context).fillSubtle, child: const SizedBox.expand()),
  );

  // Placeholders and errors stand in for an image that has no frame, so the
  // frame draws no stroke around them.
  Widget _placeholder(BuildContext context, double? progress) => FrostMediaImagePending(child: _stand(context, progress));

  Widget _outgoingImage(ImageProvider image) => FrostMediaImage(
    child: Image(image: image, fit: widget.fit, excludeFromSemantics: true),
  );

  @override
  Widget build(BuildContext context) => Image(
    image: widget.image,
    fit: widget.fit,
    excludeFromSemantics: true,
    frameBuilder: (context, imageChild, frame, synchronous) {
      final outgoing = _outgoing;
      if (frame == null) return outgoing == null ? _placeholder(context, null) : _outgoingImage(outgoing);
      _hasFrame = true;
      // A cached frame is already present; remounting a lazy row must not
      // replay loading feedback. Only an arrival that changes the picture fades.
      final displayed = FrostMediaImage(child: imageChild);
      if ((synchronous && outgoing == null) || MediaQuery.disableAnimationsOf(context)) {
        _outgoing = null;
        return displayed;
      }
      return _ImageFadeIn(
        key: ValueKey<ImageProvider>(widget.image),
        // The stroke already stands around an outgoing image; it does not dip.
        tracksReveal: outgoing == null,
        underlay: outgoing == null ? _stand(context, 1) : _outgoingImage(outgoing),
        onEnd: () => _outgoing = null,
        child: displayed,
      );
    },
    loadingBuilder: (context, imageChild, progress) {
      if (progress == null || _outgoing != null) return imageChild;
      final total = progress.expectedTotalBytes;
      return _placeholder(context, total == null || total == 0 ? null : (progress.cumulativeBytesLoaded / total).clamp(0.0, 1.0));
    },
    errorBuilder: (context, error, stack) {
      _outgoing = null;
      final tokens = FrostThemeTokens.of(context);
      return FrostMediaImagePending(
        child:
            widget.errorBuilder?.call(context, error) ??
            ColoredBox(
              color: tokens.fillSubtle,
              child: Center(
                child: FrostIcon(FrostIconSet.of(context).imageError, size: FrostControlSize.regular.iconSize, color: tokens.textTertiary),
              ),
            ),
      );
    },
  );
}

/// Fades a newly arrived image in over [underlay] and tells the enclosing
/// registries how far it has got, so the media stroke does not outshine a still
/// transparent picture. The underlay stays opaque until the image is, so an
/// opaque image never lets the backdrop through; it then fades out over a
/// further quarter of the fade, which only a transparent image shows.
class _ImageFadeIn extends StatefulWidget {
  const _ImageFadeIn({required this.tracksReveal, required this.underlay, required this.onEnd, required this.child, super.key});
  final bool tracksReveal;
  final Widget underlay;
  final VoidCallback onEnd;
  final Widget child;
  @override
  State<_ImageFadeIn> createState() => _ImageFadeInState();
}

// The underlay's fade after the image's, as a share of the image's.
const _underlayFade = .25;

class _ImageFadeInState extends State<_ImageFadeIn> {
  FrostMediaImageRegistry? _registry;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = FrostMediaImageRegistryScope.maybeOf(context);
    if (identical(next, _registry)) return;
    _registry?.clearReveal(this);
    _registry = next;
  }

  @override
  void dispose() {
    _registry?.clearReveal(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1 + _underlayFade),
    duration: FrostMotion.imageFade * (1 + _underlayFade),
    onEnd: widget.onEnd,
    builder: (context, progress, child) {
      final opacity = math.min(1.0, progress);
      final underlay = progress <= 1 ? 1.0 : (1 + _underlayFade - progress) / _underlayFade;
      _registry?.setReveal(this, widget.tracksReveal ? opacity : 1);
      return Stack(
        fit: StackFit.passthrough,
        alignment: Alignment.topLeft,
        children: [
          if (underlay > 0)
            Positioned.fill(
              child: FadeTransition(opacity: AlwaysStoppedAnimation(underlay), child: widget.underlay),
            ),
          Opacity(opacity: opacity, child: child),
        ],
      );
    },
    child: widget.child,
  );
}
