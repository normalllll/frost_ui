import 'package:flutter/widgets.dart';

import '../display/status_dot.dart';
import '../foundation/_control_geometry.dart';
import '../foundation/control_scope.dart';
import '../foundation/density.dart';
import '../foundation/fonts.dart';
import '../foundation/radius.dart';
import '../foundation/sizes.dart';
import '../foundation/spacing.dart';
import '../foundation/tokens.dart';
import '../foundation/typography.dart';
import '../lists/_row_scope.dart';
import '../lists/list_row.dart';
import '../motion/_selection_feedback.dart';
import '../overlays/context_menu.dart';
import '../overlays/menu_entry.dart';
import '../overlays/tooltip.dart';
import '../primitives/_icon_slot.dart';
import '../primitives/_measured_layout_builder.dart';
import '../primitives/_path_elision.dart';
import '../primitives/click_surface.dart';
import '../primitives/glyph.dart';
import '../primitives/icon.dart';
import '../primitives/keyline.dart';
import '../primitives/text.dart';

/// Where a navigation row's text (or leading content) starts inside its
/// selection fill: the settings section list's label inset.
const frostNavigationRowTextStart = 14.0;
const _textEnd = 8.0, _leadingGap = 12.0, _subtitleGap = 2.0, _twoLineInset = 6.0;

/// One object in the column of a [FrostNavigationColumnLayout], such as a
/// repository or an account: the selection look, height and text line of the
/// settings section list, with an optional [subtitle], [leading] content and
/// [trailing] control. The title and subtitle stay on one line and show their
/// full text in a tooltip when shortened. Up and down arrows move focus
/// between the rows of one column.
///
/// Put rows in a FrostContentColumn (or FrostSliverContentColumn) inside the
/// column's scroll view: the column's keyline is the row text line, so section
/// headers there start where row text starts.
class FrostNavigationColumnRow extends StatefulWidget {
  const FrostNavigationColumnRow({
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.contentTitle = false,
    this.selected = false,
    this.onPressed,
    this.contextMenu = const [],
    super.key,
  });
  final String title;
  final FrostRowSubtitle? subtitle;

  /// Drawn in a slot as wide as the nearest FrostRowLeadingExtent, or an icon.
  final FrostLeading? leading;
  final Widget? trailing;

  /// Marks the title as content text (see FrostText.content).
  final bool contentTitle;
  final bool selected;
  final VoidCallback? onPressed;
  final List<FrostMenuEntry> contextMenu;

  @override
  State<FrostNavigationColumnRow> createState() => _NavigationColumnRowState();
}

class _NavigationColumnRowState extends State<FrostNavigationColumnRow> {
  final _focus = FocusNode();
  _NavigationColumnFocusState? _column;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final column = context.getInheritedWidgetOfExactType<_ColumnRows>()?.state;
    if (column == _column) return;
    _column?._rows.remove(_focus);
    _column = column?.._rows.add(_focus);
  }

  @override
  void dispose() {
    _column?._rows.remove(_focus);
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = FrostThemeTokens.of(context);
    final typography = FrostTypography.of(context);
    final titleStyle = typography.style(FrostTextRole.callout);
    final single = frostControlTextGeometry(baseHeight: FrostDensity.of(context).targetHeight, style: titleStyle, textScaler: MediaQuery.textScalerOf(context));
    final subtitle = widget.subtitle;
    final parts = subtitle == null ? null : frostRowSubtitleParts(subtitle);
    final radius = BorderRadius.circular(FrostRadius.sm);
    final selected = widget.selected;
    final enabled = widget.onPressed != null && FrostControlScope.enabledOf(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The fill reaches back from the column keyline to the list's own inset.
        FrostButtonEdgeBleed(
          amount: frostNavigationRowTextStart,
          start: true,
          child: FrostSelectionFeedback(
            selected: selected,
            foreground: selected ? tokens.selectionInk : tokens.textPrimary,
            background: selected ? tokens.selectionFill : tokens.selectionFill.withValues(alpha: 0),
            builder: (context, ink, fill, _) {
              final Widget? leading = switch (widget.leading) {
                FrostCustomLeading(:final child) => child,
                FrostAvatarGlyph(:final avatar) => FrostIconSlot(size: FrostControlSize.regular.iconSize, child: avatar),
                FrostIconGlyph(:final icon) => FrostIcon(icon, size: FrostControlSize.regular.iconSize, color: ink),
                null => null,
              };
              final title = titleStyle.copyWith(color: ink);
              final subtitleStyle = parts == null
                  ? null
                  : typography
                        .style(FrostTextRole.footnote, tabular: parts.path)
                        .copyWith(
                          color: selected
                              ? tokens.selectionInk
                              : parts.tone == FrostTextTone.secondary
                              ? tokens.textSecondary
                              : frostTextStyle(context, FrostTextRole.footnote, parts.tone).color,
                        );
              final text = Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _OneLine(widget.title, style: widget.contentTitle ? frostContentTextStyle(context, widget.title, title) : title),
                  if (subtitle != null && subtitleStyle != null) ...[
                    const SizedBox(height: _subtitleGap),
                    _subtitle(context, subtitle.text, parts!, subtitleStyle),
                  ],
                ],
              );
              Widget row = Semantics(
                button: widget.onPressed != null,
                selected: selected,
                enabled: widget.onPressed != null ? enabled : null,
                onTap: enabled ? widget.onPressed : null,
                label: widget.title,
                value: subtitle?.text,
                container: true,
                explicitChildNodes: widget.trailing != null,
                excludeSemantics: widget.trailing == null,
                child: DecoratedBox(
                  decoration: BoxDecoration(color: fill, borderRadius: radius),
                  child: FrostClickSurface(
                    focusNode: _focus,
                    shape: FrostClickShape.rounded(radius),
                    onTap: widget.onPressed,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: single.height),
                      child: Padding(
                        padding: EdgeInsetsDirectional.only(
                          start: frostNavigationRowTextStart,
                          end: _textEnd,
                          top: subtitle == null ? single.verticalInset : _twoLineInset,
                          bottom: subtitle == null ? single.verticalInset : _twoLineInset,
                        ),
                        child: Row(
                          children: [
                            if (leading != null) ...[
                              // A minimum, so a leading wider than the slot, such as an avatar,
                              // widens it instead of being squeezed.
                              ConstrainedBox(
                                constraints: BoxConstraints(minWidth: FrostRowLeadingExtent.of(context) ?? FrostControlSize.regular.iconSize),
                                child: Center(child: ExcludeSemantics(child: leading)),
                              ),
                              const SizedBox(width: _leadingGap),
                            ],
                            Expanded(child: ExcludeSemantics(child: text)),
                            if (widget.trailing case final trailing?) ...[
                              const SizedBox(width: FrostGap.related),
                              FrostControlScope(size: FrostControlSize.compact, child: trailing),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
              if (widget.contextMenu.isNotEmpty) row = FrostContextMenuRegion(entries: widget.contextMenu, child: row);
              return row;
            },
          ),
        ),
        // The gap under a row answers for it, so a touch has no dead line.
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: true,
          onTap: enabled ? widget.onPressed : null,
          child: const SizedBox(height: FrostGap.inline),
        ),
      ],
    );
  }

  Widget _subtitle(BuildContext context, String text, ({FrostTextTone tone, FrostStatusTone? status, bool content, bool path}) parts, TextStyle style) {
    final line = _OneLine(text, style: parts.content ? frostContentTextStyle(context, text, style) : style, path: parts.path);
    if (parts.status case final status?) {
      return Row(
        children: [
          FrostStatusDot(tone: status),
          const SizedBox(width: FrostGap.related),
          Expanded(child: line),
        ],
      );
    }
    return line;
  }
}

/// One line that ends in an ellipsis, or a [path] shortened in the middle,
/// with its full text in a tooltip only when it is shortened.
class _OneLine extends StatelessWidget {
  const _OneLine(this.text, {required this.style, this.path = false});
  final String text;
  final TextStyle style;
  final bool path;
  @override
  Widget build(BuildContext context) {
    final lineSize = frostTextLineSize(context, text, style);
    return FrostMeasuredLayoutBuilder(
      naturalSize: lineSize,
      builder: (context, constraints) {
        final shortened = lineSize.width > constraints.maxWidth;
        final shown = path && shortened ? frostElidePathMiddle(text, constraints.maxWidth, (value) => frostTextLineSize(context, value, style).width) : text;
        final line = Text(shown, style: style, maxLines: 1, softWrap: false, overflow: TextOverflow.ellipsis);
        return shortened ? FrostTooltip(message: text, excludeFromSemantics: true, child: line) : line;
      },
    );
  }
}

/// Library-only: up and down arrows move focus between the
/// [FrostNavigationColumnRow]s below it that can take focus, in their visual
/// order, and scroll the focused row into view. Rows inside collapsed sections
/// cannot take focus and are skipped.
class FrostNavigationColumnFocus extends StatefulWidget {
  const FrostNavigationColumnFocus({required this.child, super.key});
  final Widget child;
  @override
  State<FrostNavigationColumnFocus> createState() => _NavigationColumnFocusState();
}

class _NavigationColumnFocusState extends State<FrostNavigationColumnFocus> {
  final _rows = <FocusNode>{};

  /// Up and Down (Flutter's directional focus keys) step through the rows and
  /// stop at the column's ends; other directions keep Flutter's behaviour.
  Object? _move(DirectionalFocusIntent intent) {
    final delta = switch (intent.direction) {
      TraversalDirection.down => 1,
      TraversalDirection.up => -1,
      _ => 0,
    };
    final rows = _rows.where((node) => node.context != null && node.canRequestFocus).toList()..sort((a, b) => a.rect.top.compareTo(b.rect.top));
    final index = rows.indexWhere((node) => node.hasFocus);
    if (delta == 0 || index < 0) {
      primaryFocus?.focusInDirection(intent.direction);
      return null;
    }
    final target = rows[(index + delta).clamp(0, rows.length - 1)];
    target.requestFocus();
    if (target.context case final targetContext?) Scrollable.ensureVisible(targetContext);
    return null;
  }

  @override
  Widget build(BuildContext context) => _ColumnRows(
    state: this,
    child: Actions(
      actions: {DirectionalFocusIntent: CallbackAction<DirectionalFocusIntent>(onInvoke: _move)},
      child: widget.child,
    ),
  );
}

class _ColumnRows extends InheritedWidget {
  const _ColumnRows({required this.state, required super.child});
  final _NavigationColumnFocusState state;
  @override
  bool updateShouldNotify(_ColumnRows oldWidget) => state != oldWidget.state;
}
