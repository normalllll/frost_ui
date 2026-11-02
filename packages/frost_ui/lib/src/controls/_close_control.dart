import 'package:flutter/widgets.dart';

import '../foundation/control_scope.dart';
import '../foundation/density.dart';
import '../foundation/metrics.dart';
import '../foundation/scope.dart';
import '../foundation/sizes.dart';
import '../foundation/typography.dart';
import '../overlays/tooltip.dart';
import '../primitives/icon.dart';
import '../primitives/text.dart';
import '_button_parts.dart';
import '_button_types.dart';

// Tabs and filter chips share the same small close affordance and input path.
const frostCloseSize = 20.0;
const _closeIconSize = 14.0;

/// A plain close icon. It composes only the blocks a fixed, always-enabled
/// icon action needs: no activity, selection, role or edge alignment.
class FrostCloseControl extends StatefulWidget {
  const FrostCloseControl({required this.label, required this.onPressed, required this.height, this.foreground, super.key});
  final String label;
  final VoidCallback onPressed;
  final double height;
  final Color? foreground;

  @override
  State<FrostCloseControl> createState() => _FrostCloseControlState();
}

class _FrostCloseControlState extends State<FrostCloseControl> with FrostButtonInteractionState<FrostCloseControl> {
  @override
  bool get interactive => scopeEnabled;

  @override
  Widget build(BuildContext context) {
    final density = FrostDensity.of(context);
    final touch = density.heightFor(FrostControlSize.regular) == FrostControlSize.regular.visualHeight(touch: true);
    final icon = FrostScope.configOf(context).icons.close;
    final size = FrostControlScope.sizeOf(context);
    final geometry = FrostButtonGeometry(
      horizontalInset: 0,
      verticalInset: 0,
      minimumWidth: frostCloseSize,
      alignment: MainAxisAlignment.center,
      visualHeight: frostCloseSize,
      iconSize: _closeIconSize,
      maximumHitHeight: widget.height,
    );
    final metrics = FrostButtonMetrics.icon(context, size, geometry);
    final media = FrostButtonMedia.of(context, iconContent: true);
    final labelStyle = frostTextStyle(context, FrostTextRole.callout, null);
    // Embedded desktop close actions intentionally use a narrow full-height
    // target. Touch reserves a separate 44px column instead of stealing hits
    // from the body. Owners place this outside the painted content's padding.
    return SizedBox(
      width: touch ? 44 : 24,
      height: widget.height,
      child: Semantics(
        button: true,
        label: widget.label,
        liveRegion: false,
        enabled: interactive,
        onTap: interactive ? widget.onPressed : null,
        excludeSemantics: true,
        child: FrostTooltip(
          message: widget.label,
          excludeFromSemantics: true,
          child: FrostButtonHitArea(
            metrics: metrics,
            interactive: interactive,
            onPressed: widget.onPressed,
            automaticInkBounds: !media.media,
            bleeds: true,
            child: FrostButtonFrame(
              style: FrostActionFrameStyle(variant: FrostButtonVariant.plain, media: media),
              interaction: this,
              metrics: metrics,
              labelStyle: labelStyle,
              onPressed: interactive ? widget.onPressed : null,
              builder: (context, foreground) => FrostActionStateLayer(
                activity: FrostButtonActivity.idle,
                size: size,
                color: foreground,
                child: FrostButtonContent(
                  label: widget.label,
                  metrics: metrics,
                  labelStyle: labelStyle,
                  alignment: MainAxisAlignment.center,
                  icon: icon,
                  iconWidget: widget.foreground == null
                      ? null
                      : TweenAnimationBuilder<Color?>(
                          tween: ColorTween(end: widget.foreground),
                          duration: FrostMotion.duration(context, FrostMotion.hover),
                          curve: FrostMotion.hoverCurve,
                          builder: (context, color, _) => FrostIcon(icon, size: _closeIconSize, color: color),
                        ),
                  glyphColor: foreground,
                  showsLabel: false,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
