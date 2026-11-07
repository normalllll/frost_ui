import 'package:flutter/widgets.dart';

/// Marks the root page of a shell destination: the page under
/// [FrostShellDestination], or a secondary destination's root page. The
/// sidebar already names these pages, so their headers leave the title out
/// there.
class FrostDestinationRoot extends InheritedWidget {
  const FrostDestinationRoot({required this.route, required super.child, super.key});

  /// The route of the marked page.
  final ModalRoute<Object?>? route;

  /// Whether [context] is on a destination root page itself: the marked route,
  /// or the first route of a Navigator inside it, such as a router's retained
  /// branch. Pages pushed above either are not.
  static bool contains(BuildContext context) {
    final root = context.getInheritedWidgetOfExactType<FrostDestinationRoot>();
    if (root == null) return false;
    final route = ModalRoute.of(context);
    return route == root.route || (route?.isFirst ?? false);
  }

  @override
  bool updateShouldNotify(FrostDestinationRoot oldWidget) => route != oldWidget.route;
}
