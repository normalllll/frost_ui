import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../controls/_input_surface.dart';
import '../feedback/_skeleton_geometry.dart';
import '../foundation/_key_bindings.dart';
import '../foundation/control_scope.dart';
import '../foundation/density.dart';
import '../foundation/metrics.dart';
import '../foundation/radius.dart';
import '../foundation/scope.dart';
import '../foundation/tokens.dart';
import '../foundation/typography.dart';
import '../motion/spring.dart';
import '../primitives/_click_feedback.dart';

// The visual spacing is independent of the shared pointer/touch hit height.
const _dotDiameter = 6.0;
const _dotSpacing = 6.0;
const _selectedWidth = 16.0;
const _maximumDotCount = 10;
const _onMediaInactiveOpacity = .4;
const _plateHorizontalPadding = 8.0;
const _plateVerticalPadding = 4.0;
const _plateRadius = 4.0;

/// Internal: paints the pager's media plate around the indicator's marks.
///
/// The plate fits the dots or the counter; the hit band keeps its own height
/// and may extend past the plate.
class FrostPageIndicatorPlate extends InheritedWidget {
  const FrostPageIndicatorPlate({required super.child, super.key});

  static bool isPresent(BuildContext context) => context.dependOnInheritedWidgetOfExactType<FrostPageIndicatorPlate>() != null;

  /// The indicator's offset from the bottom edge that puts the plate [inset]
  /// away from it while keeping the whole hit band inside that edge.
  static double bottomOffset(BuildContext context, {required int count, required double inset}) {
    if (count > _maximumDotCount) return inset;
    final overhang = (FrostDensity.of(context).targetHeight - (_dotDiameter + _plateVerticalPadding * 2)) / 2;
    return math.max(inset - overhang, 0);
  }

  @override
  bool updateShouldNotify(FrostPageIndicatorPlate oldWidget) => false;
}

class _Plate extends StatelessWidget {
  const _Plate({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: ShapeDecoration(color: FrostThemeTokens.of(context).onMediaScrim, shape: FrostRadius.shape(context, _plateRadius)),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: _plateHorizontalPadding, vertical: _plateVerticalPadding),
      child: child,
    ),
  );
}

/// Compact page feedback: dots through ten pages, then a localized counter.
///
/// A selectable indicator has one target-height hit band. Its horizontal
/// partitions meet midway between the actual dot centers, with half a gap
/// beyond each end, or out to the plate's ends under a plate. RTL mirrors both
/// painting and selection. It is one Tab stop: the arrow keys move a page, and
/// Enter or Space goes to the next one.
class FrostPageIndicator extends StatelessWidget {
  const FrostPageIndicator({required this.count, required this.current, this.onSelected, this.onMedia = false, super.key})
    : assert(count >= 0),
      assert(count == 0 || (current >= 0 && current < count));
  final int count;
  final int current;
  final ValueChanged<int>? onSelected;
  final bool onMedia;

  /// Right goes to the next page and Left to the previous one, mirrored in RTL.
  Map<ShortcutActivator, bool Function()> _keys(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    bool forward() {
      if (current < count - 1) onSelected!(current + 1);
      return true;
    }

    bool backward() {
      if (current > 0) onSelected!(current - 1);
      return true;
    }

    return {
      const FrostKeyPress(LogicalKeyboardKey.arrowRight): rtl ? backward : forward,
      const FrostKeyPress(LogicalKeyboardKey.arrowLeft): rtl ? forward : backward,
    };
  }

  @override
  Widget build(BuildContext context) {
    if (count <= 1) return const SizedBox.shrink();
    final onSelected = FrostControlScope.enabledOf(context) ? this.onSelected : null;
    final tokens = FrostThemeTokens.of(context);
    final active = onMedia ? tokens.onMediaInk : tokens.textPrimary;
    final inactive = onMedia ? tokens.onMediaInk.withValues(alpha: _onMediaInactiveOpacity) : tokens.textTertiary;
    final value = FrostScope.labelsOf(context).pageOf(current + 1, count);
    final labels = FrostScope.labelsOf(context);
    final next = onSelected == null ? null : () => onSelected((current + 1) % count);
    final plated = FrostPageIndicatorPlate.isPresent(context);
    Widget marks(Widget child) => plated ? _Plate(child: child) : child;
    final bandEdge = plated ? _plateHorizontalPadding : _dotSpacing / 2;
    return Semantics(
      container: true,
      button: this.onSelected != null,
      enabled: this.onSelected == null ? null : onSelected != null,
      label: this.onSelected == null ? null : labels.next,
      onTap: next,
      value: value,
      increasedValue: onSelected != null && current < count - 1 ? FrostScope.labelsOf(context).pageOf(current + 2, count) : null,
      decreasedValue: onSelected != null && current > 0 ? FrostScope.labelsOf(context).pageOf(current, count) : null,
      onIncrease: onSelected != null && current < count - 1 ? () => onSelected(current + 1) : null,
      onDecrease: onSelected != null && current > 0 ? () => onSelected(current - 1) : null,
      excludeSemantics: true,
      child: _Focusable(
        keys: onSelected == null ? null : _keys(context),
        onActivate: next,
        child: count > _maximumDotCount
            ? marks(
                FrostSkeletonText(
                  child: Text(value, style: FrostTypography.of(context).style(FrostTextRole.callout, tabular: true).copyWith(color: active)),
                ),
              )
            : FrostSpringBuilder(
                value: current.toDouble(),
                spring: FrostMotion.snappy,
                builder: (context, progress, _) {
                  final position = progress.clamp(0.0, (count - 1).toDouble());
                  final widths = List.generate(
                    count,
                    (index) => _dotDiameter + (_selectedWidth - _dotDiameter) * (1 - (position - index).abs()).clamp(0.0, 1.0),
                  );
                  final centers = <double>[];
                  var offset = 0.0;
                  for (final width in widths) {
                    centers.add(offset + width / 2);
                    offset += width + _dotSpacing;
                  }
                  final total = offset - _dotSpacing;
                  final pillWidth = widths.reduce(math.max);
                  final pillStart = position * (_dotDiameter + _dotSpacing) + (_selectedWidth - pillWidth) / 2;
                  final visual = SizedBox(
                    width: total,
                    height: _dotDiameter,
                    child: Stack(
                      children: [
                        Row(
                          children: [
                            for (var index = 0; index < count; index++) ...[
                              if (index > 0) const SizedBox(width: _dotSpacing),
                              SizedBox(
                                width: widths[index],
                                child: Center(
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(color: inactive, borderRadius: FrostRadius.borderRadius(FrostRadius.full(_dotDiameter))),
                                    child: const SizedBox(width: _dotDiameter, height: _dotDiameter),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        PositionedDirectional(
                          start: pillStart,
                          top: 0,
                          width: pillWidth,
                          height: _dotDiameter,
                          child: DecoratedBox(
                            decoration: BoxDecoration(color: active, borderRadius: FrostRadius.borderRadius(FrostRadius.full(_dotDiameter))),
                          ),
                        ),
                      ],
                    ),
                  );
                  if (this.onSelected == null) return marks(visual);
                  final band = SizedBox(
                    width: total + bandEdge * 2,
                    height: FrostDensity.of(context).targetHeight,
                    child: Center(child: marks(visual)),
                  );
                  if (onSelected == null) return band;
                  final rtl = Directionality.of(context) == TextDirection.rtl;
                  return MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      excludeFromSemantics: true,
                      onTapUp: (details) {
                        final x = (rtl ? total + bandEdge * 2 - details.localPosition.dx : details.localPosition.dx) - bandEdge;
                        var nearest = 0;
                        for (var index = 1; index < count; index++) {
                          if ((centers[index] - x).abs() < (centers[nearest] - x).abs()) nearest = index;
                        }
                        onSelected(nearest);
                      },
                      child: band,
                    ),
                  );
                },
              ),
      ),
    );
  }
}

/// The indicator's one Tab stop, with a focus ring and no other feedback.
class _Focusable extends StatelessWidget {
  const _Focusable({required this.keys, required this.onActivate, required this.child});
  final Map<ShortcutActivator, bool Function()>? keys;
  final VoidCallback? onActivate;
  final Widget child;

  @override
  Widget build(BuildContext context) => onActivate == null
      ? child
      : FrostKeyBindings(
          bindings: keys ?? const {},
          child: FrostInputSurface(
            onTap: onActivate,
            builder: (context, states) =>
                FrostClickFeedbackVisual(states: states.intersection({WidgetState.focused}), shape: FrostRadius.shape(context, FrostRadius.sm), child: child),
          ),
        );
}
