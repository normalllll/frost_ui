part of 'shell.dart';

/// The retained destination page inside a [FrostShell]'s content Navigator.
///
/// Place this once around the root page that hosts primary destinations (for
/// example, a router's retained branch shell), rather than around the Navigator
/// itself or each branch. The bar and its target State remain mounted across
/// destination changes. Secondary routes cover the complete root page, including
/// its navigation, without resizing either route. Horizontal layouts reserve no
/// navigation height. The bar owns the root's bottom system safe area.
class FrostShellDestination extends StatelessWidget {
  const FrostShellDestination({required this.child, super.key});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final navigation = context.dependOnInheritedWidgetOfExactType<_FrostDestinationNavigation>();
    assert(navigation != null, 'FrostShellDestination must be below FrostShell.');
    if (navigation == null) return child;
    navigation.route?.value = ModalRoute.of(context);
    return Column(
      children: [
        Expanded(
          child: FrostToastViewport(
            key: const ValueKey('frost-destination-toast-viewport'),
            child: MediaQuery.removePadding(
              context: context,
              removeBottom: navigation.enabled,
              child: FrostDestinationRoot(route: ModalRoute.of(context), child: child),
            ),
          ),
        ),
        if (navigation.enabled) navigation.navigation,
      ],
    );
  }
}

class _FrostDestinationNavigation extends InheritedWidget {
  const _FrostDestinationNavigation({required this.enabled, required this.navigation, this.route, required super.child});
  final bool enabled;
  final Widget navigation;

  /// Learns the destination page's route while a floating task entry looks
  /// for modal routes above it.
  final _DestinationRoute? route;
  @override
  bool updateShouldNotify(_FrostDestinationNavigation oldWidget) =>
      enabled != oldWidget.enabled || navigation != oldWidget.navigation || route != oldWidget.route;
}

class _DestinationRoute {
  ModalRoute<Object?>? value;

  /// Removes every page and modal above the destination page, with no exit
  /// motion, including those on the Navigators around it: Frost modals open on
  /// the root Navigator.
  void clearPagesAbove() {
    var anchor = value;
    while (anchor != null) {
      final navigator = anchor.navigator;
      if (navigator == null || !anchor.isActive) return;
      while (!anchor.isCurrent) {
        late Route<dynamic> top;
        // Reads the top present route; a predicate that holds pops nothing.
        navigator.popUntil((route) {
          top = route;
          return true;
        });
        navigator.removeRoute(top);
      }
      anchor = ModalRoute.of(navigator.context);
    }
  }
}
