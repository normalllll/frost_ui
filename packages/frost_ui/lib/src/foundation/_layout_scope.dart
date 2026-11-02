import 'package:flutter/widgets.dart';

import 'density.dart';

/// App-owned placement preference. Automatic follows the window's shape.
enum FrostNavigationPlacement { automatic, bottom, sidebar }

bool frostUsesSidebar(BuildContext context, Size size, FrostNavigationPlacement placement) => switch (placement) {
  FrostNavigationPlacement.sidebar => true,
  FrostNavigationPlacement.bottom => false,
  FrostNavigationPlacement.automatic => isHorizontalSize(size, pointer: FrostDensity.of(context).usesPointer),
};

const frostMobileBreakpoint = 600.0;
const frostTabletBreakpoint = 900.0;
const frostDesktopBreakpoint = 1200.0;

FrostSizeClass frostDefaultSizeClass(Size size) => FrostSizeLayout.fromSize(
  size,
  mobileBreakpoint: frostMobileBreakpoint,
  tabletBreakpoint: frostTabletBreakpoint,
  desktopBreakpoint: frostDesktopBreakpoint,
).sizeClass;

// Descendants use the window's navigation mode even after ContentViewport
// subtracts the sidebar or a detail pane constrains the available content width.
class FrostAdaptiveLayoutData extends InheritedWidget {
  const FrostAdaptiveLayoutData({
    required this.horizontal,
    required this.sizeClass,
    this.placement = FrostNavigationPlacement.automatic,
    required super.child,
    super.key,
  });
  final FrostSizeClass sizeClass;
  final bool horizontal;
  final FrostNavigationPlacement placement;

  // Read the window scope before local viewports reduce MediaQuery width.
  static bool horizontalOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<FrostAdaptiveLayoutData>()?.horizontal ??
      frostUsesSidebar(context, MediaQuery.sizeOf(context), FrostNavigationPlacement.automatic);

  @override
  bool updateShouldNotify(FrostAdaptiveLayoutData oldWidget) =>
      horizontal != oldWidget.horizontal || sizeClass != oldWidget.sizeClass || placement != oldWidget.placement;
}

enum FrostSizeClass {
  compact,
  medium,
  expanded,
  large;

  /// Default minimum width of this layout tier, usable against local space
  /// without reading the outer window's navigation classification.
  double get minimumWidth => switch (this) {
    compact => 0,
    medium => frostMobileBreakpoint,
    expanded => frostTabletBreakpoint,
    large => frostDesktopBreakpoint,
  };

  static FrostSizeClass of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<FrostAdaptiveLayoutData>()?.sizeClass ?? frostDefaultSizeClass(MediaQuery.sizeOf(context));
}

class FrostSizeLayout {
  const FrostSizeLayout({required this.size, required this.sizeClass});

  factory FrostSizeLayout.fromSize(Size size, {required double mobileBreakpoint, required double tabletBreakpoint, required double desktopBreakpoint}) {
    final width = size.width;
    final sizeClass = switch (width) {
      final value when value < mobileBreakpoint => FrostSizeClass.compact,
      final value when value < tabletBreakpoint => FrostSizeClass.medium,
      final value when value < desktopBreakpoint => FrostSizeClass.expanded,
      _ => FrostSizeClass.large,
    };

    return FrostSizeLayout(size: size, sizeClass: sizeClass);
  }

  final Size size;
  final FrostSizeClass sizeClass;

  double get width => size.width;

  double get height => size.height;

  double get shortestSide => size.shortestSide;

  bool get isCompact => sizeClass == FrostSizeClass.compact;

  bool get isMedium => sizeClass == FrostSizeClass.medium;

  bool get isExpanded => sizeClass == FrostSizeClass.expanded;

  bool get isLarge => sizeClass == FrostSizeClass.large;
}

/// The window shape rule: a sidebar beside the page, or phone-like pages with a
/// bottom bar. A window needs at least 360px content after a conservative 120px
/// navigation/frame reserve and must not be portrait. Touch asks for a clearly
/// wide viewport, since a tablet's near-square landscape reads as a phone page.
bool isHorizontalSize(Size size, {bool pointer = false}) => size.width >= 480 && size.width >= size.height * (pointer ? 1 : 1.3);
