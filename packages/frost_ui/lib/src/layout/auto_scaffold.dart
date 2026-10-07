import 'package:flutter/material.dart';

typedef FrostAutoScaffoldBuilder = Widget Function(BuildContext context, FrostSizeLayout layout, Orientation orientation, bool useHorizontalLayout);

class FrostAutoScaffold extends StatelessWidget {
  const FrostAutoScaffold({required this.builder, this.mobileBreakpoint = 600, this.tabletBreakpoint = 900, this.desktopBreakpoint = 1200, super.key});

  final FrostAutoScaffoldBuilder builder;
  final double mobileBreakpoint;
  final double tabletBreakpoint;
  final double desktopBreakpoint;

  static bool usesHorizontalLayoutOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_ShellLayout>()?.horizontal ?? isHorizontalSize(MediaQuery.sizeOf(context));

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final orientation = size.width >= size.height ? Orientation.landscape : Orientation.portrait;

    final layout = FrostSizeLayout.fromSize(size, mobileBreakpoint: mobileBreakpoint, tabletBreakpoint: tabletBreakpoint, desktopBreakpoint: desktopBreakpoint);

    final horizontal = usesHorizontalLayoutOf(context);
    return _ShellLayout(horizontal: horizontal, child: builder(context, layout, orientation, horizontal));
  }
}

// Descendants use the window's navigation mode even after ContentViewport
// subtracts the sidebar or a detail pane constrains the available content width.
class _ShellLayout extends InheritedWidget {
  const _ShellLayout({required this.horizontal, required super.child});
  final bool horizontal;

  @override
  bool updateShouldNotify(_ShellLayout oldWidget) => horizontal != oldWidget.horizontal;
}

enum FrostSizeClass { compact, medium, expanded, large }

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

/// Navigation responds to window width, even in a short or landscape window.
bool isHorizontalSize(Size size) => size.width >= 600;

/// Install above the router so nested viewports and keyboards cannot change mode.
class FrostLayoutScope extends StatelessWidget {
  const FrostLayoutScope({required this.child, super.key});
  final Widget child;

  @override
  Widget build(BuildContext context) => _ShellLayout(horizontal: isHorizontalSize(MediaQuery.sizeOf(context)), child: child);
}
