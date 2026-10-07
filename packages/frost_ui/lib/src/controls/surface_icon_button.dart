import 'package:frost_ui/src/foundation/metrics.dart';
import 'package:flutter/material.dart';
import 'package:frost_ui/src/controls/icon.dart';
import 'package:frost_ui/src/foundation/tokens.dart';

class FrostSurfaceIconButton extends StatelessWidget {
  const FrostSurfaceIconButton({required this.icon, required this.tooltip, required this.onPressed, this.iconSize, super.key});

  final FrostIconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final double? iconSize;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final tokens = FrostThemeTokens.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.surfaceRaised.withValues(alpha: 0.92),
        shape: BoxShape.circle,
        border: Border.all(color: tokens.line.withValues(alpha: .65)),
      ),
      child: IconButton(
        constraints: const BoxConstraints(minWidth: FrostMetrics.controlHeight, minHeight: FrostMetrics.controlHeight),
        tooltip: tooltip,
        onPressed: onPressed,
        iconSize: iconSize ?? FrostMetrics.iconSize,
        color: colorScheme.onSurfaceVariant,
        icon: FrostIcon(icon),
      ),
    );
  }
}
