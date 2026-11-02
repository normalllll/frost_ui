import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../foundation/_control_geometry.dart';
import '../foundation/control_scope.dart';
import '../foundation/sizes.dart';
import '../foundation/tokens.dart';
import '../foundation/typography.dart';
import '../primitives/_measured_layout_builder.dart';
import '../primitives/icon.dart';
import '_button_control.dart';
import 'field_appearance.dart';

/// A search-shaped button. The App owns navigation, shortcuts and query storage.
class FrostSearchEntry extends StatelessWidget {
  const FrostSearchEntry({required this.placeholder, required this.onPressed, this.value, this.shortcutLabel, this.size, this.focusNode, super.key});
  final String placeholder;
  final String? value, shortcutLabel;
  final VoidCallback? onPressed;
  final FrostControlSize? size;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final size = this.size ?? FrostControlScope.sizeOf(context);
    final text = value?.isNotEmpty == true ? value! : placeholder;
    final tokens = FrostThemeTokens.of(context);
    final geometry = frostControlGeometry(context, size);
    final labelStyle = FrostTypography.of(context).style(FrostTextRole.body);
    return FrostMeasuredLayoutBuilder(
      naturalSize: Size(
        size.iconSize + 24 + math.max(MediaQuery.textScalerOf(context).scale(56), frostTextLineSize(context, text, labelStyle).width),
        geometry.height,
      ),
      builder: (context, limits) {
        // Collapse from actual available width, without platform branches in pages.
        final iconOnly = limits.maxWidth < size.iconSize + 24 + MediaQuery.textScalerOf(context).scale(56);
        return FrostFieldScope(
          appearance: FrostFieldAppearance.subtle,
          child: FrostFieldButton(
            label: text,
            semanticLabel: [placeholder, if (value?.isNotEmpty == true) value!, ?shortcutLabel].join(', '),
            onPressed: FrostControlScope.enabledOf(context) ? onPressed : null,
            focusNode: focusNode,
            icon: FrostIconSet.of(context).search,
            size: size,
            search: true,
            showsLabel: !iconOnly,
            geometry: FrostButtonGeometry(
              horizontalInset: 10,
              verticalInset: 0,
              minimumWidth: 0,
              visualHeight: geometry.height,
              alignment: iconOnly ? MainAxisAlignment.center : MainAxisAlignment.start,
            ),
            labelWidget: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: value?.isNotEmpty == true ? tokens.textPrimary : tokens.textSecondary),
            ),
            trailing: !iconOnly && shortcutLabel != null && limits.maxWidth > 240
                ? Padding(
                    padding: const EdgeInsetsDirectional.only(start: 8),
                    child: Text(shortcutLabel!, style: FrostTypography.of(context).style(FrostTextRole.caption).copyWith(color: tokens.textSecondary)),
                  )
                : null,
          ),
        );
      },
    );
  }
}
