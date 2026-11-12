import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../feedback/_skeleton_geometry.dart';
import '../feedback/activity_indicator.dart';
import '../feedback/loading_gate.dart';
import '../foundation/_ambient_material.dart';
import '../foundation/_control_dimming.dart';
import '../foundation/_focus_modality.dart';
import '../foundation/_premultiplied_lerp.dart';
import '../foundation/color_math.dart';
import '../foundation/control_scope.dart';
import '../foundation/density.dart';
import '../foundation/feedback.dart';
import '../foundation/metrics.dart';
import '../foundation/radius.dart';
import '../foundation/sizes.dart';
import '../foundation/tokens.dart';
import '../foundation/typography.dart';
import '../primitives/_click_feedback.dart';
import '../primitives/_click_surface_visuals.dart';
import '../primitives/_focus_outline.dart';
import '../primitives/_on_media_chrome_scope.dart';
import '../primitives/click_surface.dart';
import '../primitives/icon.dart';
import '../primitives/keyline.dart';
import '../primitives/surface.dart';
import '../primitives/text.dart';
import '../surface/_window_background.dart';
import '_button_types.dart';
import '_field_chrome.dart';
import '_field_options.dart';

// The building blocks every button-like control is composed from. None of
// them is exported by frost_ui.dart:
// - geometry: [FrostButtonMetrics] resolves the sizes, [FrostButtonHitArea]
//   lays out the hit target and the edge bleed around the frame;
// - [FrostButtonFrame]: fill, border, shape, click feedback and focus, with
//   one paint path per kind ([FrostActionFrameStyle], [FrostFieldFrameStyle],
//   [FrostTagFrameStyle]); it paints the [FrostButtonInteraction] state that
//   the composing State owns;
// - [FrostActionStateLayer]: spinner and result glyph over the content;
// - [FrostButtonContent]: icon, label and chevron layout, truncation and
//   wrapping.

// Public text buttons use these insets, independently of toolbar edge geometry.
const _smallTextInset = 8.0;
const _compactTextInset = 10.0;
const _regularTextInset = 12.0;
const _largeTextInset = 16.0;

/// Internal geometry shared by section edges and the button blocks.
double frostButtonTextInset(FrostControlSize size) => switch (size) {
  FrostControlSize.small => _smallTextInset,
  FrostControlSize.compact => _compactTextInset,
  FrostControlSize.regular => _regularTextInset,
  FrostControlSize.large => _largeTextInset,
};
// Compact icon/label pairs are closer; chevrons always have the inline gap.
const _compactIconGap = 4.0;
const _regularIconGap = 6.0;
const _chevronGap = 4.0;
const _disabledOpacity = .38;

/// Library-only geometry override. It carries no paint or interaction policy.
class FrostButtonGeometry {
  const FrostButtonGeometry({
    required this.horizontalInset,
    required this.verticalInset,
    required this.minimumWidth,
    required this.alignment,
    this.visualHeight,
    this.cornerRadius,
    this.iconSize,
    this.iconGap,
    this.maximumHitHeight,
    this.edgeBleed,
    this.hitWidth,
  });
  final double horizontalInset, verticalInset, minimumWidth;
  final double? visualHeight, edgeBleed;

  /// Target width when it may be narrower than the target height; the plate
  /// still fits inside. Heights keep the platform minimum.
  final double? hitWidth;
  final double? cornerRadius, iconSize, maximumHitHeight, iconGap;
  final MainAxisAlignment alignment;
}

/// Icon buttons inside a field sit side by side in little room. A touch target
/// keeps the 44 height but takes only its plate plus two pixels either side
/// across, so neighbours abut without overlapping; a pointer target is the plate.
class FrostFieldIconScope extends InheritedWidget {
  const FrostFieldIconScope({required super.child, super.key});

  static double targetWidth(BuildContext context, double plate) {
    final density = FrostDensity.of(context);
    return density.usesPointer ? plate : math.min(density.targetHeight, plate + 4);
  }

  static double? targetWidthOf(BuildContext context, double plate) =>
      context.dependOnInheritedWidgetOfExactType<FrostFieldIconScope>() == null ? null : targetWidth(context, plate);

  @override
  bool updateShouldNotify(FrostFieldIconScope oldWidget) => false;
}

// ---------------------------------------------------------------------------
// Geometry

/// The resolved sizes of one button: its painted box and its hit target.
class FrostButtonMetrics {
  /// A text button, optionally with an icon: the plate grows from its insets.
  factory FrostButtonMetrics.text(BuildContext context, FrostControlSize size, FrostButtonGeometry? geometry) {
    final height = geometry?.visualHeight ?? size.height(context);
    final (hitHeight, hitWidth) = _target(context, height, geometry);
    final inset = geometry?.horizontalInset ?? frostButtonTextInset(size);
    return FrostButtonMetrics._(
      size: size,
      geometry: geometry,
      height: height,
      hitHeight: hitHeight,
      hitWidth: hitWidth,
      minWidth: geometry?.minimumWidth ?? 0,
      maxWidth: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: inset, vertical: geometry?.verticalInset ?? 0),
      centered: false,
      inkInset: 0,
      edgeInset: inset,
    );
  }

  /// An icon button: a square plate as wide as it is tall, centred in its
  /// target, whose glyph inset aligns the ink with a keyline.
  factory FrostButtonMetrics.icon(BuildContext context, FrostControlSize size, FrostButtonGeometry? geometry) {
    final height = geometry?.visualHeight ?? size.height(context);
    final (hitHeight, hitWidth) = _target(context, height, geometry, iconWidth: FrostFieldIconScope.targetWidthOf(context, height));
    final glyphInset = (math.max(hitWidth, height) - (geometry?.iconSize ?? size.iconSize)) / 2;
    return FrostButtonMetrics._(
      size: size,
      geometry: geometry,
      height: height,
      hitHeight: hitHeight,
      hitWidth: hitWidth,
      minWidth: height,
      maxWidth: height,
      padding: EdgeInsets.zero,
      centered: true,
      inkInset: glyphInset,
      edgeInset: glyphInset,
    );
  }

  FrostButtonMetrics._({
    required this.size,
    required FrostButtonGeometry? geometry,
    required this.height,
    required this.hitHeight,
    required this.hitWidth,
    required this.minWidth,
    required this.maxWidth,
    required this.padding,
    required this.centered,
    required this.inkInset,
    required this.edgeInset,
  }) : iconSize = geometry?.iconSize ?? size.iconSize,
       iconGap = geometry?.iconGap ?? (size == FrostControlSize.small || size == FrostControlSize.compact ? _compactIconGap : _regularIconGap),
       radius = geometry?.cornerRadius ?? FrostRadius.forHeight(height),
       alignment = geometry?.alignment ?? MainAxisAlignment.center,
       edgeBleed = geometry?.edgeBleed ?? 0;

  // The target keeps the platform minimum height unless the geometry caps it.
  static (double, double) _target(BuildContext context, double height, FrostButtonGeometry? geometry, {double? iconWidth}) {
    final hit = math.min(geometry?.maximumHitHeight ?? double.infinity, math.max(height, FrostDensity.of(context).targetHeight));
    return (hit, geometry?.hitWidth ?? iconWidth ?? hit);
  }

  final FrostControlSize size;

  /// Height of the painted plate.
  final double height;

  /// Minimum size of the hit target around the plate.
  final double hitHeight, hitWidth;
  final double iconSize, iconGap, radius;

  /// Main-axis alignment of the content inside the plate.
  final MainAxisAlignment alignment;

  /// Plain buttons only: how far the target extends past the layout edges.
  final double edgeBleed;

  /// Width limits and padding of the painted plate.
  final double minWidth, maxWidth;
  final EdgeInsets padding;

  /// Whether the plate is centred in its target (icons) or starts at its
  /// leading edge (text).
  final bool centered;

  /// Space between the target edge and the visible ink, for ink alignment.
  final double inkInset;

  /// How far an edge-aligned button bleeds past its keyline.
  final double edgeInset;
}

/// The hit target around a button's frame: it extends taps on the target
/// padding to the button, and lets an edge-aligned or bleeding plain button
/// spend its container's outside padding.
class FrostButtonHitArea extends StatefulWidget {
  const FrostButtonHitArea({
    required this.metrics,
    required this.interactive,
    required this.onPressed,
    required this.child,
    this.focusNode,
    this.automaticInkBounds = false,
    this.edgeAlignment,
    this.bleeds = false,
    super.key,
  });
  final FrostButtonMetrics metrics;
  final bool interactive;
  final VoidCallback? onPressed;
  final FocusNode? focusNode;

  /// Lets a shared row align this button's ink without an explicit edge.
  final bool automaticInkBounds;
  final FrostButtonEdgeAlignment? edgeAlignment;

  /// Whether [FrostButtonMetrics.edgeBleed] applies (plain buttons).
  final bool bleeds;
  final Widget child;

  @override
  State<FrostButtonHitArea> createState() => _FrostButtonHitAreaState();
}

class _FrostButtonHitAreaState extends State<FrostButtonHitArea> {
  bool _paddingPressValid = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Lifecycle cancellation must not let a later padding tap fire.
    if (!TickerMode.valuesOf(context).enabled) _paddingPressValid = false;
  }

  @override
  void didUpdateWidget(FrostButtonHitArea oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.interactive) _paddingPressValid = false;
  }

  @override
  Widget build(BuildContext context) {
    final metrics = widget.metrics;
    Widget control = Listener(
      onPointerDown: (_) => _paddingPressValid = widget.interactive,
      onPointerCancel: (_) => _paddingPressValid = false,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (_paddingPressValid && widget.interactive) {
            widget.focusNode?.requestFocus();
            widget.onPressed?.call();
          }
        },
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: metrics.hitHeight, minWidth: metrics.hitWidth),
          child: Align(alignment: metrics.centered ? Alignment.center : AlignmentDirectional.centerStart, widthFactor: 1, heightFactor: 1, child: widget.child),
        ),
      ),
    );
    // Ordinary text actions own their full feedback width, including in Wraps.
    // Only an explicit edge alignment or internal geometry may spend keyline
    // room; implicit outsets can overlap a neighbouring control's surface.
    control = FrostButtonInkBounds(inset: metrics.inkInset, automatic: widget.automaticInkBounds, child: control);
    if (widget.edgeAlignment case final alignment?) {
      return IntrinsicWidth(
        child: FrostButtonEdgeBleed(
          amount: metrics.edgeInset,
          start: alignment == FrostButtonEdgeAlignment.start,
          child: Align(
            alignment: alignment == FrostButtonEdgeAlignment.start ? AlignmentDirectional.centerStart : AlignmentDirectional.centerEnd,
            widthFactor: 1,
            heightFactor: 1,
            child: control,
          ),
        ),
      );
    }
    if (widget.bleeds && metrics.edgeBleed > 0) {
      return IntrinsicWidth(
        child: FrostBleed(
          amount: metrics.edgeBleed,
          child: Align(alignment: AlignmentDirectional.centerStart, widthFactor: 1, heightFactor: 1, child: control),
        ),
      );
    }
    return control;
  }
}

// ---------------------------------------------------------------------------
// Interaction

/// Pointer and keyboard state of one button, read by its [FrostButtonFrame].
abstract interface class FrostButtonInteraction {
  /// Whether the button takes presses now.
  bool get interactive;
  bool get hovered;
  bool get pressed;
  bool get focused;
  Set<WidgetState> get states;
  void hover(bool value);
  void press(bool value);
  void focus(bool value);
}

/// [FrostButtonInteraction] for the State that composes a button. The state
/// lives above the tooltip and the hit area, so it survives their changes.
mixin FrostButtonInteractionState<T extends StatefulWidget> on State<T> implements FrostButtonInteraction {
  bool _hovered = false, _pressed = false, _focused = false;

  @override
  bool get hovered => _hovered;
  @override
  bool get pressed => _pressed;
  @override
  bool get focused => _focused;

  @override
  Set<WidgetState> get states => <WidgetState>{
    if (!interactive) WidgetState.disabled,
    if (_hovered) WidgetState.hovered,
    if (_pressed && interactive) WidgetState.pressed,
    if (_focused) WidgetState.focused,
  };

  @override
  void hover(bool value) => setState(() => _hovered = value);
  @override
  void press(bool value) => setState(() => _pressed = value && interactive);
  @override
  void focus(bool value) => setState(() => _focused = value);

  @override
  void initState() {
    super.initState();
    FrostInputModality.instance.attach();
    FrostInputModality.instance.addListener(_modalityChanged);
    FocusManager.instance.addHighlightModeListener(_highlightModeChanged);
  }

  void _modalityChanged() {
    if (!mounted) return;
    setState(() {
      if (FrostInputModality.instance.touch) _hovered = false;
    });
  }

  void _highlightModeChanged(FocusHighlightMode _) {
    if (mounted) setState(() {});
  }

  /// Whether an enclosing control scope allows this control. Read through the
  /// shared layer, so every control built on it follows the scope.
  bool get scopeEnabled => _scopeEnabled;
  bool _scopeEnabled = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scopeEnabled = FrostControlScope.enabledOf(context);
    if (!_scopeEnabled) {
      _hovered = false;
      _pressed = false;
    }
    if (!TickerMode.valuesOf(context).enabled) {
      // The click surface owns input but this state owns the fill. Lifecycle
      // cancellation resets both without firing input callbacks.
      _hovered = false;
      _pressed = false;
    }
  }

  @override
  void didUpdateWidget(T oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!interactive) _pressed = false;
  }

  @override
  void dispose() {
    FrostInputModality.instance.removeListener(_modalityChanged);
    FrostInputModality.instance.detach();
    FocusManager.instance.removeHighlightModeListener(_highlightModeChanged);
    super.dispose();
  }
}

// ---------------------------------------------------------------------------
// Frame

/// How a button sits over media. [ink] is the ambient on-media ink; a [media]
/// button paints on-media chrome, which a [bare] one leaves transparent.
class FrostButtonMedia {
  const FrostButtonMedia._(this.ink, this.media, this.bare);

  /// [bare] asks for bare media paint, [chrome] for the on-media icon style;
  /// [iconContent] lets an ambient on-media scope turn an icon into chrome.
  factory FrostButtonMedia.of(BuildContext context, {bool bare = false, bool chrome = false, bool iconContent = false}) {
    final ink = FrostOnMediaChromeScope.inkOf(context) ?? (iconContent && FrostChromeOverMedia.activeOf(context) ? FrostThemeTokens.of(context).onMediaInk : null);
    final isBare = bare || ink != null && FrostMediaControlsScope.of(context);
    return FrostButtonMedia._(ink, isBare || chrome || ink != null && iconContent, isBare);
  }
  final Color? ink;
  final bool media, bare;
}

/// What a [FrostButtonFrame] paints, one subtype per kind of button.
sealed class FrostButtonFrameStyle {
  const FrostButtonFrameStyle({required this.media});
  final FrostButtonMedia media;
}

/// Actions: the variants, quiet and link text, and on-media chrome.
final class FrostActionFrameStyle extends FrostButtonFrameStyle {
  const FrostActionFrameStyle({
    required this.variant,
    required super.media,
    this.role = FrostButtonRole.normal,
    this.selected,
    this.quiet = false,
    this.link = false,
    this.shape = FrostButtonShape.rounded,
  });
  final FrostButtonVariant variant;
  final FrostButtonRole role;
  final bool? selected;

  /// Secondary ink ([quiet]) or accent ink ([link]) for unfilled text.
  final bool quiet, link;
  final FrostButtonShape shape;
}

/// Content-field triggers. A [search] field keeps its ring.
final class FrostFieldFrameStyle extends FrostButtonFrameStyle {
  const FrostFieldFrameStyle({required super.media, this.search = false});
  final bool search;
}

/// Content tags: a selectable fill, or the light [topic] fill.
final class FrostTagFrameStyle extends FrostButtonFrameStyle {
  const FrostTagFrameStyle({required super.media, this.topic = false, this.selected});
  final bool topic;
  final bool? selected;
}

class _FramePaint {
  const _FramePaint({required this.fill, required this.layer, required this.ink, required this.shape, this.edge, this.focusRing = true});
  final Color fill, layer, ink;
  final ShapeBorder shape;
  final Decoration? edge;

  /// Whether the frame paints its own keyboard ring.
  final bool focusRing;
}

/// Fill, border, shape, click feedback and focus of a button, and the
/// animated foreground its [builder] content is drawn in.
class FrostButtonFrame extends StatelessWidget {
  const FrostButtonFrame({
    required this.style,
    required this.interaction,
    required this.metrics,
    required this.labelStyle,
    required this.onPressed,
    required this.builder,
    this.disabled = false,
    this.onLongPress,
    this.focusNode,
    super.key,
  });
  final FrostButtonFrameStyle style;
  final FrostButtonInteraction interaction;
  final FrostButtonMetrics metrics;

  /// The label style the content inherits; the frame supplies its colour.
  final TextStyle labelStyle;
  final VoidCallback? onPressed, onLongPress;
  final FocusNode? focusNode;

  /// Dims the content; a disabled frame still paints its resting fill.
  final bool disabled;
  final Widget Function(BuildContext context, Color? foreground) builder;

  @override
  Widget build(BuildContext context) {
    final tokens = FrostThemeTokens.of(context);
    final paint = switch (style) {
      final FrostActionFrameStyle style => _action(context, tokens, style),
      final FrostFieldFrameStyle style => _field(context, tokens, style),
      final FrostTagFrameStyle style => _tag(context, tokens, style),
    };
    final shape = paint.shape;
    final media = style.media;
    final duration = FrostMotion.duration(context, FrostMotion.hover);
    Widget content = TweenAnimationBuilder<Color?>(
      tween: ColorTween(end: paint.ink),
      duration: duration,
      curve: FrostMotion.hoverCurve,
      builder: (context, foreground, _) => DefaultTextStyle(
        style: labelStyle.copyWith(color: foreground),
        child: IconTheme(
          data: IconThemeData(color: foreground, size: metrics.iconSize),
          child: builder(context, foreground),
        ),
      ),
    );
    content = AnimatedOpacity(opacity: disabled && !FrostControlDimming.ownsOpacityOf(context) ? _disabledOpacity : 1, duration: duration, child: content);
    final interactive = interaction.interactive;
    // The fill is one shape and the edge one inset stroke, neither clipped, so
    // neither squares the other's antialiased coverage. Only the content is clipped.
    return CustomPaint(
      foregroundPainter: paint.focusRing && interactive && frostShowsFocus(interaction.states)
          ? FrostFocusOutlinePainter(
              shape,
              media.media ? tokens.onMediaInk : media.ink ?? tokens.focus,
              FrostMetrics.focusBorderWidth,
              Directionality.of(context),
            )
          : null,
      child: FrostClickSurfaceVisuals(
        child: FrostClickSurface(
          focusNode: focusNode,
          onTap: interactive ? onPressed : null,
          onLongPress: interactive ? onLongPress : null,
          onHover: (value) => interaction.hover(value),
          onPressedChange: (value) => interaction.press(value),
          onFocusChange: (value) => interaction.focus(value),
          child: FrostSkeletonShape(
            shape: shape,
            active: paint.fill.a > 0,
            child: FrostInteractionDecoration(
              duration: duration,
              curve: FrostMotion.hoverCurve,
              // The state layer is folded into the fill so the shape is
              // painted once; a second antialiased shape would fringe its edge.
              decoration: ShapeDecoration(shape: shape, color: Color.alphaBlend(paint.layer, paint.fill)),
              foregroundDecoration: paint.edge,
              // Only the content is clipped to the shape; the fill and edge above
              // are painted unclipped.
              child: ClipPath(
                clipper: ShapeBorderClipper(shape: shape),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: metrics.height, minWidth: metrics.minWidth, maxWidth: metrics.maxWidth),
                  child: Padding(padding: metrics.padding, child: content),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Hover and press wash of an unfilled button over media ink, and of any
  // button whose fill is a solid colour.
  double _washAlpha() => !interaction.interactive
      ? 0
      : interaction.pressed
      ? .08
      : interaction.hovered
      ? .04
      : 0;

  // A window background behind the button may need a more opaque fill to keep
  // the ink readable; the state layer then folds into that fill.
  (Color, Color) _readable(BuildContext context, FrostThemeTokens tokens, Color fill, Color layer, Color ink) {
    final actualWindow = frostWindowBackgroundOf(context, tokens);
    if (actualWindow == null) return (fill, layer);
    final background = FrostSurfaceScope.maybeOf(context)?.background ?? actualWindow;
    final composed = Color.alphaBlend(layer, fill);
    // Eases in and out with the ambient art, like the surfaces around it.
    final weight = FrostWindowBackgroundScope.maybeOf(context)!.ambientWeight;
    return (frostLerpColorPremultiplied(composed, frostReadableWindowFill(tokens, composed, background, ink), weight)!, layer.withValues(alpha: 0));
  }

  _FramePaint _action(BuildContext context, FrostThemeTokens tokens, FrostActionFrameStyle style) {
    final media = style.media, mediaInk = media.ink, variant = style.variant;
    final destructive = style.role == FrostButtonRole.destructive;
    final restingFill = switch ((style.selected, media.media, variant)) {
      (true, _, _) => tokens.selectionFill,
      (_, true, _) => tokens.onMediaScrim.withValues(alpha: media.bare ? 0 : tokens.onMediaScrim.a),
      (_, _, FrostButtonVariant.prominent) =>
        disabled
            ? tokens.fill
            : destructive
            ? tokens.negativeFill
            : tokens.actionFill,
      (_, _, FrostButtonVariant.standard) => mediaInk == null ? tokens.fill : tokens.onMediaScrim,
      (_, _, FrostButtonVariant.tinted) =>
        disabled
            ? tokens.fill
            : destructive
            ? tokens.negativeTint
            : tokens.selectionFill,
      _ => (mediaInk == null ? tokens.fillSubtle : tokens.onMediaScrim).withValues(alpha: 0),
    };
    var ink = switch ((style.selected, media.media, variant)) {
      (true, _, _) => tokens.selectionInk,
      (_, true, _) => tokens.onMediaInk,
      (_, _, FrostButtonVariant.prominent) => destructive ? tokens.onNegative : tokens.onAction,
      (_, _, FrostButtonVariant.tinted) =>
        destructive
            ? tokens.negativeInk
            : disabled
            ? tokens.textPrimary
            : tokens.selectionInk,
      _ =>
        destructive
            ? tokens.negativeInk
            : style.link
            ? tokens.accentInk
            : style.quiet
            ? mediaInk ?? tokens.textSecondary
            : mediaInk ?? tokens.textPrimary,
    };
    if (destructive && variant != FrostButtonVariant.prominent && !media.media) {
      ink = readableAccentTone(ink, Color.alphaBlend(restingFill, tokens.surface), 4.5);
    }
    final feedbackRole = variant == FrostButtonVariant.prominent && style.selected != true ? FrostFeedbackRole.primary : FrostFeedbackRole.quiet;
    var fill = restingFill;
    var layer = mediaInk != null && !media.media && variant != FrostButtonVariant.prominent
        ? mediaInk.withValues(alpha: _washAlpha())
        : media.media || (destructive && feedbackRole == FrostFeedbackRole.primary)
        ? solidWashColor(fill).withValues(alpha: !interaction.interactive ? 0 : solidOverlayAlpha(fill, _washAlpha()))
        : frostButtonStateLayer(tokens, interaction.states, feedbackRole);
    if (!media.media && mediaInk == null && !disabled) (fill, layer) = _readable(context, tokens, fill, layer, ink);
    final shape = media.media && !media.bare
        ? const CircleBorder()
        : style.shape == FrostButtonShape.pill
        ? const StadiumBorder()
        : FrostRadius.shape(context, metrics.radius);
    return _FramePaint(
      fill: fill,
      layer: layer,
      ink: ink,
      shape: shape,
      edge: variant == FrostButtonVariant.outlined
          ? ShapeDecoration(
              shape: (shape as OutlinedBorder).copyWith(
                side: BorderSide(
                  color: destructive ? ink : tokens.textSecondary.withValues(alpha: disabled ? .16 : .45),
                  width: 1 / MediaQuery.devicePixelRatioOf(context),
                  strokeAlign: BorderSide.strokeAlignInside,
                ),
              ),
            )
          : null,
    );
  }

  _FramePaint _field(BuildContext context, FrostThemeTokens tokens, FrostFieldFrameStyle style) {
    final media = style.media;
    final chrome = FrostFieldChrome.resolve(
      context,
      enabled: interaction.interactive,
      focused: !style.search && interaction.focused,
      invalid: FrostFieldOptions.of(context)?.invalid ?? false,
      hovered: interaction.hovered,
    );
    return _FramePaint(
      fill: chrome.fill,
      layer: tokens.fillSubtle.withValues(alpha: 0),
      ink: media.media ? tokens.onMediaInk : media.ink ?? tokens.textPrimary,
      shape: chrome.shape,
      edge: chrome.edge,
      // A content field shows focus with its stroke; search keeps the ring.
      focusRing: style.search,
    );
  }

  _FramePaint _tag(BuildContext context, FrostThemeTokens tokens, FrostTagFrameStyle style) {
    final media = style.media, mediaInk = media.ink;
    final Color restingFill, ink;
    if (style.topic) {
      restingFill = tokens.fillSubtle;
      ink = tokens.textSecondary;
    } else {
      restingFill = switch ((style.selected, media.media)) {
        (true, _) => tokens.selectionFill,
        (_, true) => tokens.onMediaScrim.withValues(alpha: media.bare ? 0 : tokens.onMediaScrim.a),
        _ => mediaInk == null ? tokens.fill : tokens.onMediaScrim,
      };
      ink = switch ((style.selected, media.media)) {
        (true, _) => tokens.selectionInk,
        (_, true) => tokens.onMediaInk,
        _ => mediaInk ?? tokens.textSecondary,
      };
    }
    var fill = restingFill;
    var layer = mediaInk != null && !media.media
        ? mediaInk.withValues(alpha: _washAlpha())
        : media.media
        ? solidWashColor(fill).withValues(alpha: !interaction.interactive ? 0 : solidOverlayAlpha(fill, _washAlpha()))
        : frostButtonStateLayer(tokens, interaction.states, FrostFeedbackRole.quiet);
    if (!media.media && mediaInk == null) (fill, layer) = _readable(context, tokens, fill, layer, ink);
    return _FramePaint(fill: fill, layer: layer, ink: ink, shape: FrostRadius.shape(context, metrics.radius));
  }
}

// ---------------------------------------------------------------------------
// Action state

/// What [FrostActionStateLayer] shows over a button's content.
class FrostButtonActivity {
  const FrostButtonActivity({this.loading = false, this.cancellable = false, this.contentLabel, this.result, this.resultLabel});
  static const idle = FrostButtonActivity();

  /// A running operation: a spinner replaces the content after a short delay
  /// and the button ignores presses, unless [cancellable].
  final bool loading;

  /// Keeps the press live during [loading], for a pending action that the
  /// same button cancels.
  final bool cancellable;

  /// What the content measures and shows when the button reads as something
  /// else while it runs, so reading as cancel does not change its width.
  final String? contentLabel;

  /// A drawn result glyph; the button ignores presses while it shows.
  final Widget? result;

  /// Announces [result].
  final String? resultLabel;

  /// Whether a result is showing.
  bool get busy => result != null;
}

/// Spinner and result glyph over a button's [child]. The layer is always
/// present, so content keeps its place in the tree when a run starts.
class FrostActionStateLayer extends StatelessWidget {
  const FrostActionStateLayer({required this.activity, required this.size, required this.color, required this.child, super.key});
  final FrostButtonActivity activity;

  /// The button size; the spinner uses the nearest of small, compact and regular.
  final FrostControlSize size;

  /// The spinner colour, the button's animated foreground.
  final Color? color;
  final Widget child;

  @override
  Widget build(BuildContext context) => FrostLoadingGate(
    loading: activity.loading,
    builder: (context, showLoading) => Stack(
      alignment: Alignment.center,
      fit: StackFit.passthrough,
      children: [
        AnimatedOpacity(opacity: showLoading || activity.result != null ? 0 : 1, duration: FrostMotion.duration(context, FrostMotion.layoutFade), child: child),
        if (activity.result == null || showLoading)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedOpacity(
                opacity: showLoading ? 1 : 0,
                duration: FrostMotion.duration(context, FrostMotion.layoutFade),
                child: Center(
                  child: TickerMode(
                    enabled: showLoading,
                    child: FrostActivityForeground(
                      color: color!,
                      child: FrostActivityIndicator(
                        size: size == FrostControlSize.small
                            ? FrostControlSize.small
                            : size == FrostControlSize.compact
                            ? FrostControlSize.compact
                            : FrostControlSize.regular,
                        semanticLabel: null,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        Positioned.fill(
          child: IgnorePointer(
            child: Center(
              child: AnimatedSwitcher(
                duration: FrostMotion.duration(context, FrostMotion.layoutFade),
                child: showLoading ? const SizedBox.shrink() : activity.result ?? const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

// ---------------------------------------------------------------------------
// Content

/// The icon, label, chevron and trailing row of a button, with its
/// truncation and wrapping.
class FrostButtonContent extends StatelessWidget {
  const FrostButtonContent({
    required this.label,
    required this.metrics,
    required this.labelStyle,
    required this.alignment,
    this.labelWidget,
    this.icon,
    this.iconWidget,
    this.trailing,
    this.glyphColor,
    this.showsLabel = true,
    this.chevron = FrostButtonChevron.none,
    this.fills = false,
    this.textRole = FrostTextRole.callout,
    this.prominent = false,
    this.wrapsLabel = false,
    this.truncates = true,
    this.wrapsEnlargedText = false,
    super.key,
  });
  static const _iconPop = AlwaysStoppedAnimation<double>(1);
  final String label;
  final FrostButtonMetrics metrics;
  final TextStyle labelStyle;
  final MainAxisAlignment alignment;
  final Widget? labelWidget, iconWidget, trailing;
  final FrostIconData? icon;

  /// Colour of [icon] and the chevron.
  final Color? glyphColor;
  final bool showsLabel;
  final FrostButtonChevron chevron;

  /// Fills the plate's width, with the label taking the free space (fields).
  final bool fills;
  final FrostTextRole textRole;

  /// Draws the label as prominent skeleton text in [labelStyle].
  final bool prominent;
  final bool wrapsLabel, truncates;

  /// Lets the label wrap once text scaling enlarges it (actions outside toolbars).
  final bool wrapsEnlargedText;

  @override
  Widget build(BuildContext context) {
    final hasIcon = icon != null || iconWidget != null;
    final largeText =
        wrapsEnlargedText && !FrostControlScope.toolbarOf(context) && MediaQuery.textScalerOf(context).scale(labelStyle.fontSize!) > labelStyle.fontSize!;
    final maxLines = wrapsLabel || largeText ? null : 1;
    final overflow = maxLines == null || !truncates ? TextOverflow.visible : TextOverflow.ellipsis;
    return Row(
      mainAxisSize: fills ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: alignment,
      children: [
        if (hasIcon)
          ScaleTransition(
            scale: _iconPop,
            child: iconWidget ?? FrostIcon(icon!, size: metrics.iconSize, color: glyphColor),
          ),
        if (hasIcon && showsLabel) SizedBox(width: metrics.iconGap),
        if (showsLabel)
          Flexible(
            fit: fills ? FlexFit.tight : FlexFit.loose,
            child:
                labelWidget ??
                (prominent
                    ? FrostSkeletonText(
                        child: Text(label, style: labelStyle, maxLines: maxLines, overflow: overflow),
                      )
                    : FrostText(label, role: textRole, maxLines: maxLines, overflow: overflow)),
          ),
        if (chevron != FrostButtonChevron.none) ...[
          const SizedBox(width: _chevronGap),
          FrostIcon(
            chevron == FrostButtonChevron.down ? FrostIconSet.of(context).chevronDown : FrostIconSet.of(context).chevronUpDown,
            size: metrics.size.iconSize,
            color: glyphColor,
          ),
        ],
        ?trailing,
      ],
    );
  }
}
