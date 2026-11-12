import 'package:flutter/widgets.dart';

import '../feedback/skeleton.dart';
import '../foundation/_media_contrast.dart';
import '../foundation/density.dart';
import '../foundation/metrics.dart';
import '../foundation/radius.dart';
import '../foundation/scope.dart';
import '../foundation/tokens.dart';
import '../foundation/typography.dart';
import '../lists/_selection_presentation.dart';
import '../motion/_user_selection_draw.dart';
import '../motion/spring.dart';
import '../overlays/_additional_menu_entries.dart';
import '../overlays/context_menu.dart';
import '../overlays/menu_entry.dart';
import '../primitives/_click_feedback.dart';
import '../primitives/_click_surface_visuals.dart';
import '../primitives/_measured_layout_builder.dart';
import '../primitives/_media_image_registry.dart';
import '../primitives/_media_selection.dart';
import '../primitives/_media_shape.dart';
import '../primitives/_on_media_chrome_scope.dart';
import '../primitives/click_surface.dart';
import '../primitives/media_frame.dart';
import '../primitives/presence.dart';
import '../primitives/status_glyph.dart';
import '../primitives/text.dart';
import '_cover_scrim.dart';

// Media overlays and the footer share an eight-pixel separation.
const _mediaInset = 8.0;
const _checkDiameter = 20.0;
const _checkOutlineWidth = 1.5;
const _checkIconSize = 16.0;
const _selectionHiddenScale = .92;

/// A media boundary with independent corner controls and an unscaled footer.
/// [media] owns image loading. Without [aspectRatio], its natural height wins.
class FrostMediaCard extends StatelessWidget {
  /// Pass an explicit ratio, or null only with a finite parent height.
  /// Missing runtime geometry throws FlutterError in debug; no shape is guessed.
  factory FrostMediaCard.skeleton({required double? aspectRatio, required String? footer}) => _SkeletonMediaCard(aspectRatio: aspectRatio, footerText: footer);
  const FrostMediaCard({
    required this.media,
    this.aspectRatio,
    this.topStart,
    this.topEnd,
    this.bottomStart,
    this.bottomEnd,
    this.footer,
    this.title,
    this.metadata,
    this.titleLines = 2,
    this.overlay,
    this.progress,
    this.onPressed,
    this.onOpenInBackground,
    this.onOpenInNewTab,
    this.selected,
    this.contextMenu = const [],
    this.semanticLabel,
    super.key,
  }) : assert(aspectRatio == null || (aspectRatio > 0 && aspectRatio < double.infinity)),
       assert(progress == null || progress > double.negativeInfinity && progress < double.infinity);

  static ({int columns, double width}) _columns(BuildContext context, double width) {
    const gap = 16.0;
    final minimum = FrostDensity.of(context).usesPointer ? FrostMetrics.gridExtent : 168.0;
    final columns = ((width + gap) / (minimum + gap)).floor().clamp(1, 8);
    return (columns: columns, width: (width - gap * (columns - 1)) / columns);
  }

  /// How many title lines a grid of cards laid out in [width] must reserve for
  /// [titles]: two only when a sibling title can actually wrap, otherwise one.
  /// Pass the result to both [gridDelegate] and each card's [titleLines].
  static int titleLinesFor(BuildContext context, double width, Iterable<String> titles) {
    final cardWidth = _columns(context, width).width;
    final style = FrostTypography.of(context).style(FrostTextRole.subheadline);
    final painter = TextPainter(textDirection: Directionality.of(context), textScaler: MediaQuery.textScalerOf(context), maxLines: 2);
    var lines = 1;
    for (final title in titles) {
      painter.text = TextSpan(text: title, style: style);
      painter.layout(maxWidth: cardWidth);
      if (painter.computeLineMetrics().length > 1) {
        lines = 2;
        break;
      }
    }
    painter.dispose();
    return lines;
  }

  /// A lazy media grid whose title and metadata geometry follow this card's
  /// defaults, including text scaling. Apps supply their own metadata content.
  /// [titleLines] and [metadata] size the footer: reserve two lines only when
  /// siblings can wrap (see [titleLinesFor]) and no metadata row when no card
  /// has one.
  static SliverGridDelegate gridDelegate(BuildContext context, double width, {int titleLines = 2, bool metadata = true}) {
    const gap = 16.0;
    final (:columns, width: cardWidth) = _columns(context, width);
    final type = FrostTypography.of(context);
    final scaler = MediaQuery.textScalerOf(context);
    final title = type.style(FrostTextRole.subheadline);
    final meta = type.style(FrostTextRole.footnote);
    return SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: columns,
      crossAxisSpacing: gap,
      mainAxisSpacing: 20,
      mainAxisExtent:
          cardWidth * 9 / 16 +
          8 +
          scaler.scale(title.fontSize!) * title.height! * titleLines +
          (metadata ? 6 + scaler.scale(meta.fontSize!) * meta.height! : 0),
    );
  }

  final Widget media;
  final double? aspectRatio;
  final Widget? topStart;
  final Widget? topEnd;
  final Widget? bottomStart;
  final Widget? bottomEnd;
  final Widget? footer;

  /// Standard media-card title; reserves [titleLines] lines at the current text scale.
  final String? title;

  /// Lines reserved for [title]. Keep two where a sibling title in the same grid
  /// can wrap; one lets a grid of short titles drop the empty second line.
  final int titleLines;

  /// App-owned metadata below the standard title. Use footer for other structures.
  final Widget? metadata;

  /// Noninteractive cover text. Frost owns the bottom gradient, white numeric
  /// typography and insets; artwork above the fade remains untouched.
  final Widget? overlay;

  /// Optional watched fraction, clamped to 0–1 along the cover's bottom edge.
  final double? progress;
  final VoidCallback? onPressed;
  final VoidCallback? onOpenInBackground;
  final VoidCallback? onOpenInNewTab;
  final bool? selected;
  final List<FrostMenuEntry> contextMenu;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final selection = FrostSelectionPresentation.of(context);
    final row = FrostCoverRowScope.of(context);
    final radius = row ? frostRowThumbnailRadius : frostCoverRadius;
    final titleStyle = FrostTypography.of(context).style(FrostTextRole.subheadline);
    final metaStyle = FrostTypography.of(context).style(FrostTextRole.footnote);
    final scaler = MediaQuery.textScalerOf(context);
    final content =
        footer ??
        (title == null
            ? null
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Fixed semantic line boxes match adjacent cards even when a
                  // font rounds its paragraph metrics up to a physical pixel.
                  SizedBox(
                    height: scaler.scale(titleStyle.fontSize!) * titleStyle.height! * titleLines,
                    child: Text(title!, style: titleStyle, maxLines: titleLines, overflow: TextOverflow.ellipsis),
                  ),
                  if (metadata != null) ...[
                    const SizedBox(height: 6),
                    DefaultTextStyle(
                      style: FrostTypography.of(context).style(FrostTextRole.footnote).copyWith(color: FrostThemeTokens.of(context).textTertiary),
                      child: SizedBox(
                        height: scaler.scale(metaStyle.fontSize!) * metaStyle.height!,
                        child: Align(alignment: AlignmentDirectional.centerStart, child: metadata!),
                      ),
                    ),
                  ],
                ],
              ));
    final selected = selection == null ? this.selected : (selection.active ? selection.selected : null);
    final VoidCallback? activate = selection == null ? onPressed : () => selection.activate(onPressed);
    return FrostMediaImageHost(
      builder: (context, images) => FrostUserSelectionDraw(
        selected: selected,
        trigger: selection?.drawTrigger,
        // Shared selection owns whether this was a single input or a bulk change.
        trackInput: selection == null,
        onActivate: activate,
        builder: (context, trigger, activate) {
          Widget picture = FrostClickSurfaceVisuals.unclipped(
            scalesOnPress: false,
            mediaImages: images,
            child: Semantics(
              container: true,
              button: activate != null,
              selected: selected,
              label: semanticLabel,
              child: FrostClickSurface(
                onTap: activate,
                onOpenInBackground: selection?.active == true ? null : onOpenInBackground,
                onOpenInNewTab: selection?.active == true ? null : onOpenInNewTab,
                onLongPress: selection?.longPress,
                feedback: FrostClickFeedback.surface,
                shape: FrostClickShape.rounded(FrostRadius.borderRadius(radius)),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: FrostMediaFrame(
                            aspectRatio: aspectRatio,
                            radius: radius,
                            child: Builder(
                              builder: (context) => FrostMediaInnerStroke(
                                enabled: false,
                                child: FrostMediaImageRegistryScope(
                                  registry: images,
                                  child: Stack(
                                    fit: StackFit.passthrough,
                                    children: [
                                      FrostInteractionScale(
                                        mediaImages: images,
                                        value: FrostClickSurface.hoveredOf(context) ? FrostMetrics.mediaHoverZoom : 1,
                                        child: media,
                                      ),
                                      if (overlay case final text?)
                                        Positioned.fill(
                                          child: IgnorePointer(
                                            child: LayoutBuilder(
                                              builder: (context, bounds) {
                                                final row = FrostCoverRowScope.of(context);
                                                final tokens = FrostThemeTokens.of(context);
                                                final ink = tokens.onMediaInk;
                                                return Align(
                                                  alignment: Alignment.bottomCenter,
                                                  child: CustomPaint(
                                                    painter: FrostCoverScrim(coverHeight: bounds.maxHeight, fraction: row ? .5 : .42, scrim: tokens.onMediaScrim, readable: frostOnMediaScrimOpacity(tokens, minimum: .5)),
                                                    child: Padding(
                                                      padding: row ? const EdgeInsets.fromLTRB(5, 0, 5, 4) : const EdgeInsets.fromLTRB(8, 0, 8, 6),
                                                      child: FrostOnMediaChromeScope(
                                                        child: DefaultTextStyle(
                                                          style: FrostTypography.of(context)
                                                              .style(FrostTextRole.caption, numeric: true)
                                                              .copyWith(
                                                                fontSize: row ? 10.5 : 11.5,
                                                                fontWeight: FontWeight.w500,
                                                                height: 1.45,
                                                                letterSpacing: 0,
                                                                color: ink,
                                                              ),
                                                          child: IconTheme(
                                                            data: IconThemeData(color: ink, size: 13),
                                                            child: SizedBox(width: double.infinity, child: text),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                        ),
                                      if (progress case final fraction?)
                                        PositionedDirectional(
                                          start: 0,
                                          end: 0,
                                          bottom: 0,
                                          child: IgnorePointer(
                                            child: Semantics(
                                              value: '${(fraction.clamp(0.0, 1.0) * 100).round()}%',
                                              child: SizedBox(
                                                height: 3,
                                                child: Stack(
                                                  children: [
                                                    Positioned.fill(child: ColoredBox(color: _mediaTrackColor(FrostThemeTokens.of(context).onMediaInk))),
                                                    FractionallySizedBox(
                                                      widthFactor: fraction.clamp(0.0, 1.0),
                                                      heightFactor: 1,
                                                      child: ColoredBox(color: FrostThemeTokens.of(context).accent),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (topStart case final child?) PositionedDirectional(top: 6, start: 6, child: FrostOnMediaChromeScope(child: child)),
                        PositionedDirectional(
                          top: _mediaInset,
                          end: _mediaInset,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              FrostPresence(
                                visible: selected != null,
                                child: Padding(
                                  padding: EdgeInsetsDirectional.only(end: topEnd == null ? 0 : _mediaInset),
                                  child: _SelectionCircle(selected: selected == true, drawTrigger: trigger),
                                ),
                              ),
                              ?topEnd,
                            ],
                          ),
                        ),
                        if (bottomStart case final child?) PositionedDirectional(bottom: _mediaInset, start: _mediaInset, child: child),
                        if (bottomEnd case final child?) PositionedDirectional(bottom: _mediaInset, end: _mediaInset, child: child),
                        FrostMediaSelectionRing(selected: selected == true, radius: radius, width: frostMediaCardRingWidth),
                      ],
                    ),
                    if (content != null) ...[
                      const SizedBox(height: _mediaInset),
                      // Hover shows on the image alone; the text below keeps its ink.
                      DefaultTextStyle.merge(
                        style: TextStyle(color: FrostThemeTokens.of(context).textPrimary),
                        child: content,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
          final entries = [...contextMenu, ...FrostAdditionalMenuEntries.of(context)];
          if (entries.isNotEmpty) picture = FrostContextMenuRegion(entries: entries, child: picture);
          return picture;
        },
      ),
    );
  }
}

class _SelectionCircle extends StatelessWidget {
  const _SelectionCircle({required this.selected, required this.drawTrigger});
  final bool selected;
  final Object? drawTrigger;
  @override
  Widget build(BuildContext context) {
    final tokens = FrostThemeTokens.of(context);
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: _checkDiameter,
        child: Stack(
          fit: StackFit.expand,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(end: selected ? 1 : 0),
              duration: FrostMotion.duration(context, FrostMotion.hover),
              builder: (context, opacity, child) => Stack(
                fit: StackFit.expand,
                children: [
                  // Retiring the outline prevents its white antialiased edge
                  // from bleeding through the selected fill at the same bounds.
                  CustomPaint(
                    painter: FrostMediaSelectionCirclePainter(fill: tokens.onMediaScrim, outline: tokens.onMediaInk, opacity: 1 - opacity),
                  ),
                  Opacity(
                    opacity: opacity,
                    child: FrostSpringBuilder(
                      value: selected ? 1 : _selectionHiddenScale,
                      spring: FrostMotion.snappy,
                      builder: (_, scale, child) => Transform.scale(scale: scale, child: child),
                      child: child,
                    ),
                  ),
                ],
              ),
              child: CustomPaint(
                painter: FrostMediaSelectionCirclePainter(fill: tokens.actionFill),
                child: Center(
                  child: _MediaCheck(selected: selected, trigger: drawTrigger, color: tokens.onAction),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Internal vector paint; never a clipped bitmap or a package export.
class FrostMediaSelectionCirclePainter extends CustomPainter {
  const FrostMediaSelectionCirclePainter({required this.fill, this.outline, this.opacity = 1});
  final Color fill;
  final Color? outline;
  final double opacity;
  @override
  void paint(Canvas canvas, Size size) {
    if (opacity <= 0) return;
    final radius = size.shortestSide / 2, center = size.center(Offset.zero);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = fill.withValues(alpha: fill.a * opacity)
        ..isAntiAlias = true,
    );
    if (outline case final color?) {
      canvas.drawCircle(
        center,
        radius - _checkOutlineWidth / 2,
        Paint()
          ..color = color.withValues(alpha: color.a * opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = _checkOutlineWidth
          ..isAntiAlias = true,
      );
    }
  }

  @override
  bool shouldRepaint(FrostMediaSelectionCirclePainter oldDelegate) =>
      fill != oldDelegate.fill || outline != oldDelegate.outline || opacity != oldDelegate.opacity;
}

class _MediaCheck extends StatefulWidget {
  const _MediaCheck({required this.selected, required this.trigger, required this.color});
  final bool selected;
  final Object? trigger;
  final Color color;
  @override
  State<_MediaCheck> createState() => _MediaCheckState();
}

class _MediaCheckState extends State<_MediaCheck> {
  bool _draw = false;
  @override
  void initState() {
    super.initState();
    _draw = widget.selected && frostFreshUserSelection(widget.trigger);
  }

  @override
  void didUpdateWidget(_MediaCheck oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected != oldWidget.selected) _draw = widget.selected && widget.trigger != null && widget.trigger != oldWidget.trigger;
  }

  @override
  Widget build(BuildContext context) => FrostStatusGlyphAnimation(
    kind: FrostStatusGlyphKind.success,
    size: _checkIconSize,
    color: widget.color,
    visible: true,
    replay: widget.selected ? widget.trigger : null,
    animateChanges: _draw,
    drawOnMount: _draw,
    duration: frostSelectionDrawDuration,
  );
}

class _SkeletonMediaCard extends FrostMediaCard {
  _SkeletonMediaCard({required super.aspectRatio, required String? footerText})
    : _footerText = footerText,
      super(
        media: const SizedBox.expand(),
        footer: footerText == null ? null : FrostText(footerText, role: FrostTextRole.subheadline, tabular: true, maxLines: 1),
      );
  final String? _footerText;

  double _heightAt(BuildContext context, double width) {
    if (footer == null) return width / (aspectRatio ?? 1);
    final title = TextPainter(
      text: TextSpan(text: _footerText, style: FrostTypography.of(context).style(FrostTextRole.subheadline, tabular: true)),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout(maxWidth: width);
    final height = title.height;
    title.dispose();
    return width / (aspectRatio ?? 1) + _mediaInset + height;
  }

  @override
  Widget build(BuildContext context) => FrostMeasuredLayoutBuilder(
    naturalSize: Size(FrostMetrics.gridExtent, _heightAt(context, FrostMetrics.gridExtent)),
    heightForWidth: (width) => _heightAt(context, width),
    builder: (context, constraints) {
      assert(() {
        if (aspectRatio == null && !constraints.hasBoundedHeight) {
          throw FlutterError('FrostMediaCard.skeleton requires aspectRatio when the parent height is unbounded.');
        }
        return true;
      }());
      final title = TextPainter(
        text: TextSpan(text: _footerText, style: FrostTypography.of(context).style(FrostTextRole.subheadline, tabular: true)),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
        maxLines: 1,
      )..layout(maxWidth: constraints.maxWidth);
      final footerHeight = footer == null ? 0.0 : _mediaInset + title.height;
      title.dispose();
      return Semantics(
        label: FrostScope.labelsOf(context).loading,
        excludeSemantics: true,
        child: FrostMediaCard(
          aspectRatio: aspectRatio,
          media: SizedBox(
            height: aspectRatio == null ? (constraints.maxHeight - footerHeight).clamp(0.0, double.infinity) : null,
            // The shading picture must be recorded inside the media clip,
            // exactly as for the standalone frame. Wrapping the whole card
            // lets skeletonizer's picture layer escape the rounded boundary.
            child: FrostMediaFrame.skeleton(aspectRatio: null),
          ),
          footer: footer?.frostSkeleton(true),
        ),
      );
    },
  );
}

/// The unfilled part of a card's progress line: the media ink at 40%.
Color _mediaTrackColor(Color ink) => ink.withValues(alpha: ink.a * 0x66 / 255);
