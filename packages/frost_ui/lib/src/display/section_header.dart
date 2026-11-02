import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../controls/_button_control.dart' show frostButtonTextInset;
import '../controls/buttons.dart';
import '../feedback/_skeleton_geometry.dart';
import '../foundation/_control_geometry.dart';
import '../foundation/control_scope.dart';
import '../foundation/density.dart';
import '../foundation/metrics.dart';
import '../foundation/radius.dart';
import '../foundation/scope.dart';
import '../foundation/sizes.dart';
import '../foundation/spacing.dart';
import '../foundation/tokens.dart';
import '../foundation/typography.dart';
import '../motion/layout_crossfade.dart';
import '../overlays/tooltip.dart';
import '../primitives/_directional_icon.dart';
import '../primitives/_measured_layout_builder.dart';
import '../primitives/_path_elision.dart';
import '../primitives/click_surface.dart';
import '../primitives/divider.dart';
import '../primitives/icon.dart';
import '../primitives/keyline.dart';
import '../primitives/surface.dart';
import '_disclosure_body.dart';
import '_header_actions.dart';

/// A section title with same-row compact actions. Content stays on its keyline;
/// the last button's content edge spends its own padding outside that line.
class FrostSectionHeader extends StatelessWidget {
  const FrostSectionHeader({required this.title, this.actionLabel, this.onAction, this.trailing = const [], this.pathTitle = false, super.key})
    : expanded = null,
      onExpansionChanged = null,
      child = null;

  /// A rounded panel containing its header, actions and revealed [child].
  /// The spacious header toggles the panel; [trailing] stays inside its surface
  /// with independent actions. Collapsed content takes no focus or semantics. The
  /// caller owns [expanded]; a null [onExpansionChanged] disables the toggle.
  const FrostSectionHeader.collapsible({
    required this.title,
    required bool this.expanded,
    required this.onExpansionChanged,
    required Widget this.child,
    this.trailing = const [],
    this.pathTitle = false,
    super.key,
  }) : actionLabel = null,
       onAction = null;

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final List<Widget> trailing;

  /// Shows [title] as a path: one line in tabular figures, shortened in the
  /// middle when it does not fit, with the full path in a tooltip.
  final bool pathTitle;

  /// Whether [child] shows; null on a header that does not collapse.
  final bool? expanded;
  final ValueChanged<bool>? onExpansionChanged;
  final Widget? child;

  @override
  Widget build(BuildContext context) => child == null ? _header(context) : _panel(context);

  Widget _panel(BuildContext context) {
    const inset = FrostGap.panelInset;
    final tokens = FrostThemeTokens.of(context);
    final style = FrostTypography.of(context).style(FrostTextRole.headline, tabular: pathTitle).copyWith(color: tokens.textPrimary);
    final onToggle = onExpansionChanged == null || !FrostControlScope.enabledOf(context) ? null : () => onExpansionChanged!(!expanded!);
    final toggle = Semantics(
      container: true,
      label: title,
      button: true,
      enabled: onToggle != null,
      expanded: expanded,
      onTap: onToggle,
      excludeSemantics: true,
      child: FrostClickSurface(
        onTap: onToggle,
        // The header is part of the panel, not a pill-shaped button on it.
        shape: const FrostClickShape.rounded(BorderRadius.zero),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: FrostControlSize.regular.height(context) + FrostGap.panelInset),
          child: Padding(
            padding: const EdgeInsets.all(inset),
            child: Row(
              children: [
                Expanded(
                  child: FrostSkeletonText(
                    child: pathTitle ? _PathTitle(title, style: style) : Text(title, style: style),
                  ),
                ),
                const SizedBox(width: FrostGap.related),
                AnimatedRotation(
                  turns: expanded! ? frostDisclosureTurns(context) : 0,
                  duration: FrostMotion.duration(context, FrostMotion.feedback),
                  curve: FrostMotion.hoverCurve,
                  child: FrostIcon(frostTrailingChevron(context), size: FrostControlSize.regular.iconSize, color: tokens.textSecondary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return FrostSurface(
      role: FrostSurfaceRole.module,
      borderRadius: FrostRadius.borderRadius(FrostRadius.lg),
      child: FrostKeyline(
        leadingRoom: 0,
        trailingRoom: 0,
        edgeDistanceStart: 0,
        edgeDistanceEnd: 0,
        insideContainer: true,
        contentStart: 0,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (trailing.isEmpty)
              toggle
            else
              FrostHeaderActions(
                direction: Directionality.of(context),
                leading: toggle,
                actions: Padding(
                  padding: const EdgeInsetsDirectional.only(end: FrostGap.related, top: FrostGap.related, bottom: FrostGap.related),
                  child: FrostControlScope(
                    size: FrostControlSize.compact,
                    child: Wrap(
                      spacing: FrostGap.related,
                      runSpacing: FrostGap.related,
                      alignment: WrapAlignment.end,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: trailing,
                    ),
                  ),
                ),
              ),
            FrostDisclosureBody(
              expanded: expanded!,
              gap: 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const FrostDivider(),
                  FrostBleedBoundary(
                    child: Padding(
                      padding: const EdgeInsets.all(inset),
                      // This is an already-inset content line. Rows may use the
                      // inner margin for feedback but cannot leave the card.
                      child: FrostKeyline(
                        leadingRoom: inset,
                        trailingRoom: inset,
                        edgeDistanceStart: inset,
                        edgeDistanceEnd: inset,
                        insideContainer: false,
                        contentStart: 0,
                        child: child!,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    final style = FrostTypography.of(context).style(FrostTextRole.headline, tabular: pathTitle).copyWith(fontSize: 15);
    final geometry = frostControlTextGeometry(baseHeight: 22, style: style, textScaler: MediaQuery.textScalerOf(context));
    final actions = <Widget>[
      if (onAction != null)
        FrostButton.quiet(
          edgeAlignment: FrostButtonEdgeAlignment.end,
          label: actionLabel ?? FrostScope.labelsOf(context).showAll,
          size: FrostControlSize.compact,
          onPressed: onAction,
        ),
      ...trailing,
    ];
    final last = actions.lastOrNull;
    final edge = switch (last) {
      FrostButton(:final size) && final button when frostButtonIsIcon(button) =>
        (math.max((size ?? FrostControlSize.compact).height(context), FrostDensity.of(context).targetHeight) - (size ?? FrostControlSize.compact).iconSize) / 2,
      FrostButton(:final size) => frostButtonTextInset(size ?? FrostControlSize.compact),
      _ => 0.0,
    };
    Widget contents(BuildContext context) {
      final granted = frostBleedOutsetsOf(context).resolve(Directionality.of(context));
      final rtl = Directionality.of(context) == TextDirection.rtl;
      final end = rtl ? granted.left : granted.right;
      final color = FrostThemeTokens.of(context).textPrimary;
      final titleBlock = Padding(
        padding: EdgeInsets.symmetric(vertical: geometry.verticalInset),
        child: FrostSkeletonText(
          child: pathTitle
              ? _PathTitle(title, style: style.copyWith(color: color))
              : Text(
                  title,
                  style: style.copyWith(color: color),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
        ),
      );
      return Padding(
        padding: EdgeInsetsDirectional.only(end: math.max(0, end - edge)),
        // Every header reserves the action row, so content below keeps the same
        // distance from the title whether or not the header has actions.
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: math.max(geometry.height, FrostDensity.of(context).targetHeight)),
          child: actions.isEmpty
              ? Align(alignment: AlignmentDirectional.centerStart, widthFactor: 1, child: titleBlock)
              : FrostHeaderActions(
                  direction: Directionality.of(context),
                  leading: titleBlock,
                  // Spend the keyline edge budget once, outside the action group.
                  actions: FrostKeyline(
                    leadingRoom: 0,
                    trailingRoom: 0,
                    edgeDistanceStart: 0,
                    edgeDistanceEnd: 0,
                    insideContainer: true,
                    contentStart: 0,
                    child: FrostControlScope(
                      size: FrostControlSize.compact,
                      child: Wrap(crossAxisAlignment: WrapCrossAlignment.center, alignment: WrapAlignment.end, runSpacing: FrostGap.related, children: actions),
                    ),
                  ),
                ),
        ),
      );
    }

    return FrostButtonEdgeBleed(
      amount: edge,
      start: false,
      child: FrostMotionSize(
        duration: FrostMotion.duration(context, FrostMotion.layoutFade),
        alignment: AlignmentDirectional.topStart,
        child: Builder(builder: contents),
      ),
    );
  }
}

/// One line of path text, shortened in the middle to fit, with the full path
/// in a tooltip and in semantics.
class _PathTitle extends StatelessWidget {
  const _PathTitle(this.path, {required this.style});
  final String path;
  final TextStyle style;
  @override
  Widget build(BuildContext context) => FrostMeasuredLayoutBuilder(
    naturalSize: frostTextLineSize(context, path, style),
    builder: (context, constraints) => FrostTooltip(
      message: path,
      excludeFromSemantics: true,
      child: Text(
        frostElidePathMiddle(path, constraints.maxWidth, (text) => frostTextLineSize(context, text, style).width),
        style: style,
        maxLines: 1,
        softWrap: false,
        semanticsLabel: path,
      ),
    ),
  );
}
