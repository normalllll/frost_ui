import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Whether nothing follows [context]'s widget in the vertical flow holding it:
/// its render object, or an ancestor reached through single-child wrappers, is
/// the last child of a vertical Flex. Anything else (a lazy list, a sliver, a
/// widget placed outside a column) answers false, so callers keep the
/// separator they would draw when content follows.
///
/// Call after layout, for example from a post-frame callback.
bool frostEndsVerticalFlow(BuildContext context) {
  RenderObject? node = context.findRenderObject();
  while (node != null) {
    final parent = node.parent;
    if (parent is RenderFlex) {
      return parent.direction == Axis.vertical && (node.parentData! as FlexParentData).nextSibling == null;
    }
    if (parent is! RenderObjectWithChildMixin) return false;
    node = parent;
  }
  return false;
}
