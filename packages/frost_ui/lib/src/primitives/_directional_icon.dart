import 'package:flutter/widgets.dart';

import '../foundation/icon_data.dart';

/// The icon that points the way [logical] does in left-to-right text, drawn
/// so it reads the same way in [context]'s text direction.
///
/// In right-to-left text a glyph that mirrors itself (a font glyph with
/// `matchTextDirection`, like Material's chevrons and arrows) is already
/// flipped by the icon, so [logical] is returned as is; any other glyph is
/// replaced by [opposite], the icon that points the other way.
FrostIconData frostDirectionalIcon(BuildContext context, {required FrostIconData logical, required FrostIconData opposite}) {
  if (Directionality.of(context) == TextDirection.ltr) return logical;
  return switch (logical) {
    FrostGlyphIcon(:final data) when data.matchTextDirection => logical,
    _ => opposite,
  };
}

/// The chevron that says "goes on from here" at the trailing end of a row or
/// header, pointing the way the text reads.
FrostIconData frostTrailingChevron(BuildContext context) {
  final icons = FrostIconSet.of(context);
  return frostDirectionalIcon(context, logical: icons.chevronRight, opposite: icons.chevronLeft);
}

/// The arrow toward the reading start, for "back" or "previous".
FrostIconData frostBackIcon(BuildContext context) {
  final icons = FrostIconSet.of(context);
  return frostDirectionalIcon(context, logical: icons.back, opposite: icons.forward);
}

/// The arrow toward the reading end, for "forward" or "next".
FrostIconData frostForwardIcon(BuildContext context) {
  final icons = FrostIconSet.of(context);
  return frostDirectionalIcon(context, logical: icons.forward, opposite: icons.back);
}

/// The chevron for stepping to the previous item, or to the next, in a
/// control whose previous side is the reading start.
FrostIconData frostStepChevron(BuildContext context, {required bool previous}) {
  final icons = FrostIconSet.of(context);
  return previous
      ? frostDirectionalIcon(context, logical: icons.chevronLeft, opposite: icons.chevronRight)
      : frostDirectionalIcon(context, logical: icons.chevronRight, opposite: icons.chevronLeft);
}
