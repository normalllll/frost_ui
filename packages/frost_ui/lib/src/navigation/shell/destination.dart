part of 'shell.dart';

/// The retained destination page inside a [FrostShell]'s content Navigator.
///
/// Place this once around the root page that hosts primary destinations (for
/// example, a router's retained branch shell), rather than around the Navigator
/// itself or each branch. The bar and its target State remain mounted across
/// destination changes. Secondary routes cover the complete root page, including
/// its navigation, without resizing either route. Horizontal layouts reserve no
/// navigation height.
///
/// On a phone the page runs beneath the bottom navigation bar, which is glass
/// over it. The page sees the bar, its bottom safe area included, as its
/// bottom [MediaQuery] padding: scroll views end their content above it, and
/// toasts and floating actions stay above it.
class FrostShellDestination extends StatelessWidget {
  const FrostShellDestination({required this.child, super.key});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final navigation = context.dependOnInheritedWidgetOfExactType<_FrostDestinationNavigation>();
    assert(navigation != null, 'FrostShellDestination must be below FrostShell.');
    if (navigation == null) return child;
    final route = ModalRoute.of(context);
    navigation.route?.value = route;
    // The root page, its navigation bar included, may have no transition of
    // its own; its glass still waits for a page above it to settle.
    return FrostSettledGlass(
      secondary: route?.secondaryAnimation ?? kAlwaysDismissedAnimation,
      // The page runs beneath the bar, so the bar is glass over it, and the
      // page's own bars and this one read the backdrop once between them.
      child: BackdropGroup(
        child: CustomMultiChildLayout(
          delegate: _DestinationLayout(),
          children: [
            LayoutId(
              id: _DestinationSlot.page,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // The delegate lays the bar out first and passes its height,
                  // bottom safe area included, as the page's minimum height.
                  final media = MediaQuery.of(context);
                  final bar = navigation.enabled ? constraints.minHeight : 0.0;
                  return SizedBox.expand(
                    child: MediaQuery(
                      data: !navigation.enabled
                          ? media
                          : media.copyWith(
                              padding: media.padding.copyWith(bottom: math.max(0.0, bar - media.viewInsets.bottom)),
                              viewPadding: media.viewPadding.copyWith(bottom: bar),
                            ),
                      child: FrostToastViewport(
                        key: const ValueKey('frost-destination-toast-viewport'),
                        bottomInset: bar,
                        child: FrostDestinationRoot(route: route, child: child),
                      ),
                    ),
                  );
                },
              ),
            ),
            if (navigation.enabled) LayoutId(id: _DestinationSlot.bar, child: navigation.navigation),
          ],
        ),
      ),
    );
  }
}

enum _DestinationSlot { page, bar }

/// The page takes the whole area and the bar lies over its bottom edge.
class _DestinationLayout extends MultiChildLayoutDelegate {
  _DestinationLayout();

  @override
  void performLayout(Size size) {
    var bar = 0.0;
    if (hasChild(_DestinationSlot.bar)) {
      bar = layoutChild(_DestinationSlot.bar, BoxConstraints(minWidth: size.width, maxWidth: size.width, maxHeight: size.height)).height;
      positionChild(_DestinationSlot.bar, Offset(0, size.height - bar));
    }
    layoutChild(
      _DestinationSlot.page,
      BoxConstraints(minWidth: size.width, maxWidth: size.width, minHeight: math.min(bar, size.height), maxHeight: size.height),
    );
    positionChild(_DestinationSlot.page, Offset.zero);
  }

  @override
  bool shouldRelayout(_DestinationLayout oldDelegate) => false;
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
