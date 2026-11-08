import 'package:flutter/widgets.dart';

// Caption geometry is owned by the shell so an expanded field participates in
// hit testing outside its resting slot, rather than merely painting overflow.
const frostCaptionSearchWidth = 360.0;
const frostCaptionSearchEndWidth = 240.0;
const frostCaptionSearchExpandedWidth = 520.0;

class FrostCaptionSearchScope extends InheritedWidget {
  const FrostCaptionSearchScope({required this.expanded, required this.onExpanded, required super.child, super.key});
  final bool expanded;
  final ValueChanged<bool> onExpanded;
  static FrostCaptionSearchScope? maybeOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<FrostCaptionSearchScope>();
  @override
  bool updateShouldNotify(FrostCaptionSearchScope oldWidget) => expanded != oldWidget.expanded;
}

/// Private presentation inherited by the caption editor and its normal field.
class FrostCaptionFieldScope extends InheritedWidget {
  const FrostCaptionFieldScope({required super.child, super.key});
  static bool of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<FrostCaptionFieldScope>() != null;
  @override
  bool updateShouldNotify(FrostCaptionFieldScope oldWidget) => false;
}
