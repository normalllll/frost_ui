import 'package:flutter/widgets.dart';

/// Marks one body of a group kept under a pinned chrome and says whether it
/// is the one on screen.
class FrostChromeBodyScope extends InheritedWidget {
  const FrostChromeBodyScope({required this.active, required super.child, super.key});
  final bool active;

  /// The box of the marked body around [context]; null outside any group.
  static RenderBox? boxOf(BuildContext? context) {
    final box = context?.getElementForInheritedWidgetOfExactType<FrostChromeBodyScope>()?.findRenderObject();
    return box is RenderBox ? box : null;
  }

  @override
  bool updateShouldNotify(FrostChromeBodyScope oldWidget) => active != oldWidget.active;
}
