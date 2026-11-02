part of 'picker.dart';

class _SegmentedPicker<T> extends _PickerImpl<T> {
  const _SegmentedPicker(super.picker);
  @override
  State<_PickerImpl<T>> createState() => _SegmentedPickerState<T>();
}

class _SegmentedPickerState<T> extends State<_PickerImpl<T>> with _PickerGroupFocus<T>, _PickerSegmentThumb<T>, _PickerField<T> {
  @override
  FocusNode? get _focusTarget => _groupFocus;
  @override
  Widget build(BuildContext context) => FrostControlScope(
    size: widget.picker.size,
    child: _PickerGroupField<T>(
      owner: this,
      child: _PickerSegments<T>(owner: this),
    ),
  );
}

/// Mutually exclusive modes on an inset track with one raised sliding thumb.
class _PickerSegments<T> extends StatelessWidget {
  const _PickerSegments({required this.owner, this.measurement = false});
  final _PickerSegmentThumb<T> owner;
  final bool measurement;
  List<FrostPickerOption<T>> get segments => owner.widget.picker.options;
  ValueChanged<T>? get onChanged => owner._enabled ? owner.widget.picker.onChanged : null;
  FrostControlSize? get size => owner.widget.picker.size;

  static const _trackPadding = FrostGap.inline;

  @override
  Widget build(BuildContext context) {
    if (segments.isEmpty) return const SizedBox.shrink();
    final tokens = FrostThemeTokens.of(context);
    final selectedIndex = owner._selected;
    final controlSize = size ?? FrostControlScope.sizeOf(context);
    final geometry = frostControlTextGeometry(
      baseHeight: controlSize.height(context),
      style: FrostTypography.of(context).style(FrostTextRole.callout),
      textScaler: MediaQuery.textScalerOf(context),
    );
    final height = geometry.height;
    final hitInset = math.max(0.0, (FrostDensity.of(context).targetHeight - height) / 2);
    final count = segments.length;
    final innerRadius = BorderRadius.circular(FrostRadius.inner(FrostRadius.forHeight(height), _trackPadding));
    return TweenAnimationBuilder<double>(
      tween: Tween(end: onChanged == null ? .38 : 1),
      duration: FrostMotion.duration(context, FrostMotion.hover),
      builder: (context, overallOpacity, _) => Opacity(
        opacity: overallOpacity,
        child: Semantics(
          container: true,
          explicitChildNodes: true,
          child: FrostControlTrack(
            height: height,
            verticalPaintInset: hitInset,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: height + hitInset * 2),
              // Equal flex inside IntrinsicWidth sizes every segment to the
              // widest label; a tight parent width still stretches the track.
              // When the width is too small (large text, narrow phones) labels
              // wrap to a second line and IntrinsicHeight grows the track.
              child: IntrinsicWidth(
                child: IntrinsicHeight(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        top: hitInset + _trackPadding,
                        bottom: hitInset + _trackPadding,
                        left: _trackPadding,
                        right: _trackPadding,
                        // The pill slides on a spring: a quick second tap
                        // redirects it from where it is, at its speed.
                        child: AnimatedOpacity(
                          opacity: selectedIndex != null ? 1 : 0,
                          duration: FrostMotion.duration(context, FrostMotion.hover),
                          child: FrostSpringBuilder(
                            value: owner._thumbIndex.toDouble(),
                            spring: FrostMotion.snappy,
                            builder: (context, position, child) => Align(
                              alignment: Alignment(
                                count == 1 ? 0 : (-1 + 2 * position / (count - 1)) * (Directionality.of(context) == TextDirection.rtl ? -1 : 1),
                                0,
                              ),
                              child: child,
                            ),
                            child: FractionallySizedBox(
                              widthFactor: 1 / count,
                              heightFactor: 1,
                              child: DecoratedBox(
                                decoration: ShapeDecoration(
                                  color: tokens.isDark
                                      ? Color.alphaBlend(tokens.fillStrong.withValues(alpha: .16), tokens.surfaceRaised)
                                      : tokens.surfaceRaised,
                                  shape: FrostScope.configOf(context).continuousCorners
                                      ? RoundedSuperellipseBorder(borderRadius: innerRadius)
                                      : RoundedRectangleBorder(borderRadius: innerRadius),
                                  shadows: tokens.shadowContact,
                                ),
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
                              child: ExcludeFocusTraversal(
                                excluding: measurement || index != owner._tabIndex,
                                child: _Segment(
                                  segment: segment,
                                  iconOnly: owner.widget.picker._iconOnly,
                                  focusNode: measurement ? null : owner._nodes[index],
                                  selected: index == selectedIndex,
                                  size: controlSize,
                                  borderRadius: innerRadius,
                                  onTap: segment.enabled && onChanged != null && index != selectedIndex ? () => owner._choose(index) : null,
                                  interactive: segment.enabled && onChanged != null,
                                  overallOpacity: overallOpacity,
                                  hitInset: hitInset + _trackPadding,
                                ),
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
      ),
    );
  }
}

class _Segment<T> extends StatelessWidget {
  const _Segment({
    required this.segment,
    required this.iconOnly,
    required this.focusNode,
    required this.selected,
    required this.size,
    required this.borderRadius,
    required this.onTap,
    required this.interactive,
    required this.overallOpacity,
    required this.hitInset,
  });

  final FrostPickerOption<T> segment;
  final bool iconOnly;
  final FocusNode? focusNode;
  final bool selected;
  final FrostControlSize size;
  final BorderRadius borderRadius;
  final VoidCallback? onTap;
  final bool interactive;
  final double overallOpacity;
  final double hitInset;

  /// Reserve selected-weight text so changing modes cannot resize the track.
  double _selectedContentWidth(BuildContext context, TextStyle selectedStyle) {
    final label = iconOnly ? null : segment.label;
    var width = 0.0;
    if (label != null) {
      final painter = TextPainter(
        text: TextSpan(text: label, style: selectedStyle),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
        maxLines: 1,
      )..layout();
      width = painter.width.ceilToDouble();
      painter.dispose();
    }
    if (segment.leading.icon != null) width += size.iconSize + (label != null ? _iconGap : 0);
    return width;
  }

  // Text-to-icon gaps follow the control size, not the layout spacing scale.
  static const _compactIconGap = 4.0, _regularIconGap = 6.0;
  double get _iconGap => size == FrostControlSize.small || size == FrostControlSize.compact ? _compactIconGap : _regularIconGap;

  @override
  Widget build(BuildContext context) {
    final tokens = FrostThemeTokens.of(context);
    final selectedStyle = FrostTypography.of(context).style(FrostTextRole.callout);
    final duration = FrostMotion.duration(context, FrostMotion.hover);
    final content = TweenAnimationBuilder<double>(
      tween: Tween(end: segment.enabled ? 1 : .38),
      duration: duration,
      // Avoid dimming a disabled segment twice when the whole control dims.
      // The composed opacity is the lower of the two animated opacities.
      builder: (context, segmentOpacity, child) => Opacity(opacity: math.min(1, segmentOpacity / overallOpacity), child: child),
      child: TweenAnimationBuilder<Color?>(
        tween: ColorTween(end: selected ? tokens.textPrimary : tokens.textSecondary),
        duration: duration,
        curve: FrostMotion.hoverCurve,
        builder: (context, foreground, _) => Padding(
          padding: EdgeInsets.symmetric(
            horizontal: size == FrostControlSize.small || size == FrostControlSize.compact ? 8 : 10,
            vertical: size == FrostControlSize.small || size == FrostControlSize.compact ? 0 : 2,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: _selectedContentWidth(context, selectedStyle)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (segment.leading.icon case final icon?) FrostIcon(icon, size: size.iconSize, color: foreground),
                if (segment.leading.icon != null && !iconOnly) SizedBox(width: _iconGap),
                if (!iconOnly)
                  Flexible(
                    child: FrostSkeletonText(
                      child: Text(
                        segment.label,
                        style: selectedStyle.copyWith(
                          color: foreground,
                          fontWeight: selected ? selectedStyle.fontWeight : FrostTypography.of(context).style(FrostTextRole.body).fontWeight,
                        ),
                        maxLines: FrostControlScope.toolbarOf(context) ? 1 : null,
                        textAlign: TextAlign.center,
                        overflow: FrostControlScope.toolbarOf(context) ? TextOverflow.ellipsis : TextOverflow.visible,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    Widget result = Semantics(
      button: true,
      label: iconOnly ? segment.label : null,
      selected: selected,
      enabled: interactive,
      inMutuallyExclusiveGroup: true,
      child: FrostInputSurface(
        focusNode: focusNode,
        // The selected segment keeps focus traversal but has nothing to do.
        onTap: onTap ?? (interactive ? () {} : null),
        builder: (context, states) => ConstrainedBox(
          constraints: BoxConstraints(minWidth: FrostDensity.of(context).targetHeight),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: hitInset),
            // Keep hover/press/focus paint inside the visual track, while the
            // input surface also owns the transparent platform target padding.
            child: FrostClickFeedbackVisual(
              states: states,
              feedback: FrostClickFeedback.quiet,
              shape: FrostScope.configOf(context).continuousCorners
                  ? RoundedSuperellipseBorder(borderRadius: borderRadius)
                  : RoundedRectangleBorder(borderRadius: borderRadius),
              child: Center(child: content),
            ),
          ),
        ),
      ),
    );
    if (iconOnly) result = FrostTooltip(message: segment.label, excludeFromSemantics: true, child: result);
    return result;
  }
}
