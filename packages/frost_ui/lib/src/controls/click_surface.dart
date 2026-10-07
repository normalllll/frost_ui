import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:frost_ui/src/foundation/metrics.dart';
import 'package:frost_ui/src/foundation/feedback.dart';
import 'package:frost_ui/src/foundation/tokens.dart';
import 'package:frost_ui/src/motion/spring.dart';

enum FrostClickFeedback { surface, quiet, media }

/// Shared pointer feedback; media remains unshaded and only keyboard focus
/// receives an outline. Layout never determines the available input methods.
class FrostClickSurface extends StatefulWidget {
  const FrostClickSurface({
    required this.child,
    this.onTap,
    this.onLongPress,
    this.feedback = FrostClickFeedback.surface,
    this.borderRadius,
    this.customBorder,
    this.autofocus = false,
    this.focusNode,
    this.mouseCursor,
    this.onHover,
    this.onFocusChange,
    super.key,
  });
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final FrostClickFeedback feedback;
  final BorderRadius? borderRadius;
  final ShapeBorder? customBorder;
  final bool autofocus;
  final FocusNode? focusNode;
  final MouseCursor? mouseCursor;
  final ValueChanged<bool>? onHover;
  final ValueChanged<bool>? onFocusChange;

  /// Whether the nearest enclosing click surface is under the pointer (not
  /// over a nested control), for content that reacts to hovering its card,
  /// such as a picture zooming inside its frame.
  static bool hoveredOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<_HoverScope>()?.hovered ?? false;

  @override
  State<FrostClickSurface> createState() => _AppClickSurfaceState();
}

class _HoverScope extends InheritedWidget {
  const _HoverScope({required this.hovered, required super.child});

  final bool hovered;

  @override
  bool updateShouldNotify(_HoverScope oldWidget) => hovered != oldWidget.hovered;
}

class _AppClickSurfaceState extends State<FrostClickSurface> {
  bool _hovered = false;
  bool _focused = false;
  bool _pressed = false;

  void _updateHover(PointerEvent event) {
    // Fingers do not hover. Some Android devices still report finger hover
    // (Samsung Air View) without a dependable exit, which left items lit.
    if (event.kind == PointerDeviceKind.touch) return;
    final result = HitTestResult();
    GestureBinding.instance.hitTestInView(result, event.position, event.viewId);
    var nestedControl = false;
    for (final entry in result.path) {
      final target = entry.target;
      if (target is RenderMetaData && identical(target.metaData, this)) break;
      // Material buttons and nested click surfaces resolve their cursor on the
      // render object. Stop parent feedback even over a disabled child control.
      if (target is RenderMouseRegion && target.cursor != MouseCursor.defer) {
        nestedControl = true;
      }
    }
    _setHovered(!nestedControl);
  }

  void _setHovered(bool value) {
    if (_hovered == value) return;
    setState(() => _hovered = value);
    widget.onHover?.call(value);
  }

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addHighlightModeListener(_highlightModeChanged);
  }

  void _highlightModeChanged(FocusHighlightMode mode) {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    FocusManager.instance.removeHighlightModeListener(_highlightModeChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = FrostThemeTokens.of(context);
    final enabled = widget.onTap != null || widget.onLongPress != null;
    final states = <WidgetState>{
      if (!enabled) WidgetState.disabled,
      if (_hovered) WidgetState.hovered,
      if (_pressed) WidgetState.pressed,
      if (_focused) WidgetState.focused,
    };
    final media = widget.feedback == FrostClickFeedback.media;
    final shape = widget.customBorder ?? RoundedRectangleBorder(borderRadius: widget.borderRadius ?? BorderRadius.circular(FrostMetrics.controlRadius));
    final active = enabled && frostShowsFocus(states);
    return MouseRegion(
      onEnter: _updateHover,
      onHover: _updateHover,
      onExit: (_) => _setHovered(false),
      child: CustomPaint(
        foregroundPainter: active ? _OutlinePainter(shape, tokens.focus, FrostMetrics.focusBorderWidth, Directionality.of(context)) : null,
        child: InkWell(
          onTap: widget.onTap,
          onLongPress: widget.onLongPress,
          autofocus: widget.autofocus,
          focusNode: widget.focusNode,
          mouseCursor: widget.mouseCursor ?? frostClickCursor.resolve(states),
          customBorder: shape,
          splashFactory: NoSplash.splashFactory,
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          onFocusChange: (value) {
            setState(() => _focused = value);
            widget.onFocusChange?.call(value);
          },
          onHighlightChanged: (value) {
            if (mounted) setState(() => _pressed = value);
          },
          child: ClipPath(
            clipper: ShapeBorderClipper(shape: shape),
            child: AnimatedContainer(
              duration: FrostMotion.duration(context, FrostMotion.hover),
              curve: FrostMotion.hoverCurve,
              decoration: ShapeDecoration(
                shape: shape,
                color: switch (widget.feedback) {
                  FrostClickFeedback.surface => frostFeedbackSurface(tokens, states),
                  FrostClickFeedback.quiet => frostButtonStateLayer(tokens, states, FrostFeedbackRole.quiet),
                  FrostClickFeedback.media => Colors.transparent,
                },
              ),
              // Pressing sinks the surface on a snappy spring; a quick tap
              // reverses mid-way at its current speed instead of restarting.
              child: FrostSpringBuilder(
                value: enabled && _pressed ? FrostMetrics.pressedScale(context, media: media) : 1,
                spring: FrostMotion.snappy,
                builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
                child: MetaData(
                  metaData: this,
                  behavior: HitTestBehavior.translucent,
                  child: _HoverScope(hovered: enabled && _hovered, child: widget.child),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OutlinePainter extends CustomPainter {
  const _OutlinePainter(this.shape, this.color, this.width, this.direction);
  final ShapeBorder shape;
  final Color color;
  final double width;
  final TextDirection direction;
  @override
  void paint(Canvas canvas, Size size) {
    // Leave a two-pixel gap between the hit surface and the keyboard ring.
    final gap = width / 2 + 2;
    final rect = (Offset.zero & size).inflate(gap);
    if (rect.isEmpty) return;
    // Grow rounded corners with the ring so it stays concentric with the
    // surface instead of pinching tighter at each corner.
    final ringShape = switch (shape) {
      RoundedRectangleBorder(:final borderRadius) => RoundedRectangleBorder(borderRadius: borderRadius.resolve(direction) + BorderRadius.circular(gap)),
      _ => shape,
    };
    canvas.drawPath(
      ringShape.getOuterPath(rect, textDirection: direction),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = width,
    );
  }

  @override
  bool shouldRepaint(_OutlinePainter oldDelegate) =>
      shape != oldDelegate.shape || color != oldDelegate.color || width != oldDelegate.width || direction != oldDelegate.direction;
}
