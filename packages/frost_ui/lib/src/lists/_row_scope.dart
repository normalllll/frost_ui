import 'package:flutter/widgets.dart';

/// Shares picker input focus without changing row content or geometry.
class FrostRowFocus extends InheritedWidget {
  const FrostRowFocus({required this.focusNode, required super.child, super.key});
  final FocusNode focusNode;
  static FocusNode? of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<FrostRowFocus>()?.focusNode;
  @override
  bool updateShouldNotify(FrostRowFocus oldWidget) => focusNode != oldWidget.focusNode;
}

/// Group placement and measured text anchor, never part of the public API.
class FrostRowPlacement extends InheritedWidget {
  const FrostRowPlacement({required this.textAnchor, required this.corners, required super.child, super.key});
  final GlobalKey textAnchor;
  final BorderRadius? corners;
  static FrostRowPlacement? of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<FrostRowPlacement>();
  @override
  bool updateShouldNotify(FrostRowPlacement oldWidget) => textAnchor != oldWidget.textAnchor || corners != oldWidget.corners;
}

/// List selection/highlight is presentation state owned by the list, while
/// activation falls back to the row when the list has no selection callback.
class FrostListItemScope extends InheritedWidget {
  const FrostListItemScope({
    required this.selected,
    this.reserveIconColumn = false,
    required this.highlighted,
    required this.onSelected,
    required this.handle,
    required this.viewportInset,
    required super.child,
    super.key,
  });

  /// Null when the list has no selection, so rows do not reserve a check column.
  final bool? selected;
  final bool highlighted, reserveIconColumn;
  final VoidCallback? onSelected;
  final FrostListItemHandle handle;
  final EdgeInsetsGeometry viewportInset;
  static FrostListItemScope? of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<FrostListItemScope>();
  @override
  bool updateShouldNotify(FrostListItemScope oldWidget) =>
      selected != oldWidget.selected ||
      reserveIconColumn != oldWidget.reserveIconColumn ||
      highlighted != oldWidget.highlighted ||
      onSelected != oldWidget.onSelected ||
      handle != oldWidget.handle ||
      viewportInset != oldWidget.viewportInset;
}

/// UI-only registration, without notifications or writes during build/layout.
class FrostListItemHandle {
  VoidCallback? activate;
}

/// One shared width for the leading slot of every [FrostListRow] below it, so
/// icon rows and avatar or thumbnail rows in the same list start their text at
/// the same place. Leading content is centred in the slot.
class FrostRowLeadingExtent extends InheritedWidget {
  const FrostRowLeadingExtent({required this.extent, required super.child, super.key});
  final double extent;
  static double? of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<FrostRowLeadingExtent>()?.extent;
  @override
  bool updateShouldNotify(FrostRowLeadingExtent oldWidget) => extent != oldWidget.extent;
}

/// Keeps a row's value and trailing controls on the title's line even when the
/// title wraps, as an inline subtitle does; for rows whose end action must stay
/// at the end, such as a tab's close button.
class FrostRowInlineValue extends InheritedWidget {
  const FrostRowInlineValue({required super.child, super.key});
  static bool of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<FrostRowInlineValue>() != null;
  @override
  bool updateShouldNotify(FrostRowInlineValue oldWidget) => false;
}
