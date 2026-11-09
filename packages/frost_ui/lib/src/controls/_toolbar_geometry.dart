import 'dart:math' as math;
import 'package:flutter/widgets.dart';

import '../foundation/density.dart';
import '../foundation/sizes.dart';
import '../foundation/spacing.dart';
import '../primitives/_on_media_chrome_scope.dart';
import '_button_control.dart';

/// Internal graphic alignment shared by every kind of toolbar control.
class FrostToolbarEdge extends InheritedWidget {
  const FrostToolbarEdge({required this.trailing, required super.child, super.key});
  final bool trailing;
  static bool trailingOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<FrostToolbarEdge>()?.trailing ?? false;
  @override
  bool updateShouldNotify(FrostToolbarEdge oldWidget) => trailing != oldWidget.trailing;
}

FrostButtonGeometry frostToolbarButtonGeometry(BuildContext context) {
  final inset = FrostGap.of(context).hitInset;
  return FrostButtonGeometry(
    horizontalInset: inset,
    verticalInset: FrostGap.inline,
    minimumWidth: math.max(FrostDensity.of(context).targetHeight, FrostControlSize.compact.iconSize + inset * 2),
    alignment: FrostToolbarEdge.trailingOf(context) ? MainAxisAlignment.end : MainAxisAlignment.start,
  );
}

/// Whether a toolbar lays its controls out for chrome over media.
bool frostToolbarOverMedia(BuildContext context) => FrostOnMediaChromeScope.inkOf(context) != null || FrostChromeOverMedia.declaredOf(context);

/// Layout width of a bare icon target in a toolbar row. A touch row is narrow
/// and its icon targets sit side by side, so each keeps the 44 touch height but
/// takes only its plate plus two pixels either side across (40 for the 36
/// plate): neighbours abut without overlapping and the plate never reaches the
/// next target. Pointer targets are already that tight and stay square.
/// Chrome over media draws its plates as always-visible circles, which need
/// visible room between them, so it keeps the full square target.
double frostToolbarIconWidth(BuildContext context) {
  final density = FrostDensity.of(context);
  if (frostToolbarOverMedia(context)) return density.targetHeight;
  return math.min(density.targetHeight, density.heightFor(FrostControlSize.compact) + 4);
}

FrostButtonGeometry frostToolbarIconGeometry(BuildContext context) =>
    FrostButtonGeometry(horizontalInset: 0, verticalInset: 0, minimumWidth: 0, alignment: MainAxisAlignment.center, hitWidth: frostToolbarIconWidth(context));

// Only natural-width leading menus opt into title-like truncation. Action
// controls retain their measured width and their existing overflow behavior.
class FrostToolbarLeadingScope extends InheritedWidget {
  const FrostToolbarLeadingScope({required super.child, super.key});
  static bool of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<FrostToolbarLeadingScope>() != null;
  @override
  bool updateShouldNotify(FrostToolbarLeadingScope oldWidget) => false;
}
