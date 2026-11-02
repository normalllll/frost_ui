import 'package:flutter/widgets.dart';

import '../controls/buttons.dart';
import '../display/_status_metrics.dart';
import '../display/status_dot.dart';
import '../feedback/_skeleton_geometry.dart';
import '../feedback/progress.dart';
import '../foundation/control_scope.dart';
import '../foundation/icon_data.dart';
import '../foundation/metrics.dart';
import '../foundation/scope.dart';
import '../foundation/sizes.dart';
import '../foundation/spacing.dart';
import '../foundation/tokens.dart';
import '../foundation/typography.dart';
import '../overlays/menu_entry.dart';
import '../primitives/glyph.dart';
import '../primitives/presence.dart';
import '_row_content.dart';
import 'list_row.dart';

const _taskVisibleActions = 2;

enum FrostTaskStatus { queued, running, paused, completed, failed, cancelled }

/// Position of a task's progress relative to its secondary detail text.
enum FrostTaskProgressPlacement { aboveDetail, belowDetail }

class FrostTaskAction {
  const FrostTaskAction({required this.label, required this.icon, required this.onPressed});
  final String label;
  final FrostIconData icon;
  final VoidCallback onPressed;
}

/// A shared list row with rich secondary content. The first two actions stay
/// visible; remaining actions join [contextMenu]. The application owns task
/// state, image loading, retry/cancel operations and localized detail text.
class FrostTaskRow extends StatelessWidget {
  const FrostTaskRow({
    required this.title,
    required this.status,
    this.contentTitle = false,
    this.detail,
    this.selected = false,
    this.progress,
    this.thumbnail,
    this.showsStatusDot = true,
    this.progressPlacement = FrostTaskProgressPlacement.aboveDetail,
    this.actions = const [],
    this.trailing,
    this.onPressed,
    this.contextMenu = const [],
    super.key,
  });

  /// Highlights the main row without entering checkbox selection mode.
  /// Activation and independent task actions retain their ordinary behavior.
  final bool selected;
  final String title;

  /// The title is content text (see [FrostText.content]), such as a name from
  /// the App's data. The detail line stays interface text.
  final bool contentTitle;
  final FrostTaskStatus status;
  final String? detail;

  /// Shown while running or paused. A queued task with progress keeps the bar's
  /// room, unpainted, so starting it does not move the rows below.
  final double? progress;

  /// Self-sized artwork, typically a FrostThumbnail. The row preserves its
  /// dimensions and clipping; custom artwork must provide finite dimensions.
  final Widget? thumbnail;

  /// Hides only the painted status dot; status remains in the row's semantics.
  final bool showsStatusDot;
  final FrostTaskProgressPlacement progressPlacement;
  final List<FrostTaskAction> actions;

  /// Independent controls inside the full row background. Keep a fixed slot
  /// when hiding hover-only controls so text and progress do not reflow.
  final Widget? trailing;
  final VoidCallback? onPressed;
  final List<FrostMenuEntry> contextMenu;
  @override
  Widget build(BuildContext context) {
    final labels = FrostScope.labelsOf(context), tokens = FrostThemeTokens.of(context);
    final (label, tone) = switch (status) {
      FrostTaskStatus.queued => (labels.taskQueued, FrostStatusTone.neutral),
      FrostTaskStatus.running => (labels.taskRunning, FrostStatusTone.accent),
      FrostTaskStatus.paused => (labels.taskPaused, FrostStatusTone.caution),
      FrostTaskStatus.completed => (labels.taskCompleted, FrostStatusTone.positive),
      FrostTaskStatus.failed => (labels.taskFailed, FrostStatusTone.negative),
      FrostTaskStatus.cancelled => (labels.taskCancelled, FrostStatusTone.neutral),
    };
    final showProgress = progress != null && (status == FrostTaskStatus.running || status == FrostTaskStatus.paused);
    // A queued task with progress keeps the bar's room, so starting it moves nothing.
    final reservesProgress = progress != null && status == FrostTaskStatus.queued;
    final entries = [
      ...contextMenu,
      for (final action in actions.skip(_taskVisibleActions))
        FrostMenuAction(action.label, leading: FrostGlyph.icon(action.icon), onSelected: action.onPressed),
    ];
    Widget progressView() => FrostPresence(
      key: const ValueKey('task-progress'),
      visible: showProgress || reservesProgress,
      effect: FrostPresenceEffect.expand,
      alignment: AlignmentDirectional.topStart,
      child: Padding(
        padding: EdgeInsets.only(
          top: progressPlacement == FrostTaskProgressPlacement.belowDetail ? FrostGap.inline : 0,
          bottom: progressPlacement == FrostTaskProgressPlacement.aboveDetail ? FrostGap.inline : 0,
        ),
        child: ExcludeSemantics(
          excluding: reservesProgress,
          child: AnimatedOpacity(
            opacity: reservesProgress ? 0 : 1,
            duration: FrostMotion.duration(context, FrostMotion.hover),
            curve: FrostMotion.hoverCurve,
            child: FrostProgressBar(value: progress ?? 0, semanticLabel: label),
          ),
        ),
      ),
    );
    final controls = actions.isEmpty && trailing == null
        ? null
        : Wrap(
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final action in actions.take(_taskVisibleActions))
                FrostButton.icon(
                  label: action.label,
                  icon: action.icon,
                  size: FrostControlSize.compact,
                  onPressed: FrostControlScope.enabledOf(context) ? action.onPressed : null,
                ),
              ?trailing,
            ],
          );
    final row = FrostRowContent(
      selected: selected,
      semanticValue: [label, ?detail, if (showProgress) '${(progress!.clamp(0.0, 1.0) * 100).round()}%'].join(' · '),
      belowTitle: Padding(
        padding: const EdgeInsets.only(top: FrostGap.inline),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (progressPlacement == FrostTaskProgressPlacement.aboveDetail) progressView(),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (showsStatusDot) ...[
                  Semantics(
                    label: label,
                    excludeSemantics: true,
                    child: FrostStatusDot(tone: tone),
                  ),
                  const SizedBox(width: frostStatusLabelGap),
                ],
                Expanded(
                  child: AnimatedDefaultTextStyle(
                    duration: FrostMotion.duration(context, FrostMotion.hover),
                    curve: FrostMotion.hoverCurve,
                    style: FrostTypography.of(context)
                        .style(FrostTextRole.footnote, tabular: true)
                        .copyWith(color: selected ? tokens.selectionInk : (status == FrostTaskStatus.failed ? tokens.negativeInk : tokens.textSecondary)),
                    child: FrostSkeletonText(child: Text(detail ?? label)),
                  ),
                ),
              ],
            ),
            if (progressPlacement == FrostTaskProgressPlacement.belowDetail) progressView(),
          ],
        ),
      ),
      child: FrostListRow(
        title: title,
        contentTitle: contentTitle,
        subtitle: FrostRowSubtitle(detail ?? label),
        onPressed: onPressed,
        contextMenu: entries,
        trailing: controls,
        leading: thumbnail == null ? null : FrostLeading.custom(thumbnail!),
      ),
    );
    return row;
  }
}
