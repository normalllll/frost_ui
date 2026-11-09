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

/// Set by a menu host beside the editor: a tap on its menu is not a tap away.
class FrostCaptionFieldMenu {
  bool open = false;
}

/// Private presentation inherited by the caption editor and its normal field.
class FrostCaptionFieldScope extends InheritedWidget {
  const FrostCaptionFieldScope({required this.region, required this.editor, required this.menu, required super.child, super.key});

  /// Whether a menu opened from a control beside the editor is up.
  final FrostCaptionFieldMenu menu;

  /// Has focus while the editor or a control beside it does, the menus those
  /// controls open included.
  final FocusNode region;

  /// Where a menu opened from a control beside the editor returns focus.
  final FocusNode editor;
  static bool of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<FrostCaptionFieldScope>() != null;

  /// For state and callbacks, without a build dependency.
  static FrostCaptionFieldScope? read(BuildContext context) => context.getInheritedWidgetOfExactType<FrostCaptionFieldScope>();
  @override
  bool updateShouldNotify(FrostCaptionFieldScope oldWidget) => false;
}
