import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:frost_ui/src/foundation/metrics.dart';
import 'package:frost_ui/src/layout/column_placement.dart';

/// Measures content in the space remaining after window navigation.
class FrostContentViewport extends StatelessWidget {
  const FrostContentViewport({required this.child, this.navigationReserve, super.key});
  final Widget child;
  final double? navigationReserve;

  @override
  Widget build(BuildContext context) {
    final reserve = navigationReserve ?? FrostContentColumnBudget.of(context);
    return LayoutBuilder(
      builder: (context, constraints) => FrostContentColumnBudget(
        reservedWidth: reserve,
        child: MediaQuery(
          data: MediaQuery.of(context).copyWith(size: Size(constraints.maxWidth, constraints.maxHeight)),
          child: child,
        ),
      ),
    );
  }
}

/// Keeps responsive column counts stable while the user opens the sidebar.
/// The count still follows the window, text scale, and each grid's own inset.
class FrostContentColumnBudget extends InheritedWidget {
  const FrostContentColumnBudget({required this.reservedWidth, required super.child, super.key});

  final double reservedWidth;

  static double of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<FrostContentColumnBudget>()?.reservedWidth ?? 0;

  static double columnWidth(BuildContext context, double availableWidth) => math.max(0, availableWidth - of(context));

  @override
  bool updateShouldNotify(FrostContentColumnBudget oldWidget) => reservedWidth != oldWidget.reservedWidth;
}

/// A page's content column: centred, at most [maxWidth] wide, and inset by
/// [FrostMetrics.columnPadding] so every page shares the same edges.
class FrostContentColumn extends StatelessWidget {
  const FrostContentColumn({required this.child, this.maxWidth = FrostMetrics.contentMaxWidth, this.bleed = 0, super.key});

  final Widget child;
  final double maxWidth;

  /// How far the box reaches past the column on each side, for rows whose
  /// children carry that much inset themselves (padded buttons and tabs), so
  /// their visible content still lands on the column edge.
  final double bleed;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final column = FrostColumnPlacement.columnPadding(context, constraints.maxWidth, maxWidth: maxWidth);
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: math.max(0, column.left - bleed)),
          child: child,
        );
      },
    );
  }
}

/// [FrostContentColumn] for a sliver inside a scroll view; the scroll view itself
/// stays full width so its scrollbar remains at the window edge.
class FrostSliverContentColumn extends StatelessWidget {
  const FrostSliverContentColumn({required this.sliver, this.maxWidth = FrostMetrics.contentMaxWidth, super.key});

  final Widget sliver;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return SliverLayoutBuilder(
      builder: (context, constraints) => SliverPadding(
        padding: FrostColumnPlacement.columnPadding(context, constraints.crossAxisExtent, maxWidth: maxWidth),
        sliver: sliver,
      ),
    );
  }
}
