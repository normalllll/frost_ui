import 'dart:math' as math;
import 'package:flutter/widgets.dart';

import '../foundation/_control_geometry.dart';
import '../foundation/_menu_metrics.dart';
import '../foundation/feedback.dart';
import '../foundation/metrics.dart';
import '../foundation/radius.dart';
import '../foundation/tokens.dart';
import '../foundation/typography.dart';
import '../primitives/_state_button.dart';
import 'menu_anchor.dart';

/// Internal input mechanism; callers describe menu entries instead of styles.
class FrostMenuItem extends StatelessWidget {
  const FrostMenuItem({
    required this.onPressed,
    required this.child,
    this.focusNode,
    this.autofocus = false,
    this.closeOnActivate = true,
    this.onHover,
    super.key,
  });
  final VoidCallback? onPressed;
  final Widget child;
  final FocusNode? focusNode;
  final bool autofocus, closeOnActivate;
  final ValueChanged<bool>? onHover;
  @override
  Widget build(BuildContext context) {
    final close = context.getInheritedWidgetOfExactType<FrostMenuScope>()?.close;
    final geometry = frostControlGeometry(context, FrostMenuMetrics.sizeOf(context), role: FrostTextRole.callout);
    final radius = math.min(FrostRadius.inner(FrostRadius.lg, FrostMenuMetrics.panelInset), FrostRadius.forHeight(geometry.height));
    final tokens = FrostThemeTokens.of(context);
    // MenuItemButton closes RawMenuAnchor children when another root item loses
    // focus. A plain state button keeps the same input without that policy.
    // Menus express keyboard current-item focus with the same whole-row fill as
    // pointer hover, so no ring is drawn.
    return FrostStateButton(
      focusNode: focusNode,
      autofocus: autofocus,
      onHover: onHover,
      onPressed: onPressed == null
          ? null
          : () {
              if (closeOnActivate) close?.call();
              onPressed!();
            },
      shape: FrostRadius.shape(context, radius),
      fill: (states) => frostButtonStateLayer(tokens, states, FrostFeedbackRole.quiet),
      ink: (states) => states.contains(WidgetState.disabled) ? tokens.textQuaternary : tokens.textPrimary,
      textStyle: FrostTypography.of(context).style(FrostTextRole.callout),
      iconSize: 18,
      focusReadsAsHover: true,
      constraints: BoxConstraints(minHeight: geometry.height),
      padding: EdgeInsets.symmetric(horizontal: FrostMenuMetrics.rowInset, vertical: geometry.verticalInset),
      child: AnimatedOpacity(opacity: onPressed == null ? .38 : 1, duration: FrostMotion.duration(context, FrostMotion.hover), child: child),
    );
  }
}
