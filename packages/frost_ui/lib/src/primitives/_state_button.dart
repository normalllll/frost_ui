import 'package:flutter/widgets.dart';

import '../foundation/_focus_modality.dart' show FrostInputModality;
import '../foundation/feedback.dart' show frostShowsFocus;
import '../foundation/metrics.dart';
import '../foundation/tokens.dart';
import '_click_surface_visuals.dart';
import '_focus_outline.dart';
import '_on_media_chrome_scope.dart';
import 'click_surface.dart';

/// A bare pressable whose fill, ink and keyboard ring the owner decides from
/// the widget states, for chrome whose colours are not a Frost button's.
///
/// Input, focus and activation belong to [FrostClickSurface]; this widget only
/// reports the resulting states and paints a clipped fill under [child].
class FrostStateButton extends StatefulWidget {
  const FrostStateButton({
    required this.onPressed,
    required this.shape,
    required this.fill,
    required this.ink,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.constraints = const BoxConstraints(),
    this.textStyle,
    this.iconSize,
    this.mouseCursor,
    this.focusNode,
    this.autofocus = false,
    this.onHover,
    this.focusReadsAsHover = false,
    super.key,
  });

  /// Null disables the button.
  final VoidCallback? onPressed;
  final ShapeBorder shape;

  /// The fill for a state set. It animates between values.
  final Color Function(Set<WidgetState> states) fill;

  /// The foreground colour of text and icons for a state set.
  final Color Function(Set<WidgetState> states) ink;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final BoxConstraints constraints;
  final TextStyle? textStyle;
  final double? iconSize;
  final MouseCursor? mouseCursor;
  final FocusNode? focusNode;
  final bool autofocus;
  final ValueChanged<bool>? onHover;

  /// Shows keyboard focus as the hover fill instead of a ring, for a list of
  /// items whose current item is the highlighted one.
  final bool focusReadsAsHover;

  @override
  State<FrostStateButton> createState() => _FrostStateButtonState();
}

class _FrostStateButtonState extends State<FrostStateButton> {
  bool _hovered = false, _pressed = false, _focused = false;

  @override
  void initState() {
    super.initState();
    FrostInputModality.instance.addListener(_refresh);
    FocusManager.instance.addHighlightModeListener(_highlightChanged);
  }

  void _highlightChanged(FocusHighlightMode mode) => _refresh();
  void _refresh() => _set(() {});

  @override
  void dispose() {
    FrostInputModality.instance.removeListener(_refresh);
    FocusManager.instance.removeHighlightModeListener(_highlightChanged);
    super.dispose();
  }

  void _set(void Function() change) {
    if (mounted) setState(change);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final states = <WidgetState>{
      if (!enabled) WidgetState.disabled,
      if (_hovered) WidgetState.hovered,
      if (_pressed) WidgetState.pressed,
      if (_focused) WidgetState.focused,
    };
    final showsFocus = frostShowsFocus(states) && enabled;
    final fillStates = widget.focusReadsAsHover
        ? <WidgetState>{...states.where((state) => state != WidgetState.focused), if (showsFocus) WidgetState.hovered}
        : states;
    final ink = widget.ink(states);
    final tokens = FrostThemeTokens.of(context);
    Widget content = Padding(
      padding: widget.padding,
      child: Align(widthFactor: 1, heightFactor: 1, child: widget.child),
    );
    content = DefaultTextStyle.merge(
      style: (widget.textStyle ?? const TextStyle()).copyWith(color: ink),
      child: IconTheme.merge(
        data: IconThemeData(color: ink, size: widget.iconSize),
        child: content,
      ),
    );
    final surface = FrostClickSurfaceVisuals(
      child: FrostClickSurface(
        onTap: widget.onPressed,
        mouseCursor: widget.mouseCursor,
        focusNode: widget.focusNode,
        autofocus: widget.autofocus,
        onHover: (value) {
          _set(() => _hovered = value);
          widget.onHover?.call(value);
        },
        onFocusChange: (value) => _set(() => _focused = value),
        onPressedChange: (value) => _set(() => _pressed = value),
        child: CustomPaint(
          foregroundPainter: showsFocus && !widget.focusReadsAsHover
              ? FrostFocusOutlinePainter(
                  widget.shape,
                  FrostOnMediaChromeScope.inkOf(context) ?? tokens.focus,
                  FrostMetrics.focusBorderWidth,
                  Directionality.of(context),
                )
              : null,
          child: ConstrainedBox(
            constraints: widget.constraints,
            child: Stack(
              fit: StackFit.passthrough,
              children: [
                Positioned.fill(
                  child: IgnorePointer(
                    child: ClipPath(
                      clipper: ShapeBorderClipper(shape: widget.shape, textDirection: Directionality.of(context)),
                      child: AnimatedContainer(
                        duration: FrostMotion.duration(context, FrostMotion.hover),
                        curve: FrostMotion.hoverCurve,
                        color: widget.fill(fillStates),
                      ),
                    ),
                  ),
                ),
                content,
              ],
            ),
          ),
        ),
      ),
    );
    return Semantics(container: true, button: true, enabled: enabled, child: surface);
  }
}
