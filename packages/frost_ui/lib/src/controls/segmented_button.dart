import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:frost_ui/src/controls/icon.dart';
import 'package:frost_ui/src/foundation/metrics.dart';
import 'package:frost_ui/src/foundation/tokens.dart';
import 'package:frost_ui/src/motion/spring.dart';
import 'package:frost_ui/src/controls/click_surface.dart';

/// Mutually exclusive mode switch: an inset track with one raised pill that
/// slides to the selected segment. Selection is carried by the pill, the
/// accent ink and the heavier weight, so it never depends on colour alone.
class FrostSegmentedButton<T> extends StatelessWidget {
  const FrostSegmentedButton({required this.segments, required this.selected, required this.onSelectionChanged, this.showSelectedIcon = false, super.key});
  final List<ButtonSegment<T>> segments;
  final Set<T> selected;
  final ValueChanged<Set<T>>? onSelectionChanged;

  /// Adds a check to the selected segment when the segments carry no icons.
  final bool showSelectedIcon;

  static const _trackPadding = 3.0;

  @override
  Widget build(BuildContext context) {
    final tokens = FrostThemeTokens.of(context);
    final selectedIndex = math.max(0, segments.indexWhere((segment) => selected.contains(segment.value)));
    final height = FrostMetrics.fieldHeight(context);
    final count = segments.length;
    final radius = BorderRadius.circular(FrostMetrics.controlRadius);
    final innerRadius = BorderRadius.circular(FrostMetrics.controlRadius - _trackPadding);
    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: DecoratedBox(
        decoration: BoxDecoration(color: tokens.surfaceInset, borderRadius: radius),
        child: Padding(
          padding: const EdgeInsets.all(_trackPadding),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: height - _trackPadding * 2),
            // Equal flex inside IntrinsicWidth sizes every segment to the
            // widest label; a tight parent width still stretches the track.
            // When the width is too small (large text, narrow phones) labels
            // wrap to a second line and IntrinsicHeight grows the track.
            child: IntrinsicWidth(
              child: IntrinsicHeight(
                child: Stack(
                  children: [
                    Positioned.fill(
                      // The pill slides on a spring: a quick second tap
                      // redirects it from where it is, at its speed.
                      child: FrostSpringBuilder(
                        value: selectedIndex.toDouble(),
                        spring: FrostMotion.snappy,
                        builder: (context, position, child) => Align(alignment: Alignment(count == 1 ? 0 : -1 + 2 * position / (count - 1), 0), child: child),
                        child: FractionallySizedBox(
                          widthFactor: 1 / count,
                          heightFactor: 1,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: tokens.isDark ? tokens.surfaceMuted : tokens.surfaceRaised,
                              borderRadius: innerRadius,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: tokens.isDark ? .24 : .08),
                                  blurRadius: 6,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final (index, segment) in segments.indexed)
                          Expanded(
                            child: _Segment(
                              segment: segment,
                              selected: index == selectedIndex,
                              showSelectedIcon: showSelectedIcon,
                              borderRadius: innerRadius,
                              onTap: segment.enabled && onSelectionChanged != null && index != selectedIndex
                                  ? () => onSelectionChanged!({segment.value})
                                  : null,
                              interactive: segment.enabled && onSelectionChanged != null,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Segment<T> extends StatelessWidget {
  const _Segment({
    required this.segment,
    required this.selected,
    required this.showSelectedIcon,
    required this.borderRadius,
    required this.onTap,
    required this.interactive,
  });

  final ButtonSegment<T> segment;
  final bool selected;
  final bool showSelectedIcon;
  final BorderRadius borderRadius;
  final VoidCallback? onTap;
  final bool interactive;

  /// Width of the content when selected: a text label in the selected weight
  /// beside the icon, or the check that selection adds. A label that is not
  /// a [Text] reserves only the icon.
  double _selectedContentWidth(BuildContext context, TextStyle? selectedStyle) {
    final label = segment.label;
    final span = switch (label) {
      Text(:final data?, :final style) => TextSpan(text: data, style: selectedStyle?.merge(style) ?? style),
      Text(:final textSpan?, :final style) => TextSpan(children: [textSpan], style: selectedStyle?.merge(style) ?? style),
      _ => null,
    };
    var width = 0.0;
    if (span != null) {
      final painter = TextPainter(text: span, textDirection: Directionality.of(context), textScaler: MediaQuery.textScalerOf(context), maxLines: 1)..layout();
      width = painter.width.ceilToDouble();
      painter.dispose();
    }
    final icon = segment.icon;
    final iconWidth = switch (icon) {
      null => showSelectedIcon ? 18.0 : 0.0,
      Icon(:final size?) || FrostIcon(:final size?) => size,
      _ => 18.0,
    };
    if (iconWidth > 0) width += iconWidth + (label != null ? 6 : 0);
    return width;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = FrostThemeTokens.of(context);
    final theme = Theme.of(context);
    final foreground = !interactive
        ? tokens.disabledText
        : selected
        ? tokens.selectionInk
        : tokens.textSecondary;
    final icon = segment.icon ?? (showSelectedIcon && selected ? FrostIcon(FrostIconSet.of(context).check) : null);
    final selectedStyle = theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600);
    final content = IconTheme.merge(
      data: IconThemeData(size: 18, color: foreground),
      child: DefaultTextStyle.merge(
        style: theme.textTheme.labelLarge?.copyWith(color: foreground, fontWeight: selected ? FontWeight.w600 : FontWeight.w500),
        // Two lines before an ellipsis, so large text never hides a label.
        maxLines: 2,
        textAlign: TextAlign.center,
        overflow: TextOverflow.ellipsis,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          // Every segment reserves its selected size (heavier weight, check
          // mark), so selecting one never changes the control's width.
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: _selectedContentWidth(context, selectedStyle)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                ?icon,
                if (icon != null && segment.label != null) const SizedBox(width: 6),
                if (segment.label case final label?) Flexible(child: label),
              ],
            ),
          ),
        ),
      ),
    );
    Widget result = Semantics(
      button: true,
      selected: selected,
      enabled: interactive,
      inMutuallyExclusiveGroup: true,
      child: FrostClickSurface(
        // The selected segment keeps focus traversal but has nothing to do.
        onTap: onTap ?? (interactive ? () {} : null),
        feedback: selected ? FrostClickFeedback.media : FrostClickFeedback.quiet,
        borderRadius: borderRadius,
        child: Center(child: content),
      ),
    );
    if (segment.tooltip case final tooltip?) result = Tooltip(message: tooltip, child: result);
    return result;
  }
}

class FrostConstrainedSegmentedButton<T> extends StatelessWidget {
  const FrostConstrainedSegmentedButton({
    required this.segments,
    required this.selected,
    required this.onSelectionChanged,
    this.maxWidth = 420,
    this.alignment = AlignmentDirectional.centerStart,
    super.key,
  });

  final List<ButtonSegment<T>> segments;
  final Set<T> selected;
  final ValueChanged<Set<T>> onSelectionChanged;
  final double? maxWidth;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    final button = SizedBox(
      width: double.infinity,
      child: FrostSegmentedButton<T>(segments: segments, selected: selected, onSelectionChanged: onSelectionChanged),
    );
    final constrainedButton = maxWidth == null
        ? button
        : ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth!),
            child: button,
          );

    return Align(alignment: alignment, child: constrainedButton);
  }
}
