import 'package:flutter/widgets.dart';

import '../foundation/radius.dart';
import '../primitives/surface.dart';

// Popover contents use a separate inset from dense menu items.
const frostPopoverContentInset = 16.0;

/// Shared material for arbitrary anchored content, including passive previews.
class FrostPopoverSurface extends StatelessWidget {
  const FrostPopoverSurface({required this.child, this.padding = const EdgeInsets.all(frostPopoverContentInset), super.key});
  final Widget child;

  /// A child that scrolls takes only the vertical inset here and pads its
  /// content inside the scroll view, so its scrollbar keeps the panel edge.
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) => FrostSurface(
    role: FrostSurfaceRole.overlay,
    borderRadius: FrostRadius.borderRadius(FrostRadius.xl),
    child: Padding(padding: padding, child: child),
  );
}
