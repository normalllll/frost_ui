import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:frost_ui/src/foundation/metrics.dart';

/// Where content columns sit in their viewport.
enum FrostColumnAlignment { start, center, end }

/// Places every content column below: centred by default; in a pane of a
/// split view, against the divider, so both panes meet in the middle of the
/// window while each viewport still reaches its own edge (and keeps its
/// scrollbar there). [maxWidth] caps the columns to the pane's content width.
class FrostColumnPlacement extends InheritedWidget {
  const FrostColumnPlacement({required this.alignment, required super.child, this.maxWidth, super.key});

  final FrostColumnAlignment alignment;
  final double? maxWidth;

  static FrostColumnPlacement? maybeOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<FrostColumnPlacement>();

  /// The width a column asking for [maxWidth] gets here.
  static double columnWidth(BuildContext context, double maxWidth) {
    final cap = maybeOf(context)?.maxWidth;
    return cap == null ? maxWidth : math.min(maxWidth, cap);
  }

  /// Horizontal padding that places a column of at most [maxWidth] (its
  /// inset included) in a viewport of [width], like
  /// [FrostMetrics.columnPadding] but following the nearest placement. The
  /// inset is the one [maxWidth] asks for, so a capped reading column keeps
  /// the reading inset.
  static EdgeInsets columnPadding(BuildContext context, double width, {double maxWidth = FrostMetrics.contentMaxWidth}) {
    final placement = maybeOf(context);
    final inset = maxWidth == FrostMetrics.readingMaxWidth ? FrostMetrics.pageInset : FrostMetrics.browseInset(width);
    final column = placement?.maxWidth == null ? maxWidth : math.min(maxWidth, placement!.maxWidth!);
    final free = math.max(0.0, width - column);
    return switch (placement?.alignment ?? FrostColumnAlignment.center) {
      FrostColumnAlignment.center => EdgeInsets.symmetric(horizontal: free / 2 + inset),
      FrostColumnAlignment.start => EdgeInsets.only(left: inset, right: free + inset),
      FrostColumnAlignment.end => EdgeInsets.only(left: free + inset, right: inset),
    };
  }

  /// Where a box of [columnWidth] sits in its viewport here.
  static Alignment alignmentOf(BuildContext context) => switch (maybeOf(context)?.alignment ?? FrostColumnAlignment.center) {
    FrostColumnAlignment.center => Alignment.topCenter,
    FrostColumnAlignment.start => Alignment.topLeft,
    FrostColumnAlignment.end => Alignment.topRight,
  };

  @override
  bool updateShouldNotify(FrostColumnPlacement oldWidget) => alignment != oldWidget.alignment || maxWidth != oldWidget.maxWidth;
}
