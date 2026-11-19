import 'dart:math' as math;
import 'package:flutter/widgets.dart';

/// The page's panel and its scrollbar channel: a strip at the panel's
/// physical right, inside the panel, where the page's scrollbar paints.
/// The surface consumes only paint ownership; columns keep the channel clear.
class FrostPageOutline extends InheritedWidget {
  const FrostPageOutline({super.key, required this.radius, this.scrollbarChannel = 0, this.channelClaimed = false, required super.child});
  final BorderRadius radius;
  final double scrollbarChannel;
  final bool channelClaimed;
  static FrostPageOutline? maybeOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<FrostPageOutline>();
  static BorderRadius of(BuildContext context) => maybeOf(context)?.radius ?? BorderRadius.zero;
  static double channelOf(BuildContext context) => maybeOf(context)?.scrollbarChannel ?? 0;
  static double contentWidth(BuildContext context, double width) => math.max(0, width - channelOf(context));

  /// Columns already reserved the channel; descendants must not add it again.
  static Widget content(BuildContext context, Widget child) => FrostPageOutline(radius: of(context), channelClaimed: true, child: child);
  Widget consumeSurface(Widget child) => FrostPageOutline(radius: radius, scrollbarChannel: scrollbarChannel, channelClaimed: true, child: child);
  @override
  bool updateShouldNotify(FrostPageOutline oldWidget) =>
      radius != oldWidget.radius || scrollbarChannel != oldWidget.scrollbarChannel || channelClaimed != oldWidget.channelClaimed;
}

/// Images keep the panel's curved corners while a page moves inside it.
class FrostPageViewportClip extends CustomClipper<Path> {
  const FrostPageViewportClip({required this.radius, required this.continuous});
  final BorderRadius radius;
  final bool continuous;
  @override
  Path getClip(Size size) {
    final shape = continuous ? RoundedSuperellipseBorder(borderRadius: radius) : RoundedRectangleBorder(borderRadius: radius);
    return shape.getOuterPath(Offset.zero & size);
  }

  @override
  bool shouldReclip(FrostPageViewportClip oldClipper) => radius != oldClipper.radius || continuous != oldClipper.continuous;
}
