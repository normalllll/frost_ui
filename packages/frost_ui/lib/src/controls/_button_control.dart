import 'package:flutter/material.dart';

import '../foundation/control_scope.dart';
import '../foundation/icon_data.dart';
import '../foundation/scope.dart';
import '../foundation/sizes.dart';
import '../foundation/tokens.dart';
import '../foundation/typography.dart';
import '../overlays/tooltip.dart';
import '../primitives/text.dart';
import '_button_parts.dart';
import '_button_types.dart';

export '_button_parts.dart';

// Each kind of button composes the blocks in _button_parts.dart: a State that
// owns the pointer and focus state, then semantics and tooltip, the hit area,
// the frame of its kind, the action-state layer and the content row.
// - FrostButtonControl: actions (text and icon), including toolbar and media
//   actions;
// - FrostFieldButton: content-field and search triggers;
// - FrostTagButton: content tags and filter bodies.
// None of them is exported by frost_ui.dart.

/// Library-only presentation of an action; geometry remains a numeric configuration.
enum FrostButtonPresentation { action, link, quiet, media }

/// The action button shared by public buttons, toolbar and media actions:
/// text, text and icon, or icon only (an [iconStyle]).
class FrostButtonControl extends StatefulWidget {
  const FrostButtonControl({
    required this.label,
    required this.onPressed,
    this.labelWidget,
    this.onLongPress,
    this.semanticLabel,
    this.iconWidget,
    this.icon,
    this.variant = FrostButtonVariant.standard,
    this.role = FrostButtonRole.normal,
    this.size,
    this.chevron = FrostButtonChevron.none,
    this.iconStyle,
    this.selected,
    this.shape = FrostButtonShape.rounded,
    this.activity = FrostButtonActivity.idle,
    this.tooltip,
    this.edgeAlignment,
    this.focusNode,
    this.textRole = FrostTextRole.callout,
    this.showsLabel = true,
    this.truncates = true,
    this.geometry,
    this.presentation = FrostButtonPresentation.action,
    this.wrapsLabel = false,
    super.key,
  });
  final String label;
  final String? semanticLabel;
  final VoidCallback? onPressed, onLongPress;
  final Widget? labelWidget, iconWidget;
  final FrostIconData? icon;
  final FrostButtonVariant variant;
  final FrostButtonRole role;
  final FrostControlSize? size;
  final FrostButtonChevron chevron;

  /// Makes this an icon button; [label] is then its tooltip and semantics.
  final FrostIconButtonStyle? iconStyle;
  final bool? selected;
  final FrostButtonShape shape;

  /// Spinner, cancel and result state of the action.
  final FrostButtonActivity activity;
  final String? tooltip;
  final FrostButtonEdgeAlignment? edgeAlignment;
  final FocusNode? focusNode;
  final FrostTextRole textRole;
  final bool showsLabel, truncates;
  final FrostButtonGeometry? geometry;
  final FrostButtonPresentation presentation;
  final bool wrapsLabel;

  /// Whether the action shows its spinner.
  bool get loading => activity.loading;

  @override
  State<FrostButtonControl> createState() => _FrostButtonControlState();
}

class _FrostButtonControlState extends State<FrostButtonControl> with FrostButtonInteractionState<FrostButtonControl> {
  @override
  bool get interactive {
    final activity = widget.activity;
    return scopeEnabled && widget.onPressed != null && (!activity.loading || activity.cancellable) && !activity.busy;
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size ?? FrostControlScope.sizeOf(context);
    final iconOnly = widget.iconStyle != null;
    final metrics = iconOnly ? FrostButtonMetrics.icon(context, size, widget.geometry) : FrostButtonMetrics.text(context, size, widget.geometry);
    final media = FrostButtonMedia.of(
      context,
      bare: widget.presentation == FrostButtonPresentation.media,
      chrome: widget.iconStyle == FrostIconButtonStyle.onMedia,
      iconContent: iconOnly || !widget.showsLabel && (widget.icon != null || widget.iconWidget != null),
    );
    final variant = switch (widget.iconStyle) {
      FrostIconButtonStyle.plain => FrostButtonVariant.plain,
      FrostIconButtonStyle.standard => FrostButtonVariant.standard,
      _ => widget.variant,
    };
    final prominent = variant == FrostButtonVariant.prominent;
    final activity = widget.activity;
    final labelStyle = frostTextStyle(context, widget.textRole, null).copyWith(fontWeight: prominent ? FontWeight.w600 : null);
    final control = FrostButtonHitArea(
      metrics: metrics,
      interactive: interactive,
      onPressed: widget.onPressed,
      focusNode: widget.focusNode,
      automaticInkBounds: !media.media && iconOnly && widget.iconStyle == FrostIconButtonStyle.plain && widget.edgeAlignment == null,
      edgeAlignment: widget.edgeAlignment,
      bleeds: variant == FrostButtonVariant.plain,
      child: FrostButtonFrame(
        style: FrostActionFrameStyle(
          variant: variant,
          media: media,
          role: widget.role,
          selected: widget.selected,
          quiet: widget.presentation == FrostButtonPresentation.quiet,
          link: widget.presentation == FrostButtonPresentation.link,
          shape: widget.shape,
        ),
        interaction: this,
        metrics: metrics,
        labelStyle: labelStyle,
        disabled: (!scopeEnabled || widget.onPressed == null) && !activity.loading && !activity.busy,
        onPressed: widget.onPressed,
        onLongPress: widget.onLongPress,
        focusNode: widget.focusNode,
        builder: (context, foreground) => FrostActionStateLayer(
          activity: activity,
          size: size,
          color: foreground,
          child: FrostButtonContent(
            label: activity.contentLabel ?? widget.label,
            metrics: metrics,
            labelStyle: labelStyle,
            alignment: media.media ? MainAxisAlignment.center : metrics.alignment,
            labelWidget: widget.labelWidget,
            icon: widget.icon,
            iconWidget: widget.iconWidget,
            glyphColor: foreground,
            showsLabel: widget.showsLabel && !iconOnly,
            chevron: widget.chevron,
            textRole: widget.textRole,
            prominent: prominent,
            wrapsLabel: widget.wrapsLabel,
            truncates: widget.truncates,
            wrapsEnlargedText: widget.presentation == FrostButtonPresentation.action,
          ),
        ),
      ),
    );
    final help = widget.tooltip ?? (iconOnly || !widget.showsLabel ? widget.label : null);
    return Semantics(
      button: true,
      label: widget.semanticLabel ?? widget.label,
      hint: widget.tooltip,
      value: activity.resultLabel ?? (activity.loading ? FrostScope.labelsOf(context).loading : null),
      liveRegion: activity.loading || activity.resultLabel != null,
      toggled: widget.selected,
      enabled: interactive,
      onTap: interactive ? widget.onPressed : null,
      onLongPress: interactive ? widget.onLongPress : null,
      excludeSemantics: true,
      child: help == null ? control : FrostTooltip(message: help, excludeFromSemantics: true, child: control),
    );
  }
}

/// The trigger of a content field (value, date and range selectors) or, with
/// [search], a search-shaped button. The field chrome owns fill and stroke.
class FrostFieldButton extends StatefulWidget {
  const FrostFieldButton({
    required this.label,
    required this.onPressed,
    required this.geometry,
    this.search = false,
    this.semanticLabel,
    this.labelWidget,
    this.icon,
    this.iconWidget,
    this.trailing,
    this.chevron = FrostButtonChevron.none,
    this.size,
    this.focusNode,
    this.textRole = FrostTextRole.callout,
    this.showsLabel = true,
    this.truncates = true,
    this.wrapsLabel = false,
    super.key,
  });
  final String label;
  final String? semanticLabel;
  final VoidCallback? onPressed;
  final FrostButtonGeometry geometry;
  final bool search;
  final Widget? labelWidget, iconWidget, trailing;
  final FrostIconData? icon;
  final FrostButtonChevron chevron;
  final FrostControlSize? size;
  final FocusNode? focusNode;
  final FrostTextRole textRole;

  /// Search only: false collapses the field to its icon.
  final bool showsLabel;
  final bool truncates, wrapsLabel;

  @override
  State<FrostFieldButton> createState() => _FrostFieldButtonState();
}

class _FrostFieldButtonState extends State<FrostFieldButton> with FrostButtonInteractionState<FrostFieldButton> {
  @override
  bool get interactive => scopeEnabled && widget.onPressed != null;

  @override
  Widget build(BuildContext context) {
    final size = widget.size ?? FrostControlScope.sizeOf(context);
    final metrics = FrostButtonMetrics.text(context, size, widget.geometry);
    final media = FrostButtonMedia.of(context, iconContent: !widget.showsLabel && (widget.icon != null || widget.iconWidget != null));
    final labelStyle = frostTextStyle(context, widget.textRole, null);
    final control = FrostButtonHitArea(
      metrics: metrics,
      interactive: interactive,
      onPressed: widget.onPressed,
      focusNode: widget.focusNode,
      child: FrostButtonFrame(
        style: FrostFieldFrameStyle(media: media, search: widget.search),
        interaction: this,
        metrics: metrics,
        labelStyle: labelStyle,
        disabled: !interactive,
        onPressed: widget.onPressed,
        focusNode: widget.focusNode,
        builder: (context, foreground) => FrostActionStateLayer(
          activity: FrostButtonActivity.idle,
          size: size,
          color: foreground,
          child: FrostButtonContent(
            label: widget.label,
            metrics: metrics,
            labelStyle: labelStyle,
            alignment: media.media ? MainAxisAlignment.center : metrics.alignment,
            labelWidget: widget.labelWidget,
            icon: widget.icon,
            iconWidget: widget.iconWidget,
            trailing: widget.trailing,
            glyphColor: FrostThemeTokens.of(context).textSecondary,
            showsLabel: widget.showsLabel,
            chevron: widget.chevron,
            fills: true,
            textRole: widget.textRole,
            wrapsLabel: widget.wrapsLabel,
            truncates: widget.truncates,
          ),
        ),
      ),
    );
    return Semantics(
      button: true,
      label: widget.semanticLabel ?? widget.label,
      liveRegion: false,
      enabled: interactive,
      onTap: interactive ? widget.onPressed : null,
      excludeSemantics: true,
      child: widget.showsLabel ? control : FrostTooltip(message: widget.label, excludeFromSemantics: true, child: control),
    );
  }
}

/// A content tag or filter body: selectable or [topic] fill, footnote text,
/// no disabled dimming of its own.
class FrostTagButton extends StatefulWidget {
  const FrostTagButton({
    required this.label,
    required this.labelWidget,
    required this.onPressed,
    required this.geometry,
    this.topic = false,
    this.selected,
    this.size,
    this.focusNode,
    this.chevron = FrostButtonChevron.none,
    this.truncates = true,
    this.wrapsLabel = false,
    super.key,
  });
  final String label;
  final Widget labelWidget;
  final VoidCallback? onPressed;
  final FrostButtonGeometry geometry;
  final bool topic;
  final bool? selected;
  final FrostControlSize? size;
  final FocusNode? focusNode;
  final FrostButtonChevron chevron;
  final bool truncates, wrapsLabel;

  @override
  State<FrostTagButton> createState() => _FrostTagButtonState();
}

class _FrostTagButtonState extends State<FrostTagButton> with FrostButtonInteractionState<FrostTagButton> {
  @override
  bool get interactive => scopeEnabled && widget.onPressed != null;

  @override
  Widget build(BuildContext context) {
    final size = widget.size ?? FrostControlScope.sizeOf(context);
    final metrics = FrostButtonMetrics.text(context, size, widget.geometry);
    final media = FrostButtonMedia.of(context);
    final labelStyle = frostTextStyle(context, FrostTextRole.footnote, null);
    return Semantics(
      // A static tag is content, not a disabled button.
      button: widget.onPressed != null,
      label: widget.label,
      liveRegion: false,
      toggled: widget.selected,
      selected: widget.selected,
      enabled: widget.onPressed != null ? interactive : null,
      onTap: interactive ? widget.onPressed : null,
      excludeSemantics: true,
      child: FrostButtonHitArea(
        metrics: metrics,
        interactive: interactive,
        onPressed: widget.onPressed,
        focusNode: widget.focusNode,
        bleeds: widget.topic,
        child: FrostButtonFrame(
          style: FrostTagFrameStyle(media: media, topic: widget.topic, selected: widget.selected),
          interaction: this,
          metrics: metrics,
          labelStyle: labelStyle,
          onPressed: widget.onPressed,
          focusNode: widget.focusNode,
          builder: (context, foreground) => FrostActionStateLayer(
            activity: FrostButtonActivity.idle,
            size: size,
            color: foreground,
            child: FrostButtonContent(
              label: widget.label,
              metrics: metrics,
              labelStyle: labelStyle,
              alignment: media.media ? MainAxisAlignment.center : metrics.alignment,
              labelWidget: widget.labelWidget,
              glyphColor: foreground,
              chevron: widget.chevron,
              textRole: FrostTextRole.footnote,
              wrapsLabel: widget.wrapsLabel,
              truncates: widget.truncates,
            ),
          ),
        ),
      ),
    );
  }
}
