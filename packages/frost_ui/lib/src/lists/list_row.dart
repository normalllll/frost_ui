// Public argument names stay plain while the storage is private.
// ignore_for_file: prefer_initializing_formals

import 'dart:math' as math;
import 'dart:ui' show BoxHeightStyle;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../controls/_picker_row_scope.dart';
import '../controls/buttons.dart' show FrostButton, FrostButtonEdgeAlignment, frostButtonIsIcon;
import '../controls/checkbox.dart';
import '../controls/switch.dart';
import '../display/_status_metrics.dart';
import '../display/status_dot.dart';
import '../feedback/_skeleton_geometry.dart';
import '../feedback/skeleton.dart';
import '../foundation/_control_geometry.dart';
import '../foundation/_row_metrics.dart';
import '../foundation/control_scope.dart';
import '../foundation/density.dart';
import '../foundation/fonts.dart';
import '../foundation/metrics.dart';
import '../foundation/radius.dart';
import '../foundation/sizes.dart';
import '../foundation/spacing.dart';
import '../foundation/tokens.dart';
import '../foundation/typography.dart';
import '../motion/_layout_identity.dart';
import '../motion/_material_reveal.dart';
import '../motion/_user_selection_draw.dart';
import '../motion/layout_crossfade.dart';
import '../motion/spring.dart';
import '../overlays/_additional_menu_entries.dart';
import '../overlays/context_menu.dart';
import '../overlays/menu_entry.dart';
import '../primitives/_click_surface_visuals.dart';
import '../primitives/_directional_icon.dart';
import '../primitives/_icon_slot.dart';
import '../primitives/click_surface.dart';
import '../primitives/glyph.dart';
import '../primitives/icon.dart';
import '../primitives/keyline.dart';
import '../primitives/path_text.dart';
import '../primitives/presence.dart';
import '../primitives/text.dart';
import '_inline_row_text.dart';
import '_row_content.dart';
import '_row_layout.dart';
import '_row_scope.dart';
import '_selection_presentation.dart';

// Text blocks keep their base breathing room; secondary lines share this gap.
const _rowTextGap = 2.0;
const _rowDisabledOpacity = .38;

enum FrostRowAccessory { none, chevron, external }

/// The text under (or after) a row's title. Each kind keeps the complete text
/// as the row's accessibility value, even when it is truncated.
sealed class FrostRowSubtitle {
  const FrostRowSubtitle._(this.text);

  /// The ordinary subtitle below the title. [tone] inks an unselected
  /// subtitle: secondary by default, tertiary for quieter detail such as a
  /// file name, or a status tone for a failure. [content] marks content text
  /// (see [FrostText.content]), such as a person's or a work's name.
  /// [maxLines] caps a long description and ends it with an ellipsis; the
  /// accessibility value stays the full text. Null wraps without a limit.
  const factory FrostRowSubtitle(String text, {FrostTextTone tone, bool content, int? maxLines}) = _TextSubtitle;

  /// A semantic status dot before the ordinary subtitle; the text stays the
  /// only accessibility value. [tone] inks the text as for the ordinary
  /// subtitle, such as negative for a failure.
  const factory FrostRowSubtitle.status(String text, FrostStatusTone status, {FrostTextTone tone, bool content, int? maxLines}) = _StatusSubtitle;

  /// A path in tabular figures, wrapped and selected as one original value.
  const factory FrostRowSubtitle.path(String path) = _PathSubtitle;

  /// After the full title on the same baseline. It ellipsizes in the
  /// remaining space and never makes a second line; only the title wraps.
  /// Trailing metadata keeps its inline place.
  const factory FrostRowSubtitle.inline(String text, {FrostTextTone tone, bool content}) = _InlineSubtitle;

  final String text;
}

final class _TextSubtitle extends FrostRowSubtitle {
  const _TextSubtitle(super.text, {this.tone = FrostTextTone.secondary, this.content = false, this.maxLines})
    : assert(maxLines == null || maxLines > 0),
      super._();
  final FrostTextTone tone;
  final bool content;
  final int? maxLines;
}

final class _StatusSubtitle extends FrostRowSubtitle {
  const _StatusSubtitle(super.text, this.status, {this.tone = FrostTextTone.secondary, this.content = false, this.maxLines})
    : assert(maxLines == null || maxLines > 0),
      super._();
  final FrostTextTone tone;
  final FrostStatusTone status;
  final bool content;
  final int? maxLines;
}

final class _PathSubtitle extends FrostRowSubtitle {
  const _PathSubtitle(super.text) : super._();
}

final class _InlineSubtitle extends FrostRowSubtitle {
  const _InlineSubtitle(super.text, {this.tone = FrostTextTone.secondary, this.content = false}) : super._();
  final FrostTextTone tone;
  final bool content;
}

/// Library-only: how [subtitle] inks its text, for rows outside this library
/// that draw it on one line. A path keeps tabular figures.
({FrostTextTone tone, FrostStatusTone? status, bool content, bool path}) frostRowSubtitleParts(FrostRowSubtitle subtitle) => switch (subtitle) {
  _TextSubtitle(:final tone, :final content) || _InlineSubtitle(:final tone, :final content) => (tone: tone, status: null, content: content, path: false),
  _StatusSubtitle(:final tone, :final status, :final content) => (tone: tone, status: status, content: content, path: false),
  _PathSubtitle() => (tone: FrostTextTone.secondary, status: null, content: false, path: true),
};

/// A readable row. Values move below the text when their actual widths cannot
/// share one line; labels and values never truncate at larger text sizes.
class FrostListRow extends StatefulWidget {
  /// Explicit content determines bones only; semantics use the loading label.
  factory FrostListRow.skeleton({required String title, required bool icon, required String? subtitle, required String? value}) =>
      _SkeletonListRow(icon, title: title, subtitle: subtitle, value: value);

  /// A row that may open something, show a value or carry trailing controls.
  /// [leading] takes any widget through [FrostLeading.custom], such as a
  /// thumbnail, status dot or button; a [FrostGlyph] draws in the icon column.
  const FrostListRow({
    required this.title,
    this.subtitle,
    this.contentTitle = false,
    FrostLeading? leading,
    String? value,
    Widget? trailing,
    FrostRowAccessory accessory = FrostRowAccessory.none,
    VoidCallback? onPressed,
    VoidCallback? onOpenInNewTab,
    VoidCallback? onOpenInBackground,
    this.selected = false,
    bool destructive = false,
    bool enabled = true,
    List<FrostMenuEntry> contextMenu = const [],
    super.key,
  }) : _leading = leading,
       _value = value,
       _trailing = trailing,
       _accessory = accessory,
       _onPressed = onPressed,
       _onOpenInNewTab = onOpenInNewTab,
       _onOpenInBackground = onOpenInBackground,
       _destructive = destructive,
       _enabled = enabled,
       _contextMenu = contextMenu,
       _toggle = null,
       _onChanged = null,
       _checked = null;

  /// A row whose whole surface flips a switch at its end.
  const FrostListRow.toggle({
    required this.title,
    this.subtitle,
    this.contentTitle = false,
    FrostGlyph? leading,
    required bool value,
    required ValueChanged<bool>? onChanged,
    this.selected = false,
    super.key,
  }) : _leading = leading,
       _value = null,
       _trailing = null,
       _accessory = FrostRowAccessory.none,
       _onPressed = null,
       _destructive = false,
       _enabled = onChanged != null,
       _contextMenu = const [],
       _onOpenInNewTab = null,
       _onOpenInBackground = null,
       _toggle = value,
       _onChanged = onChanged,
       _checked = null;

  /// A row that shows a check at its end when [checked].
  const FrostListRow.check({
    required this.title,
    this.subtitle,
    this.contentTitle = false,
    FrostGlyph? leading,
    required bool checked,
    required VoidCallback? onPressed,
    this.selected = false,
    super.key,
  }) : _leading = leading,
       _value = null,
       _trailing = null,
       _accessory = FrostRowAccessory.none,
       _onPressed = onPressed,
       _destructive = false,
       _enabled = onPressed != null,
       _contextMenu = const [],
       _onOpenInNewTab = null,
       _onOpenInBackground = null,
       _toggle = null,
       _onChanged = null,
       _checked = checked;
  final String title;
  final FrostRowSubtitle? subtitle;

  /// The title is content text (see [FrostText.content]), such as a person's
  /// or a work's name, drawn with the regional forms of its own script or
  /// [FrostFonts.defaultScript] rather than the interface language. Interface
  /// labels, the default, keep the interface font.
  final bool contentTitle;

  /// Highlights this row without entering checkmark or checkbox selection mode.
  /// Shares the task-row fill, ink and transition; activation is unchanged.
  final bool selected;

  // Arguments that only some constructors take; the others store defaults.
  final FrostLeading? _leading;
  final String? _value;
  final Widget? _trailing;
  final FrostRowAccessory _accessory;
  final VoidCallback? _onPressed;
  final bool _destructive, _enabled;
  final List<FrostMenuEntry> _contextMenu;
  final VoidCallback? _onOpenInNewTab, _onOpenInBackground;
  final bool? _toggle, _checked;
  final ValueChanged<bool>? _onChanged;
  @override
  State<FrostListRow> createState() => _FrostListRowState();
}

class _SkeletonListRow extends FrostListRow {
  _SkeletonListRow(this._icon, {required super.title, required String? subtitle, required super.value})
    : super(subtitle: subtitle == null ? null : FrostRowSubtitle(subtitle));
  final bool _icon;
  @override
  State<FrostListRow> createState() => _SkeletonRowState();
}

class _SkeletonRowState extends State<_SkeletonListRow> {
  @override
  Widget build(BuildContext context) => FrostListRow(
    title: widget.title,
    subtitle: widget.subtitle,
    value: widget._value,
    leading: widget._icon ? FrostGlyph.icon(FrostIconSet.of(context).empty) : null,
  ).frostSkeleton(true);
}

class _FrostListRowState extends State<FrostListRow> {
  FrostIconData? get _icon => switch (widget._leading) {
    FrostIconGlyph(:final icon) => icon,
    _ => null,
  };

  // An avatar glyph fills the icon slot, sized like the icon it replaces.
  Widget? get _leading => switch (widget._leading) {
    FrostCustomLeading(:final child) => child,
    FrostAvatarGlyph(:final avatar) => FrostIconSlot(size: FrostControlSize.regular.iconSize, child: avatar),
    _ => null,
  };
  final _focus = FocusNode();
  final _layout = FrostLayoutIdentity();
  FrostListItemHandle? _handle;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _bindHandle();
  }

  @override
  void didUpdateWidget(FrostListRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    _bindHandle();
  }

  void _bindHandle() {
    final handle = FrostListItemScope.of(context)?.handle;
    if (_handle != handle) {
      _handle?.activate = null;
      _handle = handle;
    }
    _handle?.activate = _activate;
  }

  void _activate() {
    if (!widget._enabled || !FrostControlScope.enabledOf(context)) return;
    final multiple = FrostSelectionPresentation.of(context);
    if (multiple != null) {
      multiple.activate(_originalAction);
      return;
    }
    _originalAction();
  }

  void _originalAction() {
    final selection = FrostListItemScope.of(context)?.onSelected;
    if (selection != null) {
      selection();
    } else if (widget._toggle case final value?) {
      widget._onChanged?.call(!value);
    } else {
      widget._onPressed?.call();
    }
  }

  @override
  void dispose() {
    _handle?.activate = null;
    _focus.dispose();
    _layout.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget._enabled && FrostControlScope.enabledOf(context);
    final item = FrostListItemScope.of(context);
    final content = FrostRowContent.of(context);
    final selected = content?.selected ?? widget.selected;
    final multiple = FrostSelectionPresentation.of(context);
    final interactive = enabled && (multiple != null || item?.onSelected != null || widget._onPressed != null || widget._onChanged != null);
    final checked = item?.selected ?? widget._checked;
    final placement = FrostRowPlacement.of(context);
    final inside = FrostKeyline.maybeOf(context)?.insideContainer ?? false;
    final tokens = FrostThemeTokens.of(context);
    final subtitle = widget.subtitle?.text;
    final (subtitleTone, subtitleStatus, inlineSubtitle, path, contentSubtitle, subtitleLines) = switch (widget.subtitle) {
      _TextSubtitle(:final tone, :final content, :final maxLines) => (tone, null, false, false, content, maxLines),
      _StatusSubtitle(:final tone, :final status, :final content, :final maxLines) => (tone, status, false, false, content, maxLines),
      _PathSubtitle() => (FrostTextTone.secondary, null, false, true, false, null),
      _InlineSubtitle(:final tone, :final content) => (tone, null, true, false, content, null),
      null => (FrostTextTone.secondary, null, false, false, false, null),
    };
    final subtitleColor = selected
        ? tokens.selectionInk
        : subtitleTone == FrostTextTone.secondary
        ? tokens.textSecondary
        : frostTextStyle(context, FrostTextRole.footnote, subtitleTone).color!;
    final density = FrostDensity.of(context);
    final rowSize = density.heightFor(FrostControlSize.regular) == 44 ? FrostControlSize.regular : FrostControlSize.compact;
    final geometry = frostControlGeometry(context, rowSize);
    final endButton = widget._trailing;
    // The wrappers depend only on the button, so a check, switch or accessory
    // appearing later changes their room, not the button's place in the tree.
    final endAligned = inside && endButton is FrostButton && !frostButtonIsIcon(endButton) && endButton.edgeAlignment == FrostButtonEdgeAlignment.end;
    final spendsEndPadding = endAligned && widget._accessory == FrostRowAccessory.none && checked == null && widget._toggle == null;
    Widget? cluster;
    if (widget._value != null || widget._trailing != null) {
      // A grouped row's keyline has no room outside its rows. A text button that
      // asks for end alignment may spend the row's own end padding, so its text
      // ends where the other rows' values end while its hit area reaches outward.
      final keyline = FrostKeyline.maybeOf(context);
      var trailing = widget._trailing;
      if (endAligned && keyline != null && trailing != null) {
        trailing = FrostKeyline(
          leadingRoom: keyline.leadingRoom,
          trailingRoom: spendsEndPadding ? FrostGap.of(context).rowInset : 0,
          edgeDistanceStart: keyline.edgeDistanceStart,
          edgeDistanceEnd: keyline.edgeDistanceEnd,
          insideContainer: true,
          contentStart: keyline.contentStart,
          child: trailing,
        );
      }
      cluster = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget._value case final value?)
            Flexible(
              child: ExcludeSemantics(
                child: _RowText(value, role: FrostTextRole.body, color: selected ? tokens.selectionInk : tokens.textSecondary),
              ),
            ),
          if (widget._value != null && widget._trailing != null) const SizedBox(width: FrostGap.related),
          if (trailing != null)
            Flexible(
              child: Semantics(
                container: true,
                child: FrostControlScope(
                  size: FrostControlSize.compact,
                  child: FrostRowTrailingAlignment(
                    // A lazy list's viewport only hit-tests inside itself, so its rows keep
                    // the whole trailing target in the row rather than bleeding it out.
                    enabled: widget._accessory == FrostRowAccessory.none && checked == null && widget._toggle == null && item == null,
                    child: trailing,
                  ),
                ),
              ),
            ),
        ],
      );
    }
    final ends = <Widget>[
      if (widget._toggle case final value?)
        ExcludeFocus(
          child: IgnorePointer(
            child: FrostSwitch(value: value, onChanged: (_) {}, semanticLabel: null),
          ),
        ),
      if (widget._accessory != FrostRowAccessory.none)
        FrostIcon(
          widget._accessory == FrostRowAccessory.chevron ? frostTrailingChevron(context) : FrostIconSet.of(context).externalLink,
          size: FrostControlSize.compact.iconSize,
          color: selected ? tokens.selectionInk : tokens.textTertiary,
        ),
      if (checked != null)
        SizedBox.square(
          dimension: FrostControlSize.regular.iconSize,
          child: FrostPresence(
            visible: checked,
            child: FrostIcon(FrostIconSet.of(context).check, size: FrostControlSize.regular.iconSize, color: tokens.selectionInk),
          ),
        ),
    ];
    // The button's end bleed lies outside its slot but inside the row; a boundary
    // routes hits there to it.
    Widget bleedRoom(Widget layout) => endAligned ? FrostBleedBoundary(child: layout) : layout;
    Widget row(BuildContext context) {
      final inset = inside
          ? EdgeInsets.symmetric(horizontal: FrostGap.of(context).rowInset)
          : (item?.viewportInset ?? frostBleedOutsetsOf(context)).resolve(Directionality.of(context));
      final direction = Directionality.of(context);
      // Standalone rows share one rounded surface for selection/hover/press.
      // Contiguous groups alone supply their outer/middle row corner geometry.
      final corners = placement?.corners ?? FrostRadius.borderRadius(FrostRadius.sm);
      final shape = switch (FrostRadius.shape(context, FrostRadius.sm)) {
        RoundedSuperellipseBorder() => RoundedSuperellipseBorder(borderRadius: corners),
        _ => RoundedRectangleBorder(borderRadius: corners),
      };
      final control = FrostClickHighlight(
        highlighted: enabled && (item?.highlighted ?? false),
        child: FrostClickSurface(
          focusNode: FrostRowFocus.of(context) ?? _focus,
          onTap: interactive ? _activate : null,
          // While selecting, a modified click extends the selection instead.
          onOpenInNewTab: interactive && multiple == null ? widget._onOpenInNewTab : null,
          onOpenInBackground: interactive && multiple == null ? widget._onOpenInBackground : null,
          onLongPress: enabled ? multiple?.longPress : null,
          shape: FrostClickShape.rounded(corners),
          child: FrostMotionSize(
            duration: FrostMotion.duration(context, FrostMotion.layoutFade),
            alignment: AlignmentDirectional.topStart,
            child: FrostTimedLayoutCrossfade(
              layoutIdentity: _layout,
              settleDuration: Duration.zero,
              child: bleedRoom(
                FrostRowLayout(
                  identity: _layout,
                  // Rich rows do not display subtitle; progress/detail changes must not
                  // crossfade their title through this unused fallback string.
                  contentIdentity: (widget.title, content == null ? subtitle : null, widget._value, widget._trailing?.key, inlineSubtitle, path),
                  keepValueInline: content != null || inlineSubtitle || FrostRowInlineValue.of(context),
                  minimumInlineTextWidth: content == null ? 0 : geometry.height - geometry.verticalInset * 2,
                  minimumHeight: rowSize.height(context),
                  verticalInset: geometry.verticalInset,
                  inset: inset,
                  direction: direction,
                  children: [
                    if (multiple != null)
                      FrostRowSlot(
                        id: FrostRowPart.selection,
                        child: FrostUserSelectionTrigger(
                          trigger: multiple.drawTrigger,
                          child: _SelectionColumn(active: multiple.active, selected: multiple.selected),
                        ),
                      ),
                    if (_leading != null || _icon != null || item?.reserveIconColumn == true)
                      FrostRowSlot(
                        id: FrostRowPart.leading,
                        includeSemantics: _leading != null,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minWidth: FrostRowLeadingExtent.of(context) ?? frostRowIconColumn),
                          child: Align(
                            // The page keyline aligns visible icon ink. Grouped
                            // rows retain the centred shared 28-point icon column. A list-wide
                            // leading extent centres every row's content instead.
                            alignment: !inside && FrostKeyline.maybeOf(context) != null && _leading == null && FrostRowLeadingExtent.of(context) == null
                                ? AlignmentDirectional.centerStart
                                : Alignment.center,
                            widthFactor: 1,
                            heightFactor: 1,
                            child:
                                _leading ??
                                (_icon == null
                                    ? const SizedBox.shrink()
                                    : FrostIcon(_icon!, size: FrostControlSize.regular.iconSize, color: selected ? tokens.selectionInk : tokens.textSecondary)),
                          ),
                        ),
                      ),
                    FrostRowSlot(
                      id: FrostRowPart.text,
                      child: inlineSubtitle && content == null && subtitle != null
                          ? FrostInlineRowText(
                              key: placement?.textAnchor ?? multiple?.textAnchor,
                              direction: direction,
                              title: _RowText(
                                widget.title,
                                role: FrostTextRole.body,
                                color: selected ? tokens.selectionInk : (widget._destructive ? tokens.negativeInk : tokens.textPrimary),
                                content: widget.contentTitle,
                              ),
                              subtitle: _RowText(subtitle, role: FrostTextRole.footnote, color: subtitleColor, content: contentSubtitle, singleLine: true),
                            )
                          : Column(
                              key: placement?.textAnchor ?? multiple?.textAnchor,
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _RowText(
                                  widget.title,
                                  role: FrostTextRole.body,
                                  color: selected ? tokens.selectionInk : (widget._destructive ? tokens.negativeInk : tokens.textPrimary),
                                  content: widget.contentTitle,
                                ),
                                if (content != null)
                                  content.belowTitle
                                else if (subtitle case final subtitle?) ...[
                                  const SizedBox(height: _rowTextGap),
                                  if (path)
                                    AnimatedDefaultTextStyle(
                                      style: FrostTypography.of(context).style(FrostTextRole.footnote, tabular: true).copyWith(color: subtitleColor),
                                      duration: FrostMotion.duration(context, FrostMotion.hover),
                                      child: FrostPathText(subtitle, role: FrostTextRole.footnote),
                                    )
                                  else
                                    _RowSubtitle(subtitle, status: subtitleStatus, color: subtitleColor, content: contentSubtitle, maxLines: subtitleLines),
                                ],
                              ],
                            ),
                    ),
                    if (cluster != null) FrostRowSlot(id: FrostRowPart.value, includeSemantics: true, child: cluster),
                    if (ends.isNotEmpty)
                      FrostRowSlot(
                        id: FrostRowPart.end,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (var i = 0; i < ends.length; i++) ...[if (i > 0) const SizedBox(width: FrostGap.related), ends[i]],
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      // Row selection uses the same surface and interaction geometry. Put
      // the fill behind the click surface so hover/press feedback remains live.
      final grouped = placement?.corners != null;
      final selectedControl = AnimatedContainer(
        duration: FrostMotion.duration(context, FrostMotion.hover),
        curve: FrostMotion.hoverCurve,
        decoration: grouped
            ? BoxDecoration(color: tokens.selectionFill.withValues(alpha: selected ? tokens.selectionFill.a : 0))
            : ShapeDecoration(
                color: tokens.selectionFill.withValues(alpha: selected ? tokens.selectionFill.a : 0),
                shape: shape,
              ),
        // Contiguous groups fill their complete target so compact content does
        // not introduce seams between a row and the shared outer outline.
        child: placement?.corners == null
            ? control
            : ConstrainedBox(
                constraints: BoxConstraints(minHeight: density.targetHeight),
                child: control,
              ),
      );
      return grouped ? FrostClickSurfaceVisuals.grouped(child: selectedControl) : selectedControl;
    }

    Widget accessibleRow(BuildContext context) {
      Widget control = GestureDetector(
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onTap: interactive ? _activate : null,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: density.targetHeight),
          child: Align(heightFactor: 1, child: row(context)),
        ),
      );
      control = Semantics(
        label: widget.title,
        value: content?.semanticValue ?? (inlineSubtitle ? [subtitle, widget._value].nonNulls.join(', ') : widget._value ?? subtitle),
        button: interactive,
        toggled: widget._toggle,
        selected: selected,
        checked: multiple?.active == true ? multiple!.selected : (widget._toggle == null ? checked : null),
        enabled: enabled ? (interactive ? true : null) : false,
        onTap: interactive ? _activate : null,
        container: widget._trailing != null || _leading != null,
        explicitChildNodes: widget._trailing != null || _leading != null,
        excludeSemantics: widget._trailing == null && _leading == null,
        child: ExcludeFocus(
          excluding: !enabled,
          child: IgnorePointer(
            ignoring: !enabled,
            child: FrostAnimatedMaterialReveal(
              opacity: enabled ? 1 : _rowDisabledOpacity,
              duration: FrostMotion.duration(context, FrostMotion.hover),
              child: control,
            ),
          ),
        ),
      );
      final entries = [...widget._contextMenu, ...FrostAdditionalMenuEntries.of(context)];
      if (entries.isNotEmpty) control = FrostContextMenuRegion(entries: entries, enabled: enabled, child: control);
      return multiple == null ? control : MetaData(metaData: frostSelectionInputTarget, behavior: HitTestBehavior.translucent, child: control);
    }

    // Put semantics and focus inside the expanded hit box. A scrolling list
    // already expands its viewport and supplies the same granted content inset.
    return FrostPickerRowScope(
      child: inside || item != null
          ? Builder(builder: accessibleRow)
          : FrostBleed(
              amount: FrostGap.of(context).hitInset,
              child: Builder(builder: accessibleRow),
            ),
    );
  }
}

class _RowText extends StatelessWidget {
  const _RowText(this.text, {required this.role, required this.color, bool singleLine = false, int? maxLines, this.content = false})
    : maxLines = singleLine ? 1 : maxLines;
  final bool content;
  final int? maxLines;
  final String text;
  final FrostTextRole role;
  final Color color;
  @override
  Widget build(BuildContext context) => AnimatedDefaultTextStyle(
    style: FrostTypography.of(context).style(role, tabular: true).copyWith(color: color),
    duration: FrostMotion.duration(context, FrostMotion.hover),
    curve: FrostMotion.hoverCurve,
    child: FrostSkeletonText(
      child: Text(
        text,
        style: content ? frostContentTextStyle(context, text) : null,
        maxLines: maxLines,
        overflow: maxLines == null ? null : TextOverflow.ellipsis,
      ),
    ),
  );
}

class _SelectionColumn extends StatelessWidget {
  const _SelectionColumn({required this.active, required this.selected});
  final bool active, selected;
  @override
  Widget build(BuildContext context) {
    final column = Padding(
      padding: const EdgeInsetsDirectional.only(end: FrostGap.related),
      child: SizedBox(
        width: frostRowIconColumn,
        child: Center(
          child: ExcludeFocus(
            child: IgnorePointer(
              child: FrostCheckbox(value: selected, onChanged: (_) {}, semanticLabel: null),
            ),
          ),
        ),
      ),
    );
    if (MediaQuery.disableAnimationsOf(context)) {
      return FrostPresence(visible: active, effect: FrostPresenceEffect.expand, axis: Axis.horizontal, child: column);
    }
    return FrostSpringBuilder(
      value: active ? 1 : 0,
      spring: FrostMotion.standard,
      builder: (_, progress, child) => ClipRect(
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          widthFactor: progress.clamp(0.0, 1.0),
          heightFactor: 1,
          child: Opacity(opacity: progress.clamp(0.0, 1.0), child: child),
        ),
      ),
      child: ExcludeSemantics(excluding: !active, child: column),
    );
  }
}

class _RowSubtitle extends StatelessWidget {
  const _RowSubtitle(this.text, {required this.status, required this.color, required this.content, required this.maxLines});
  final String text;
  final int? maxLines;
  final bool content;
  final FrostStatusTone? status;
  final Color color;
  @override
  Widget build(BuildContext context) {
    final label = _RowText(text, role: FrostTextRole.footnote, color: color, content: content, maxLines: maxLines);
    if (status == null) return label;
    final style = FrostTypography.of(context).style(FrostTextRole.footnote, tabular: true);
    return _StatusSubtitleLayout(
      text: text,
      style: content ? frostContentTextStyle(context, text, style) : style,
      scaler: MediaQuery.textScalerOf(context),
      direction: Directionality.of(context),
      children: [
        FrostStatusDot(tone: status!),
        label,
      ],
    );
  }
}

class _StatusSubtitleData extends ContainerBoxParentData<RenderBox> {}

/// Measures the same wrapped first line before placing the decorative dot.
/// A pre-build unbounded measurement has different leading for multiline text.
class _StatusSubtitleLayout extends MultiChildRenderObjectWidget {
  const _StatusSubtitleLayout({required this.text, required this.style, required this.scaler, required this.direction, required super.children});
  final String text;
  final TextStyle style;
  final TextScaler scaler;
  final TextDirection direction;
  @override
  RenderObject createRenderObject(BuildContext context) => _RenderStatusSubtitle(this);
  @override
  void updateRenderObject(BuildContext context, _RenderStatusSubtitle renderObject) => renderObject.update(this);
}

class _RenderStatusSubtitle extends RenderBox
    with ContainerRenderObjectMixin<RenderBox, _StatusSubtitleData>, RenderBoxContainerDefaultsMixin<RenderBox, _StatusSubtitleData> {
  _RenderStatusSubtitle(this.spec);
  _StatusSubtitleLayout spec;
  double get start => frostStatusDotExtent + FrostGap.related;
  void update(_StatusSubtitleLayout value) {
    spec = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _StatusSubtitleData) child.parentData = _StatusSubtitleData();
  }

  @override
  double computeMaxIntrinsicWidth(double height) => start + lastChild!.getMaxIntrinsicWidth(height);
  @override
  double computeMinIntrinsicWidth(double height) => start + lastChild!.getMinIntrinsicWidth(height);
  @override
  double computeMaxIntrinsicHeight(double width) => math.max(frostStatusDotExtent, lastChild!.getMaxIntrinsicHeight(math.max(0, width - start)));
  @override
  double computeMinIntrinsicHeight(double width) => computeMaxIntrinsicHeight(width);
  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final width = constraints.hasBoundedWidth ? constraints.maxWidth : computeMaxIntrinsicWidth(double.infinity);
    final text = lastChild!.getDryLayout(BoxConstraints(maxWidth: math.max(0, width - start)));
    return constraints.constrain(Size(width, math.max(frostStatusDotExtent, text.height)));
  }

  @override
  void performLayout() {
    final width = constraints.hasBoundedWidth ? constraints.maxWidth : computeMaxIntrinsicWidth(double.infinity);
    final dot = firstChild!, label = lastChild!;
    dot.layout(const BoxConstraints.tightFor(width: frostStatusDotExtent, height: frostStatusDotExtent), parentUsesSize: true);
    label.layout(BoxConstraints(maxWidth: math.max(0, width - start)), parentUsesSize: true);
    final painter = TextPainter(
      text: TextSpan(text: spec.text, style: spec.style),
      textDirection: spec.direction,
      textScaler: spec.scaler,
    )..layout(maxWidth: label.size.width);
    final firstLine = painter
        .getBoxesForSelection(TextSelection(baseOffset: 0, extentOffset: spec.text.length), boxHeightStyle: BoxHeightStyle.includeLineSpacingMiddle)
        .firstOrNull;
    final center = firstLine?.toRect().center.dy ?? painter.preferredLineHeight / 2;
    painter.dispose();
    final top = math.max(0.0, center - frostStatusDotExtent / 2);
    size = constraints.constrain(Size(width, math.max(label.size.height, top + frostStatusDotExtent)));
    (dot.parentData! as _StatusSubtitleData).offset = Offset(spec.direction == TextDirection.ltr ? 0 : width - frostStatusDotExtent, top);
    (label.parentData! as _StatusSubtitleData).offset = Offset(spec.direction == TextDirection.ltr ? start : 0, 0);
  }

  @override
  void paint(PaintingContext context, Offset offset) => defaultPaint(context, offset);
  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) => defaultHitTestChildren(result, position: position);
}
