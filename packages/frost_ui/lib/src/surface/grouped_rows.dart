import 'package:flutter/material.dart';
import 'package:frost_ui/src/foundation/metrics.dart';
import 'package:frost_ui/src/surface/surface.dart';

/// Contiguous rows share one surface and only its outer corners are rounded.
class FrostGroupedRows extends StatelessWidget {
  const FrostGroupedRows({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return FrostSurface(
      role: FrostSurfaceRole.glassPanel,
      edge: FrostSurfaceEdge.none,
      borderRadius: BorderRadius.circular(FrostMetrics.groupRadius),
      child: ListTileTheme.merge(
        shape: const RoundedRectangleBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var index = 0; index < children.length; index++)
              ClipRRect(
                borderRadius: BorderRadius.vertical(
                  top: index == 0 ? const Radius.circular(FrostMetrics.groupRadius) : Radius.zero,
                  bottom: index == children.length - 1 ? const Radius.circular(FrostMetrics.groupRadius) : Radius.zero,
                ),
                child: children[index],
              ),
          ],
        ),
      ),
    );
  }
}
