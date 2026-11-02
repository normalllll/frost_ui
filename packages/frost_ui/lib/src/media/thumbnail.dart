import 'package:flutter/widgets.dart';

import '../foundation/radius.dart';
import '../primitives/_click_surface_visuals.dart';
import '../primitives/_media_selection.dart';
import '../primitives/click_surface.dart';
import '../primitives/media_frame.dart';

enum FrostThumbnailSize { small, regular, large }

double frostThumbnailExtent(FrostThumbnailSize size) => switch (size) {
  FrostThumbnailSize.small => 48,
  FrostThumbnailSize.regular => 64,
  FrostThumbnailSize.large => 96,
};

/// A square media preview. [image] owns loading and failure presentation.
///
/// Every size uses the row-thumbnail radius of [FrostMediaRow] covers, so
/// leading artwork in task, tag and settings rows matches at any extent.
class FrostThumbnail extends StatelessWidget {
  const FrostThumbnail({
    required this.image,
    required this.semanticLabel,
    this.size = FrostThumbnailSize.regular,
    this.selected = false,
    this.onPressed,
    super.key,
  });
  final Widget image;
  final FrostThumbnailSize size;
  final bool selected;
  final VoidCallback? onPressed;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final extent = frostThumbnailExtent(size);
    const radius = frostRowThumbnailRadius;
    return SizedBox.square(
      dimension: extent,
      child: FrostClickSurfaceVisuals.unclipped(
        child: FrostClickSurface(
          onTap: onPressed,
          feedback: FrostClickFeedback.media,
          shape: FrostClickShape.rounded(FrostRadius.borderRadius(radius)),
          child: Semantics(
            label: semanticLabel,
            image: true,
            button: onPressed != null,
            selected: selected,
            child: Stack(
              clipBehavior: Clip.none,
              fit: StackFit.expand,
              children: [
                FrostMediaFrame(radius: radius, child: image),
                FrostMediaSelectionRing(selected: selected, radius: radius, width: frostThumbnailRingWidth),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
