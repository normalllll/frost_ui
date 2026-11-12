import 'package:flutter/widgets.dart';

import '../feedback/_skeleton_geometry.dart';
import '../foundation/_control_geometry.dart';
import '../foundation/color_math.dart';
import '../foundation/metrics.dart';
import '../foundation/radius.dart';
import '../foundation/spacing.dart';
import '../foundation/tokens.dart';
import '../foundation/typography.dart';
import '../primitives/_on_media_chrome_scope.dart';
import '../primitives/icon.dart';

// Status badges keep their unscaled vertical breathing room at larger type.
const _badgeHeight = 18.0;
const _badgeInset = 6.0;
const _badgeIconSize = 12.0;

enum FrostBadgeTone { neutral, accent, positive, caution, negative, info, onMedia }

enum FrostBadgeStyle { tinted, solid }

/// A noninteractive status label. Its icon is decorative in text semantics.
class FrostBadge extends StatelessWidget {
  const FrostBadge({
    required this.label,
    this.tone = FrostBadgeTone.neutral,
    this.icon,
    this.style = FrostBadgeStyle.tinted,
    this.textRole = FrostTextRole.caption,
    super.key,
  });
  final String label;
  final FrostBadgeTone tone;
  final FrostIconData? icon;
  final FrostBadgeStyle style;
  final FrostTextRole textRole;

  @override
  Widget build(BuildContext context) {
    final tokens = FrostThemeTokens.of(context);
    final solid = style == FrostBadgeStyle.solid || (FrostOnMediaChromeScope.inkOf(context) != null) && tone != FrostBadgeTone.neutral;
    var (fill, ink) = switch (tone) {
      FrostBadgeTone.neutral => (tokens.fill, tokens.textSecondary),
      FrostBadgeTone.accent => (tokens.selectionFill, tokens.selectionInk),
      FrostBadgeTone.positive => (tokens.positiveTint, tokens.positiveInk),
      FrostBadgeTone.caution => (tokens.cautionTint, tokens.cautionInk),
      FrostBadgeTone.negative => (tokens.negativeTint, tokens.negativeInk),
      FrostBadgeTone.info => (tokens.infoTint, tokens.infoInk),
      FrostBadgeTone.onMedia => (tokens.onMediaScrim, tokens.onMediaInk),
    };
    if (solid) {
      // Brand-colour solids follow the same original-accent/white-ink policy
      // as action buttons. Semantic fills keep their separate contrast rule.
      fill = tone == FrostBadgeTone.accent || tone == FrostBadgeTone.neutral ? tokens.actionFill : readableAccentTone(ink, tokens.onAction, 4.5);
      ink = tokens.onAction;
    }
    final textStyle = FrostTypography.of(context).style(textRole).copyWith(fontSize: solid ? 11 : null, fontWeight: FontWeight.w600);
    final geometry = frostControlTextGeometry(baseHeight: _badgeHeight, style: textStyle, textScaler: MediaQuery.textScalerOf(context));
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: FrostSkeletonShape(
        shape: FrostRadius.shape(context, 4),
        child: AnimatedContainer(
          duration: FrostMotion.duration(context, FrostMotion.hover),
          curve: FrostMotion.hoverCurve,
          decoration: ShapeDecoration(
            color: fill,
            shape: (FrostRadius.shape(context, 4) as OutlinedBorder).copyWith(side: BorderSide.none),
          ),
          constraints: BoxConstraints(minHeight: geometry.height),
          padding: const EdgeInsets.symmetric(horizontal: _badgeInset),
          child: AnimatedDefaultTextStyle(
            style: textStyle.copyWith(color: ink),
            duration: FrostMotion.duration(context, FrostMotion.hover),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon case final icon?) ...[
                  TweenAnimationBuilder<Color?>(
                    tween: ColorTween(end: ink),
                    duration: FrostMotion.duration(context, FrostMotion.hover),
                    builder: (_, color, _) => FrostIcon(icon, size: _badgeIconSize, color: color),
                  ),
                  const SizedBox(width: FrostGap.inline),
                ],
                Flexible(
                  child: FrostSkeletonText(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
