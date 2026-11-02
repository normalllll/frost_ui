import 'package:flutter/widgets.dart';

/// Private link between a page header and the search field in its middle slot.
/// The field reports focus and Escape; the header decides whether its row is
/// too narrow and expands the field over the row.
class FrostHeaderSearchScope extends InheritedWidget {
  const FrostHeaderSearchScope({required this.expanded, required this.row, required this.onFocused, required this.onDismissed, required super.child, super.key});
  final bool expanded;

  /// The header row; suggestions listed in the page body start below it.
  final GlobalKey row;
  final ValueChanged<FocusNode> onFocused;
  final VoidCallback onDismissed;

  /// Read from listeners and key handlers without a build dependency.
  static FrostHeaderSearchScope? read(BuildContext context) => context.getInheritedWidgetOfExactType<FrostHeaderSearchScope>();
  @override
  bool updateShouldNotify(FrostHeaderSearchScope oldWidget) => expanded != oldWidget.expanded;
}
