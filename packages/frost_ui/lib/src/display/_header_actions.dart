import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../foundation/spacing.dart';
import '../primitives/_inline_or_below.dart';

/// Keeps the leading content and its actions mounted while moving the action
/// group below when their measured widths leave too little readable content.
/// Long paths and titles may elide, but actions must not squeeze the leading
/// content below half of the local column; short titles keep their natural room.
class FrostHeaderActions extends StatelessWidget {
  const FrostHeaderActions({required this.leading, required this.actions, required this.direction, super.key});
  final Widget leading, actions;
  final TextDirection direction;

  @override
  Widget build(BuildContext context) => FrostInlineOrBelow(
    start: leading,
    end: actions,
    direction: direction,
    gap: FrostGap.related,
    fillsStart: true,
    minimumStart: (natural, width) => math.min(natural(), width / 2),
  );
}
