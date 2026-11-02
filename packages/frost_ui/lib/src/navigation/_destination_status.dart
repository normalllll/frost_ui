import 'dart:math' as math;

import 'package:flutter/rendering.dart' show OverflowBoxFit;
import 'package:flutter/widgets.dart';

import '../display/count_badge.dart';
import '../feedback/progress.dart';
import '../foundation/scope.dart';
import '../foundation/sizes.dart';
import '../foundation/tokens.dart';
import '../foundation/typography.dart';
import '../motion/rolling_text.dart';
import '../primitives/presence.dart';

// The count and progress ring share this spacing with the preceding label.
const _statusGap = 6.0;
const _percentScale = 100;
const _dotExtent = 8.0;

/// Library-only destination data, shared by both sidebar item forms.
class FrostDestinationStatus extends InheritedWidget {
  const FrostDestinationStatus({
    required this.badge,
    required this.progress,
    this.badgeTone = FrostCountBadgeTone.accent,
    this.dot = false,
    required super.child,
    super.key,
  });
  final int badge;

  /// Marks a count with a small dot above the icon's trailing corner instead
  /// of the number. A summary item uses it: its own glyph, such as an
  /// ellipsis, can carry ink where a count would sit. The count stays in the
  /// label.
  final bool dot;
  final double? progress;
  final FrostCountBadgeTone badgeTone;

  static FrostDestinationStatus? of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<FrostDestinationStatus>();

  static String labelOf(BuildContext context, String label) {
    final status = of(context);
    final description = status == null ? null : describe(context, status.badge, status.progress);
    return description == null ? label : '$label, $description';
  }

  /// A count and progress in the caller's words; null when there is neither.
  static String? describe(BuildContext context, int badge, double? progress) {
    if (badge <= 0 && progress == null) return null;
    return FrostScope.labelsOf(context).navigationStatus(math.max(0, badge), progress == null ? null : (progress * _percentScale).round());
  }

  static Widget decorateIcon(BuildContext context, Widget icon, {double expansion = 0}) {
    final status = of(context);
    if (status == null) return icon;
    // The icon remains visible while only its badge fades during expansion.
    // Navigation icons keep their size at large text and so does the count
    // over one: a text-scaled badge outgrew the icon and spilled into the gap
    // above, where it read as the previous destination's. The count remains
    // in the destination's label, and expanded rows show it at text size.
    return Stack(
      clipBehavior: Clip.none,
      children: [
        icon,
        if (status.dot)
          PositionedDirectional(
            top: -_dotExtent / 2,
            end: -_dotExtent / 2,
            child: IgnorePointer(
              child: Opacity(
                opacity: (1 - expansion * 2).clamp(0.0, 1.0),
                child: FrostPresence(
                  visible: status.badge > 0,
                  child: _CountDot(tone: status.badgeTone),
                ),
              ),
            ),
          )
        else
          Positioned.fill(
            child: Opacity(
              opacity: (1 - expansion * 2).clamp(0.0, 1.0),
              child: MediaQuery.withNoTextScaling(child: const SizedBox.expand().frostBadge(status.badge, tone: status.badgeTone)),
            ),
          ),
      ],
    );
  }

  @override
  bool updateShouldNotify(FrostDestinationStatus oldWidget) =>
      badge != oldWidget.badge || progress != oldWidget.progress || badgeTone != oldWidget.badgeTone || dot != oldWidget.dot;
}

/// Retains outgoing values until Presence finishes; digits never flash zero.
class FrostDestinationTrailing extends StatefulWidget {
  const FrostDestinationTrailing({required this.status, required this.ink, super.key});
  final FrostDestinationStatus status;
  final Color ink;

  /// The room a two-digit count takes after a label at the current text
  /// scale: the gap and two tabular digit slots, as the count rolls one slot
  /// per character. It depends on no destination's count, so a sidebar sized
  /// with it keeps its width while counts come, go and change.
  static double countReserveOf(BuildContext context) {
    final painter = TextPainter(
      text: TextSpan(text: '0', style: FrostTypography.of(context).style(FrostTextRole.footnote, tabular: true)),
      textScaler: MediaQuery.textScalerOf(context),
      textDirection: Directionality.of(context),
      maxLines: 1,
    )..layout();
    final digit = painter.width;
    painter.dispose();
    return _statusGap + 2 * digit;
  }

  @override
  State<FrostDestinationTrailing> createState() => _DestinationTrailingState();
}

class _DestinationTrailingState extends State<FrostDestinationTrailing> {
  late int _count = widget.status.badge;
  late double _progress = widget.status.progress ?? 0;
  @override
  void didUpdateWidget(FrostDestinationTrailing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.status.badge > 0) _count = widget.status.badge;
    if (widget.status.progress case final progress?) _progress = progress;
  }

  @override
  Widget build(BuildContext context) => ClipRect(
    // During sidebar collapse the fading label area can be narrower than the
    // status itself. Keep its natural geometry and clip the outgoing content.
    child: OverflowBox(
      fit: OverflowBoxFit.deferToChild,
      minWidth: 0,
      maxWidth: double.infinity,
      alignment: AlignmentDirectional.centerEnd,
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FrostPresence(
              visible: widget.status.badge > 0,
              effect: FrostPresenceEffect.expand,
              axis: Axis.horizontal,
              child: Padding(
                padding: const EdgeInsetsDirectional.only(start: _statusGap),
                child: FrostRollingText(
                  _count.toString(),
                  style: FrostTypography.of(context)
                      .style(FrostTextRole.footnote, tabular: true)
                      .copyWith(color: widget.status.badgeTone == FrostCountBadgeTone.negative ? FrostThemeTokens.of(context).negativeInk : widget.ink),
                ),
              ),
            ),
            FrostPresence(
              visible: widget.status.progress != null,
              effect: FrostPresenceEffect.expand,
              axis: Axis.horizontal,
              child: Padding(
                padding: const EdgeInsetsDirectional.only(start: _statusGap),
                child: FrostProgressInk(
                  ink: widget.ink,
                  child: FrostProgressRing(value: _progress, size: FrostControlSize.compact, semanticLabel: ''),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _CountDot extends StatelessWidget {
  const _CountDot({required this.tone});
  final FrostCountBadgeTone tone;
  @override
  Widget build(BuildContext context) {
    final tokens = FrostThemeTokens.of(context);
    return SizedBox.square(
      dimension: _dotExtent,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: switch (tone) {
            FrostCountBadgeTone.accent => tokens.actionFill,
            FrostCountBadgeTone.negative => tokens.negativeFill,
            FrostCountBadgeTone.neutral => Color.alphaBlend(tokens.textSecondary, tokens.canvas),
          },
        ),
      ),
    );
  }
}
