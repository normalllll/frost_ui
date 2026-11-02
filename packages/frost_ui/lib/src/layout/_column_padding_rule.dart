import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../foundation/metrics.dart';
import '../primitives/_page_outline.dart';
import '_content_padding.dart';
import 'column_placement.dart';

/// [FrostColumnPlacement.columnPadding] as a rule over the width, for layout to
/// apply: it reads the environment now and nothing later.
EdgeInsets Function(double width) frostColumnPaddingRule(BuildContext context, {double maxWidth = FrostMetrics.contentMaxWidth}) {
  final placement = FrostColumnPlacement.maybeOf(context);
  final channel = FrostPageOutline.channelOf(context);
  final padding = FrostContentPadding.of(context);
  final column = placement?.maxWidth == null ? maxWidth : math.min(maxWidth, placement!.maxWidth!);
  return (width) {
    final contentWidth = math.max(0.0, width - channel);
    final inset = padding ?? EdgeInsets.symmetric(horizontal: FrostMetrics.browseInset(contentWidth));
    // An unbounded width has no free space to share, whatever the column.
    final free = contentWidth.isFinite ? math.max(0.0, contentWidth - column) : 0.0;
    return switch (placement?.alignment ?? FrostColumnAlignment.center) {
      FrostColumnAlignment.center => EdgeInsets.only(left: free / 2 + inset.left, right: free / 2 + inset.right + channel),
      FrostColumnAlignment.start => EdgeInsets.only(left: inset.left, right: free + inset.right + channel),
      FrostColumnAlignment.end => EdgeInsets.only(left: free + inset.left, right: inset.right + channel),
    };
  };
}
