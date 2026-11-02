import 'package:flutter/widgets.dart';

/// The widest a toolbar's middle slot grows: a page header whose search is
/// controlled by the App gives its search field more room.
const frostToolbarMiddleMaxWidth = 360.0;
const frostToolbarSearchMiddleMaxWidth = 640.0;

/// The narrowest resting field in a narrow page header. Focus expands it over
/// the row, so its resting width only has to read as a search field.
const frostToolbarExpandingMiddleMinWidth = 80.0;

/// Library-only: how far the middle slot of the toolbar below may grow. A
/// toolbar outside a page header's search mode uses [frostToolbarMiddleMaxWidth].
/// The scope also marks the middle as a page header's, which expands on focus.
class FrostToolbarMiddleWidthScope extends InheritedWidget {
  const FrostToolbarMiddleWidthScope({required this.maxWidth, required super.child, super.key});
  final double maxWidth;

  static double of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<FrostToolbarMiddleWidthScope>()?.maxWidth ?? frostToolbarMiddleMaxWidth;

  static bool expandsOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<FrostToolbarMiddleWidthScope>() != null;

  @override
  bool updateShouldNotify(FrostToolbarMiddleWidthScope oldWidget) => maxWidth != oldWidget.maxWidth;
}
