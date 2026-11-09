import 'package:flutter/widgets.dart';

import '../foundation/_control_dimming.dart';
import '../foundation/control_scope.dart';
import '../foundation/icon_data.dart';
import '../foundation/sizes.dart';
import '../foundation/typography.dart';
import '../primitives/text.dart';
import '_button_control.dart';
import '_button_types.dart';
import '_field_layout.dart';
import '_field_options.dart';

/// The content-field trigger shared by value, date and range selectors.
class FrostFieldTrigger extends StatelessWidget {
  const FrostFieldTrigger({
    required this.label,
    required this.value,
    required this.onPressed,
    required this.focus,
    this.size,
    this.help,
    this.error,
    this.leading,
    this.leadingWidget,
    this.trailing,
    this.chevron = FrostButtonChevron.none,
    super.key,
  });
  final String label, value;
  final VoidCallback? onPressed;
  final FocusNode focus;
  final FrostControlSize? size;
  final String? help, error;
  final FrostIconData? leading;

  /// Drawn in the icon slot instead of [leading]; the caller sizes it.
  final Widget? leadingWidget;
  final Widget? trailing;
  final FrostButtonChevron chevron;
  @override
  Widget build(BuildContext context) {
    final selectedSize = size ?? FrostControlScope.sizeOf(context);
    final geometry = frostControlGeometry(context, selectedSize), enabled = onPressed != null && FrostControlScope.enabledOf(context);
    return FrostFieldOptions(
      invalid: error != null || (FrostFieldOptions.of(context)?.invalid ?? false),
      child: FrostFieldLayout(
        label: label,
        help: help,
        error: error,
        enabled: enabled,
        child: FrostFieldButton(
          label: value,
          // The inset belongs to the text: a trailing control keeps the full field
          // height for its target without making the field taller.
          labelWidget: Padding(
            padding: EdgeInsets.symmetric(vertical: geometry.verticalInset),
            child: ExcludeSemantics(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: selectedSize.iconSize),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  heightFactor: 1,
                  child: FrostText(value, role: FrostTextRole.body, maxLines: null, overflow: TextOverflow.visible),
                ),
              ),
            ),
          ),
          icon: leading,
          iconWidget: leadingWidget,
          focusNode: focus,
          onPressed: enabled ? onPressed : null,
          size: selectedSize,
          textRole: FrostTextRole.body,
          chevron: chevron,
          geometry: FrostButtonGeometry(
            horizontalInset: frostFieldInset(selectedSize),
            verticalInset: 0,
            minimumWidth: 0,
            alignment: MainAxisAlignment.start,
            visualHeight: geometry.height,
          ),
          truncates: false,
          wrapsLabel: true,
          exposesTrailing: trailing != null,
          trailing: trailing == null ? null : FrostControlDimming(disabled: !enabled, child: trailing!),
        ),
      ),
    );
  }
}
