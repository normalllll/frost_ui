import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../controls/_button_control.dart';
import '../controls/_button_types.dart';
import '../controls/_close_control.dart';
import '../feedback/_skeleton_geometry.dart';
import '../foundation/_control_geometry.dart';
import '../foundation/density.dart';
import '../foundation/radius.dart';
import '../foundation/scope.dart';
import '../foundation/sizes.dart';
import '../foundation/tokens.dart';
import '../foundation/typography.dart';
import '_tag_metrics.dart';

// The centered separator is punctuation, not a translated UI message.
const _filterSeparator = ' · ';

/// An active filter, with independent body and clear actions.
class FrostFilterChip extends StatefulWidget {
  const FrostFilterChip({required this.label, this.value, this.onPressed, this.onClear, super.key});
  final String label;
  final String? value;
  final VoidCallback? onPressed, onClear;
  @override
  State<FrostFilterChip> createState() => _FilterChipState();
}

class _FilterChipState extends State<FrostFilterChip> {
  final _bodyFocus = FocusNode();
  String get label => widget.label;
  String? get value => widget.value;
  VoidCallback? get onPressed => widget.onPressed;
  VoidCallback? get onClear => widget.onClear;
  @override
  void dispose() {
    _bodyFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final density = FrostDensity.of(context);
    final touch = density.heightFor(FrostControlSize.regular) == FrostControlSize.regular.visualHeight(touch: true);
    final text = [label, ?value].join(_filterSeparator);
    final style = FrostTypography.of(context).style(FrostTextRole.footnote, tabular: true);
    final geometry = frostControlTextGeometry(
      baseHeight: touch ? frostTagTouchHeight : frostTagPointerHeight,
      style: style,
      textScaler: MediaQuery.textScalerOf(context),
    );
    final hitHeight = math.max(density.targetHeight, geometry.height);
    final paintInset = math.max(0.0, (hitHeight - geometry.height) / 2);
    return IntrinsicHeight(
      child: Stack(
        children: [
          Positioned.fill(
            top: paintInset,
            bottom: paintInset,
            child: DecoratedBox(
              decoration: ShapeDecoration(color: FrostThemeTokens.of(context).selectionFill, shape: FrostRadius.shape(context, FrostRadius.sm)),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Flexible(
                child: FrostTagButton(
                  label: text,
                  labelWidget: FrostSkeletonText(
                    child: Text(text, style: style.copyWith(color: FrostThemeTokens.of(context).selectionInk)),
                  ),
                  onPressed: onPressed,
                  focusNode: _bodyFocus,
                  selected: true,
                  size: FrostControlSize.compact,
                  chevron: onPressed == null ? FrostButtonChevron.none : FrostButtonChevron.down,
                  truncates: false,
                  wrapsLabel: true,
                  geometry: FrostButtonGeometry(
                    horizontalInset: frostTagInset,
                    verticalInset: 0,
                    minimumWidth: 0,
                    alignment: MainAxisAlignment.start,
                    visualHeight: geometry.height,
                    cornerRadius: FrostRadius.sm,
                  ),
                ),
              ),
              if (onClear != null)
                FrostCloseControl(
                  label: FrostScope.labelsOf(context).clearText,
                  onPressed: onClear!,
                  height: hitHeight,
                  foreground: FrostThemeTokens.of(context).selectionInk,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
