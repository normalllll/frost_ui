import 'package:flutter/material.dart';
import 'package:frost_ui/src/foundation/metrics.dart';
import 'package:frost_ui/src/foundation/scope.dart';
import 'package:skeletonizer/skeletonizer.dart';

/// The shimmer of skeleton placeholders; a still fill with reduced motion.
/// Pass it to every `Skeletonizer` so skeletons respect the setting.
PaintingEffect? frostSkeletonEffect(BuildContext context) =>
    MediaQuery.disableAnimationsOf(context) ? SolidColorEffect(color: Theme.of(context).colorScheme.surfaceContainerHighest) : null;

/// Small action placeholders also keep the original control's occupied space.
class FrostSkeletonBlock extends StatelessWidget {
  const FrostSkeletonBlock({this.width = 16, this.height = 16, this.radius = FrostMetrics.badgeRadius, super.key});

  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) => Semantics(
    label: FrostScope.labelsOf(context).loading,
    child: Skeletonizer.zone(
      effect: frostSkeletonEffect(context),
      child: Bone(width: width, height: height, borderRadius: BorderRadius.circular(radius)),
    ),
  );
}

/// Placeholder filling an image's frame while it loads.
class FrostImageSkeleton extends StatelessWidget {
  const FrostImageSkeleton({this.borderRadius, super.key});

  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) => Skeletonizer.zone(
    effect: frostSkeletonEffect(context),
    child: Bone(width: double.infinity, height: double.infinity, borderRadius: borderRadius ?? BorderRadius.circular(FrostMetrics.controlRadius)),
  );
}
