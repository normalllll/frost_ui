import 'dart:math' as math;
import 'package:flutter/widgets.dart';

// Menus and popovers share this viewport margin and anchor gap (zero).
const frostAnchoredPanelMargin = 8.0;
const frostAnchoredPanelGap = Offset.zero;

/// Which side of its anchor a panel ended up on, known once it is laid out. Its
/// reveal reads this to scale from the anchored edge.
class FrostAnchoredPanelSide {
  bool below = true;

  /// A pointer panel turned back at the edge it would cross, away from its start.
  bool turned = false;
}

/// Places a panel under its anchor, or above when it does not fit there, with
/// its leading edge on the anchor's leading edge in the text direction.
class FrostAnchoredPanelLayout extends SingleChildLayoutDelegate {
  const FrostAnchoredPanelLayout({
    required this.anchor,
    required this.offset,
    required this.direction,
    required this.margin,
    this.side,
    this.insets = EdgeInsets.zero,
    this.bounds,
  });

  final Rect anchor;
  final Rect? bounds;
  Rect area(Size size) => (bounds ?? Offset.zero & size)
      .deflate(margin)
      .intersect(Rect.fromLTRB(insets.left + margin, insets.top + margin, size.width - insets.right - margin, size.height - insets.bottom - margin));
  final Offset offset;
  final TextDirection direction;
  final FrostAnchoredPanelSide? side;
  final double margin;
  final EdgeInsets insets;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final rect = area(constraints.biggest);
    final room = math.max(rect.bottom - anchor.bottom - offset.dy, anchor.top - rect.top - offset.dy);
    return BoxConstraints(maxWidth: math.max(0, rect.width), maxHeight: math.max(0, math.min(rect.height, room)));
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final rect = area(size);
    final rtl = direction == TextDirection.rtl;
    final desired = rtl ? anchor.right - offset.dx - childSize.width : anchor.left + offset.dx;
    // An empty anchor is a pointer position; the panel turns back at the edge it would cross.
    final flip = anchor.isEmpty && (rtl ? desired < rect.left : desired + childSize.width > rect.right);
    side?.turned = flip;
    final turned = rtl ? anchor.left + offset.dx : anchor.left - offset.dx - childSize.width;
    final left = (flip ? turned : desired).clamp(rect.left, math.max(rect.left, rect.right - childSize.width));
    final fitsBelow = anchor.bottom + offset.dy + childSize.height <= rect.bottom;
    side?.below = fitsBelow;
    final top = (fitsBelow ? anchor.bottom + offset.dy : anchor.top - offset.dy - childSize.height).clamp(
      rect.top,
      math.max(rect.top, rect.bottom - childSize.height),
    );
    return Offset(left.toDouble(), top.toDouble());
  }

  @override
  bool shouldRelayout(FrostAnchoredPanelLayout oldDelegate) =>
      bounds != oldDelegate.bounds ||
      anchor != oldDelegate.anchor ||
      offset != oldDelegate.offset ||
      direction != oldDelegate.direction ||
      margin != oldDelegate.margin ||
      insets != oldDelegate.insets;
}
