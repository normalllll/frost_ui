import 'package:flutter/widgets.dart';

import '../controls/_button_control.dart';
import '../controls/_button_types.dart';
import '../foundation/_control_geometry.dart';
import '../foundation/_media_contrast.dart';
import '../foundation/_touch_targets.dart';
import '../foundation/control_scope.dart';
import '../foundation/density.dart';
import '../foundation/sizes.dart';
import '../foundation/tokens.dart';
import '../foundation/typography.dart';
import '../primitives/_on_media_chrome_scope.dart';
import '../primitives/icon.dart';

/// Bare media actions with a subtle glyph shadow. The containing video control
/// region owns the readable gradient; individual actions paint no backing.
class FrostMediaButton extends StatelessWidget {
  const FrostMediaButton({required this.label, required this.onPressed, this.icon, this.size = FrostControlSize.compact, super.key}) : _iconOnly = false;
  const FrostMediaButton.icon({required FrostIconData this.icon, required this.label, required this.onPressed, this.size = FrostControlSize.compact, super.key})
    : _iconOnly = true;
  final String label;
  final VoidCallback? onPressed;
  final FrostIconData? icon;
  final FrostControlSize size;
  final bool _iconOnly;

  @override
  Widget build(BuildContext context) {
    final offset = FrostVideoCommandScope.of(context) ? (FrostDensity.of(context).usesPointer ? 4.0 : 12.0) : 0.0;
    final type = FrostTypography.of(
      context,
    ).style(FrostTextRole.caption, tabular: true).copyWith(color: const Color(0xFFFFFFFF), shadows: frostMediaInkShadows);
    final chip = !_iconOnly && icon == null;
    Widget ink(Widget child) => Padding(
      padding: EdgeInsets.only(top: offset),
      child: child,
    );
    final control = FrostButtonControl(
      label: label,
      onPressed: FrostControlScope.enabledOf(context) ? onPressed : null,
      size: size,
      presentation: FrostButtonPresentation.media,
      variant: FrostButtonVariant.plain,
      iconStyle: _iconOnly ? FrostIconButtonStyle.plain : null,
      geometry: chip ? const FrostButtonGeometry(horizontalInset: 0, verticalInset: 0, minimumWidth: 0, alignment: MainAxisAlignment.center) : null,
      iconWidget: icon == null
          ? null
          : ink(
              IconTheme.merge(
                data: const IconThemeData(shadows: frostMediaInkShadows),
                child: FrostIcon(icon!, size: size.iconSize, color: const Color(0xFFFFFFFF)),
              ),
            ),
      labelWidget: _iconOnly
          ? null
          : ink(
              chip
                  ? Container(
                      constraints: BoxConstraints(
                        minHeight: frostControlTextGeometry(baseHeight: 18, style: type, textScaler: MediaQuery.textScalerOf(context)).height,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      decoration: BoxDecoration(
                        border: Border.all(color: FrostThemeTokens.of(context).onMediaInk.withValues(alpha: .4)),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(label, style: type),
                    )
                  : Text(
                      label,
                      style: const TextStyle(color: Color(0xFFFFFFFF), shadows: frostMediaInkShadows),
                    ),
            ),
    );
    if (!FrostVideoCommandScope.of(context)) return control;
    // The strip keeps its narrow slots. On touch the target reaches its full
    // width through the root layer, and a direct hit on a neighbour stays there.
    Widget slot(double width) => FrostTouchTarget(
      enabled: !FrostDensity.of(context).usesPointer && onPressed != null && FrostControlScope.enabledOf(context),
      child: SizedBox(width: width, child: control),
    );
    if (_iconOnly) return slot(30);
    if (chip) {
      final painter = TextPainter(
        text: TextSpan(text: label, style: type),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout();
      final width = painter.width + 26;
      painter.dispose();
      return slot(width);
    }
    return control;
  }
}
