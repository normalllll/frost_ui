import 'package:frost_ui/src/controls/click_surface.dart';
import 'package:frost_ui/src/foundation/metrics.dart';
import 'package:flutter/material.dart';
import 'package:frost_ui/src/controls/icon.dart';
import 'package:frost_ui/src/foundation/tokens.dart';
import 'package:frost_ui/src/surface/surface.dart';

class FrostCard extends StatelessWidget {
  const FrostCard({
    required this.child,
    this.onTap,
    this.padding,
    this.margin = EdgeInsets.zero,
    this.accentColor,
    this.borderRadius = FrostMetrics.controlRadius,
    this.feedback = FrostClickFeedback.surface,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry margin;
  final Color? accentColor;
  final double borderRadius;
  final FrostClickFeedback feedback;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(borderRadius);

    Widget content = child;
    final padding = this.padding;
    if (padding != null) {
      content = Padding(padding: padding, child: content);
    }

    final onTap = this.onTap;
    content = Material(
      type: MaterialType.transparency,
      child: onTap == null ? content : FrostClickSurface(feedback: feedback, borderRadius: radius, onTap: onTap, child: content),
    );

    return Padding(
      padding: margin,
      child: FrostSurface(role: FrostSurfaceRole.panel, borderRadius: radius, child: content),
    );
  }
}

class FrostPill extends StatelessWidget {
  const FrostPill({
    required this.child,
    this.icon,
    this.selected = false,
    this.accentColor,
    this.padding = const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    super.key,
  });

  final Widget child;
  final FrostIconData? icon;
  final bool selected;
  final Color? accentColor;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final tokens = FrostThemeTokens.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final foreground = selected ? tokens.selectionInk : colorScheme.onSurfaceVariant;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: selected ? tokens.selectionSurface : tokens.surfaceMuted,
        borderRadius: BorderRadius.circular(FrostMetrics.controlRadius),
        border: Border.all(color: tokens.line.withValues(alpha: .35)),
      ),
      child: Padding(
        padding: padding,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[FrostIcon(icon!, size: 14, color: foreground), const SizedBox(width: 4)],
            Flexible(
              fit: FlexFit.loose,
              child: DefaultTextStyle.merge(
                style: Theme.of(context).textTheme.labelSmall?.copyWith(color: foreground, fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
