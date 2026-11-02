import 'package:flutter/widgets.dart';

import '../foundation/metrics.dart';
import '../foundation/radius.dart';
import '../foundation/tokens.dart';

// The selection ring starts two logical pixels beyond the media edge.
const frostMediaSelectionGap = 2.0;
const frostMediaCardRingWidth = 3.0;
const frostThumbnailRingWidth = 2.0;
const _selectionRingAlpha = .65;

// Covers and row thumbnails keep fixed radii at every extent; a radius that
// grows with the side reads as a rounded tile beside list text.
const frostCoverRadius = FrostRadius.sm;
const frostRowThumbnailRadius = FrostRadius.xs;

/// An outside, concentric ring. Its parent must allow painting outside bounds.
class FrostMediaSelectionRing extends StatelessWidget {
  const FrostMediaSelectionRing({required this.selected, required this.radius, required this.width, super.key});
  final bool selected;
  final double radius;
  final double width;

  @override
  Widget build(BuildContext context) => Positioned.fill(
    left: -frostMediaSelectionGap,
    top: -frostMediaSelectionGap,
    right: -frostMediaSelectionGap,
    bottom: -frostMediaSelectionGap,
    child: IgnorePointer(
      child: AnimatedContainer(
        duration: FrostMotion.duration(context, FrostMotion.hover),
        decoration: ShapeDecoration(
          shape: (FrostRadius.shape(context, radius + frostMediaSelectionGap) as OutlinedBorder).copyWith(
            side: BorderSide(
              color: FrostThemeTokens.of(context).actionFill.withValues(alpha: selected ? _selectionRingAlpha : 0),
              width: width,
              strokeAlign: BorderSide.strokeAlignOutside,
            ),
          ),
        ),
      ),
    ),
  );
}
