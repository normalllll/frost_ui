import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../foundation/metrics.dart';
import '_column_padding_rule.dart';

/// Where content columns sit in their viewport.
enum FrostColumnAlignment { start, center, end }

/// Places every content column below: a capped column is centred by default; in
/// a pane of a split view, against the divider, so both panes meet in the middle of the
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
  static EdgeInsets columnPadding(BuildContext context, double width, {double maxWidth = FrostMetrics.contentMaxWidth}) =>
      frostColumnPaddingRule(context, maxWidth: maxWidth)(width);

  /// Where a box of [columnWidth] sits in its viewport here.
  static Alignment alignmentOf(BuildContext context) => switch (maybeOf(context)?.alignment ?? FrostColumnAlignment.center) {
    FrostColumnAlignment.center => Alignment.topCenter,
    FrostColumnAlignment.start => Alignment.topLeft,
    FrostColumnAlignment.end => Alignment.topRight,
  };

  @override
  bool updateShouldNotify(FrostColumnPlacement oldWidget) => alignment != oldWidget.alignment || maxWidth != oldWidget.maxWidth;
}

/// Library-only: the width a page template gives its columns, so a column placed
/// inside the page (a heading, an inline search) lines up with its content.
class FrostPageColumnWidth extends InheritedWidget {
  const FrostPageColumnWidth({required this.width, required super.child, super.key});
  final double width;

  /// The enclosing template's width; outside one, a page is a capped column.
  static double of(BuildContext context) {
    final page = context.dependOnInheritedWidgetOfExactType<FrostPageColumnWidth>();
    return page == null ? FrostMetrics.contentMaxWidth : page.width;
  }

  @override
  bool updateShouldNotify(FrostPageColumnWidth oldWidget) => width != oldWidget.width;
}
