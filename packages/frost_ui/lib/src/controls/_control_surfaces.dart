import 'package:flutter/material.dart';

import '../foundation/control_scope.dart';
import '../foundation/metrics.dart';
import '../foundation/radius.dart';
import '../foundation/tokens.dart';

/// Shared inset track material for segmented controls and steppers.
class FrostControlTrack extends StatelessWidget {
  const FrostControlTrack({required this.height, required this.child, this.verticalPaintInset = 0, super.key});
  final double height;
  final double verticalPaintInset;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final tokens = FrostThemeTokens.of(context);
    final painted = AnimatedContainer(
      duration: FrostMotion.duration(context, FrostMotion.hover),
      curve: FrostMotion.hoverCurve,
      decoration: ShapeDecoration(
        color: FrostControlScope.toolbarOf(context) ? tokens.fillSubtle : tokens.fill,
        shape: FrostRadius.shape(context, FrostRadius.forHeight(height)),
      ),
      child: verticalPaintInset == 0 ? child : null,
    );
    return verticalPaintInset == 0
        ? painted
        : Stack(
            fit: StackFit.passthrough,
            children: [
              Positioned.fill(top: verticalPaintInset, bottom: verticalPaintInset, child: painted),
              child,
            ],
          );
  }
}

// An inset physical hairline stays visible on a light track without changing
// the thumb geometry. Switch keeps its existing borderless presentation.
const _thumbEdgePhysicalPixels = 1.0;

/// The same white, raised thumb material for switches and sliders.
class FrostControlThumb extends StatelessWidget {
  const FrostControlThumb({required this.height, this.showsEdge = false, super.key});
  final double height;
  final bool showsEdge;
  @override
  Widget build(BuildContext context) {
    final tokens = FrostThemeTokens.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.controlThumbFill,
        borderRadius: BorderRadius.circular(height / 2),
        border: showsEdge ? Border.all(color: tokens.line, width: _thumbEdgePhysicalPixels / MediaQuery.devicePixelRatioOf(context)) : null,
        boxShadow: tokens.shadowContact,
      ),
    );
  }
}
