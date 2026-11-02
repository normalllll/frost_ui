import 'package:flutter/widgets.dart';

import '../foundation/_layout_scope.dart';

export '../foundation/_layout_scope.dart' show FrostSizeClass, FrostSizeLayout, FrostNavigationPlacement, isHorizontalSize;

typedef FrostAutoScaffoldBuilder = Widget Function(BuildContext context, FrostSizeLayout layout, Orientation orientation, bool useHorizontalLayout);

class FrostAutoScaffold extends StatelessWidget {
  const FrostAutoScaffold({
    required this.builder,
    this.navigationPlacement,
    this.mobileBreakpoint = frostMobileBreakpoint,
    this.tabletBreakpoint = frostTabletBreakpoint,
    this.desktopBreakpoint = frostDesktopBreakpoint,
    super.key,
  });

  final FrostAutoScaffoldBuilder builder;
  final FrostNavigationPlacement? navigationPlacement;
  final double mobileBreakpoint;
  final double tabletBreakpoint;
  final double desktopBreakpoint;

  static bool usesHorizontalLayoutOf(BuildContext context) => FrostAdaptiveLayoutData.horizontalOf(context);

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final orientation = size.width >= size.height ? Orientation.landscape : Orientation.portrait;

    final layout = FrostSizeLayout.fromSize(size, mobileBreakpoint: mobileBreakpoint, tabletBreakpoint: tabletBreakpoint, desktopBreakpoint: desktopBreakpoint);

    final inherited = context.dependOnInheritedWidgetOfExactType<FrostAdaptiveLayoutData>();
    final placement = navigationPlacement ?? inherited?.placement ?? FrostNavigationPlacement.automatic;
    final horizontal = navigationPlacement == null && inherited != null ? inherited.horizontal : frostUsesSidebar(context, size, placement);
    return FrostAdaptiveLayoutData(
      placement: placement,
      horizontal: horizontal,
      sizeClass: layout.sizeClass,
      child: builder(context, layout, orientation, horizontal),
    );
  }
}

/// Install above the router so nested viewports and keyboards cannot change mode.
class FrostLayoutScope extends StatelessWidget {
  const FrostLayoutScope({required this.child, this.navigationPlacement = FrostNavigationPlacement.automatic, super.key});
  final FrostNavigationPlacement navigationPlacement;
  final Widget child;

  @override
  Widget build(BuildContext context) => FrostAdaptiveLayoutData(
    placement: navigationPlacement,
    horizontal: frostUsesSidebar(context, MediaQuery.sizeOf(context), navigationPlacement),
    sizeClass: frostDefaultSizeClass(MediaQuery.sizeOf(context)),
    child: child,
  );
}
