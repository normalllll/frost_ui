import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../foundation/density.dart';
import '../foundation/metrics.dart';
import '../foundation/radius.dart';
import '../foundation/sizes.dart';
import '../foundation/tokens.dart';
import '../layout/_caption_search_scope.dart';
import '_field_options.dart';
import 'field_appearance.dart';

/// One state and paint policy for editors, composers and selection triggers.
/// Resting borders are one physical hairline; focus and error edges are
/// [accentWidth] so they stay smooth on rounded corners. Focus modality only
/// affects button rings, never the appearance of an active field.
class FrostFieldChrome {
  const FrostFieldChrome({required this.fill, required this.shape, required this.edge});
  final Color fill;
  final OutlinedBorder shape;
  final ShapeDecoration edge;

  /// Logical width of the focus and error edge: at least 2 physical pixels,
  /// because a 1 pixel antialiased line steps on an 8px corner at fractional
  /// scales such as 125% and 150%.
  static double accentWidth(double devicePixelRatio) => math.max(2, devicePixelRatio.round()) / devicePixelRatio;

  static FrostFieldChrome resolve(BuildContext context, {required bool enabled, required bool focused, required bool invalid, bool hovered = false}) {
    final tokens = FrostThemeTokens.of(context);
    final touch = FrostDensity.of(context).heightFor(FrostControlSize.regular) == FrostControlSize.regular.visualHeight(touch: true);
    final dark = tokens.isDark;
    final appearance = FrostFieldScope.maybeOf(context) ?? FrostFieldOptions.of(context)?.appearance ?? FrostFieldScope.of(context);
    final subtle = appearance == FrostFieldAppearance.subtle;
    final media = appearance == FrostFieldAppearance.onMedia;
    final caption = FrostCaptionFieldScope.of(context);
    final fillAlpha = caption && enabled && !focused
        ? (dark ? .055 : .035)
        : !enabled
        ? (subtle ? (dark ? .025 : .018) : (dark ? .05 : .035)) * .38
        : focused
        ? (dark ? .09 : 0.0)
        : subtle
        ? (dark ? .025 : .018)
        : dark
        ? .05
        : .035;
    final border = !enabled
        ? tokens.textPrimary.withValues(
            alpha: subtle
                ? 0
                : dark
                ? .05
                : .06,
          )
        : invalid
        ? tokens.negativeInk
        : focused
        ? tokens.fieldFocus
        : hovered && !touch
        ? tokens.textPrimary.withValues(alpha: dark ? .22 : .26)
        : tokens.textPrimary.withValues(alpha: subtle ? 0 : (dark ? .11 : .13));
    final shape = FrostRadius.shape(context, touch ? 10 : 8) as OutlinedBorder;
    return FrostFieldChrome(
      fill: media
          ? tokens.onMediaScrim.withValues(
              alpha: !enabled
                  ? .64
                  : focused
                  ? .68
                  : .76,
            )
          : subtle && !focused
          ? tokens.fill.withValues(alpha: fillAlpha)
          : Color.alphaBlend(tokens.fill.withValues(alpha: fillAlpha), tokens.surface),
      shape: shape,
      edge: ShapeDecoration(
        shape: shape.copyWith(
          side: BorderSide(
            color: border,
            width: enabled && (focused || invalid) ? accentWidth(MediaQuery.devicePixelRatioOf(context)) : FrostMetrics.fieldFocusWidth / MediaQuery.devicePixelRatioOf(context),
            strokeAlign: BorderSide.strokeAlignInside,
          ),
        ),
      ),
    );
  }
}
