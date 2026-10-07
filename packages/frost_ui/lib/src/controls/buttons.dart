import 'package:frost_ui/src/foundation/feedback.dart';
import 'package:frost_ui/src/controls/click_surface.dart';
import 'package:frost_ui/src/foundation/metrics.dart';
import 'package:frost_ui/src/motion/spring.dart';
import 'package:frost_ui/src/foundation/tokens.dart';
import 'package:frost_ui/src/surface/rounded_surface.dart';
import 'package:flutter/material.dart';
import 'package:frost_ui/src/controls/icon.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

enum FrostButtonKind { primary, secondary, danger, ghost }

class FrostButton extends StatefulWidget {
  const FrostButton({
    required this.label,
    this.labelWidget,
    required this.onPressed,
    this.icon,
    this.kind = FrostButtonKind.secondary,
    this.loading = false,
    this.compact = false,
    this.tooltip,
    super.key,
  });

  final String label;
  final Widget? labelWidget;
  final VoidCallback? onPressed;
  final FrostIconData? icon;
  final FrostButtonKind kind;
  final bool loading;
  final bool compact;
  final String? tooltip;

  @override
  State<FrostButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<FrostButton> {
  final WidgetStatesController _states = WidgetStatesController();

  @override
  void initState() {
    super.initState();
    _states.addListener(_refreshVisualState);
    FocusManager.instance.addListener(_refreshVisualState);
  }

  void _refreshVisualState() {
    if (!mounted) return;
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    } else {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _states.removeListener(_refreshVisualState);
    FocusManager.instance.removeListener(_refreshVisualState);
    _states.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final tokens = FrostThemeTokens.of(context);
    final foreground = switch (widget.kind) {
      FrostButtonKind.primary => tokens.onAction,
      FrostButtonKind.secondary => colors.onSurface,
      FrostButtonKind.danger => colors.error,
      FrostButtonKind.ghost => colors.onSurface,
    };
    final background = switch (widget.kind) {
      FrostButtonKind.primary => tokens.actionFill,
      FrostButtonKind.secondary || FrostButtonKind.danger => tokens.surfaceInset,
      FrostButtonKind.ghost => Colors.transparent,
    };
    final feedbackBuilder = switch (widget.kind) {
      FrostButtonKind.primary => frostPrimaryButtonFeedbackBackground,
      FrostButtonKind.secondary || FrostButtonKind.danger => frostSecondaryButtonFeedbackBackground,
      FrostButtonKind.ghost => frostButtonFeedbackBackground,
    };
    final button = FilledButton(
      statesController: _states,
      clipBehavior: Clip.antiAlias,
      onPressed: widget.loading ? null : widget.onPressed,
      style: ButtonStyle(
        tapTargetSize: MaterialTapTargetSize.padded,
        minimumSize: WidgetStatePropertyAll(const Size(0, FrostMetrics.controlHeight)),
        padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: widget.compact ? 10 : 14, vertical: widget.compact ? 6 : 8)),
        backgroundBuilder: feedbackBuilder,
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.disabled) && widget.kind != FrostButtonKind.ghost ? tokens.surfaceInset : background,
        ),
        foregroundColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.disabled) ? tokens.disabledText : foreground),
        mouseCursor: frostClickCursor,
        side: const WidgetStatePropertyAll(BorderSide.none),
        elevation: const WidgetStatePropertyAll(0),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(FrostMetrics.controlRadius))),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Opacity(
            opacity: widget.loading ? 0 : 1,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.icon != null) ...[FrostIcon(widget.icon!, size: 18), const SizedBox(width: 8)],
                Flexible(
                  child:
                      widget.labelWidget ??
                      Text(
                        widget.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                ),
              ],
            ),
          ),
          if (widget.loading) SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2, color: tokens.textPrimary)),
        ],
      ),
    );
    final pressed = _states.value.contains(WidgetState.pressed);
    final focused = frostShowsFocus(_states.value);
    final surface = CustomPaint(
      foregroundPainter: focused ? _ButtonFocusPainter(tokens.focus) : null,
      child: FrostSpringBuilder(
        value: pressed && !widget.loading && widget.onPressed != null ? FrostMetrics.pressedScale(context) : 1,
        spring: FrostMotion.snappy,
        builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
        child: button,
      ),
    );
    return switch (widget.tooltip) {
      null => surface,
      final message => Tooltip(message: message, child: surface),
    };
  }
}

class _ButtonFocusPainter extends CustomPainter {
  const _ButtonFocusPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final outline = RRect.fromRectAndRadius((Offset.zero & size).inflate(3), const Radius.circular(FrostMetrics.controlRadius + 3));
    canvas.drawRRect(
      outline,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = FrostMetrics.focusBorderWidth,
    );
  }

  @override
  bool shouldRepaint(_ButtonFocusPainter oldDelegate) => color != oldDelegate.color;
}

enum FrostIconButtonKind { standard, surface, compact }

class FrostIconButton extends StatelessWidget {
  const FrostIconButton({
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.kind = FrostIconButtonKind.standard,
    this.selected = false,
    this.selectedBackgroundColor,
    this.danger = false,
    this.iconSize = 19,
    this.color,
    this.padding = const EdgeInsets.all(8),
    this.constraints,
    this.visualDensity,
    super.key,
  });

  final FrostIconButtonKind kind;
  final Widget icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final bool selected;
  final Color? selectedBackgroundColor;
  final bool danger;
  final double iconSize;
  final Color? color;
  final EdgeInsetsGeometry padding;
  final BoxConstraints? constraints;
  final VisualDensity? visualDensity;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final tokens = FrostThemeTokens.of(context);
    final foreground =
        color ??
        switch ((danger, selected)) {
          (true, _) => colors.error,
          (false, true) => colors.onPrimaryContainer,
          (false, false) => colors.onSurfaceVariant,
        };
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: icon,
      iconSize: kind == FrostIconButtonKind.compact ? 18 : iconSize,
      padding: kind == FrostIconButtonKind.compact ? EdgeInsets.zero : padding,
      constraints:
          constraints ??
          (kind == FrostIconButtonKind.compact ? const BoxConstraints.tightFor(width: FrostMetrics.controlHeight, height: FrostMetrics.controlHeight) : null),
      visualDensity: visualDensity,
      style: ButtonStyle(
        minimumSize: WidgetStatePropertyAll(constraints?.constrain(const Size.square(40)) ?? const Size.square(FrostMetrics.controlHeight)),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.disabled) ? colors.onSurfaceVariant.withValues(alpha: 0.38) : foreground,
        ),
        mouseCursor: frostClickCursor,
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (kind == FrostIconButtonKind.surface) {
            return tokens.surfaceRaised.withValues(alpha: states.contains(WidgetState.disabled) ? .55 : .92);
          }
          if (selected) {
            return selectedBackgroundColor ?? colors.primaryContainer;
          }
          return frostButtonRestingSurface(tokens, states);
        }),
        tapTargetSize: MaterialTapTargetSize.padded,
        elevation: WidgetStatePropertyAll(kind == FrostIconButtonKind.surface ? 2 : 0),
        shadowColor: WidgetStatePropertyAll(tokens.shadow),
        side: frostFeedbackStyle(tokens).side,
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        shape: const WidgetStatePropertyAll(CircleBorder()),
      ),
    );
  }
}

class FrostSwitch extends StatefulWidget {
  const FrostSwitch({required this.value, required this.onChanged, this.semanticLabel, super.key});
  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? semanticLabel;

  @override
  State<FrostSwitch> createState() => _AppSwitchState();
}

class _AppSwitchState extends State<FrostSwitch> with SingleTickerProviderStateMixin {
  late final AnimationController _position = AnimationController.unbounded(vsync: this, value: widget.value ? 1 : 0);
  final FocusNode _focus = FocusNode();
  final Set<WidgetState> _interaction = {};
  bool _dragging = false;
  double _dragValue = 0;

  @override
  void didUpdateWidget(FrostSwitch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value || (oldWidget.onChanged != null && widget.onChanged == null)) {
      _dragging = false;
      _interaction.remove(WidgetState.pressed);
      _settle();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) _position.value = widget.value ? 1 : 0;
  }

  void _settle() => FrostMotion.springTo(context, _position, widget.value ? 1 : 0, FrostMotion.snappy);

  void _state(WidgetState state, bool active) => setState(() => active ? _interaction.add(state) : _interaction.remove(state));

  void _toggle() {
    if (widget.onChanged == null) return;
    _focus.requestFocus();
    widget.onChanged!(!widget.value);
  }

  void _endDrag({required bool cancelled}) {
    if (!_dragging) return;
    _dragging = false;
    _state(WidgetState.pressed, false);
    final target = _dragValue >= .5;
    if (!cancelled && target != widget.value) widget.onChanged?.call(target);
    // The caller owns the value; rejection or cancellation returns to it.
    _settle();
  }

  @override
  void dispose() {
    _position.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final switchTheme = theme.switchTheme;
    final states = {..._interaction, if (widget.value) WidgetState.selected, if (widget.onChanged == null) WidgetState.disabled};
    final thumb = switchTheme.thumbColor?.resolve(states) ?? (widget.value ? theme.colorScheme.onPrimary : theme.colorScheme.outline);
    final track = switchTheme.trackColor?.resolve(states) ?? (widget.value ? theme.colorScheme.primary : theme.colorScheme.surfaceContainerHighest);
    final outline = switchTheme.trackOutlineColor?.resolve(states) ?? theme.colorScheme.outline;
    final overlay = switchTheme.overlayColor?.resolve(states) ?? Colors.transparent;
    final enabled = widget.onChanged != null;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final colorDuration = FrostMotion.duration(context, FrostMotion.hover);

    return Semantics(
      label: widget.semanticLabel,
      toggled: widget.value,
      enabled: enabled,
      focusable: enabled,
      focused: _focus.hasFocus,
      onTap: enabled ? _toggle : null,
      excludeSemantics: true,
      child: FocusableActionDetector(
        enabled: enabled,
        focusNode: _focus,
        onFocusChange: (_) => setState(() {}),
        mouseCursor: switchTheme.mouseCursor?.resolve(states) ?? (enabled ? SystemMouseCursors.click : SystemMouseCursors.basic),
        onShowFocusHighlight: (active) => _state(WidgetState.focused, active),
        onShowHoverHighlight: (active) => _state(WidgetState.hovered, active),
        shortcuts: const {SingleActivator(LogicalKeyboardKey.space): ActivateIntent(), SingleActivator(LogicalKeyboardKey.enter): ActivateIntent()},
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              _toggle();
              return null;
            },
          ),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: enabled ? _toggle : null,
          onTapDown: enabled ? (_) => _state(WidgetState.pressed, true) : null,
          onTapUp: enabled ? (_) => _state(WidgetState.pressed, false) : null,
          onTapCancel: enabled ? () => _state(WidgetState.pressed, false) : null,
          onHorizontalDragStart: enabled
              ? (_) {
                  _dragging = true;
                  _dragValue = _position.value;
                  _position.stop();
                  _state(WidgetState.pressed, true);
                }
              : null,
          onHorizontalDragUpdate: enabled
              ? (details) {
                  _dragValue = (_dragValue + details.delta.dx / (rtl ? -20 : 20)).clamp(0.0, 1.0);
                  if (!MediaQuery.disableAnimationsOf(context)) {
                    _position.value = _dragValue;
                  }
                }
              : null,
          onHorizontalDragEnd: enabled ? (_) => _endDrag(cancelled: false) : null,
          onHorizontalDragCancel: enabled ? () => _endDrag(cancelled: true) : null,
          child: SizedBox(
            width: 60,
            height: 48,
            child: Center(
              child: AnimatedContainer(
                duration: colorDuration,
                width: 52,
                height: 32,
                decoration: BoxDecoration(
                  color: track,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: outline, width: 2),
                ),
                child: AnimatedBuilder(
                  animation: _position,
                  builder: (context, child) {
                    final progress = _position.value.clamp(0.0, 1.0);
                    final diameter = 20 + 8 * progress;
                    return Center(
                      child: Transform.translate(
                        offset: Offset((rtl ? -1 : 1) * (-10 + 20 * progress), 0),
                        child: Stack(
                          alignment: Alignment.center,
                          clipBehavior: Clip.none,
                          children: [
                            AnimatedContainer(
                              duration: colorDuration,
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(color: overlay, shape: BoxShape.circle),
                            ),
                            SizedBox.square(
                              dimension: diameter,
                              child: AnimatedContainer(
                                duration: colorDuration,
                                decoration: BoxDecoration(color: thumb, shape: BoxShape.circle),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One merged switch row; the trailing control and row share one value callback.
class FrostSwitchListTile extends StatelessWidget {
  const FrostSwitchListTile({required this.value, required this.onChanged, required this.title, this.subtitle, this.contentPadding, super.key});

  final bool value;
  final ValueChanged<bool>? onChanged;
  final Widget title;
  final Widget? subtitle;
  final EdgeInsetsGeometry? contentPadding;

  @override
  Widget build(BuildContext context) => MergeSemantics(
    child: ListTile(
      contentPadding: contentPadding,
      title: title,
      subtitle: subtitle,
      enabled: onChanged != null,
      onTap: onChanged == null ? null : () => onChanged!(!value),
      trailing: FrostSwitch(value: value, onChanged: onChanged),
    ),
  );
}

class FrostChoiceToggle extends StatelessWidget {
  const FrostChoiceToggle({required this.label, required this.selected, required this.onPressed, super.key});

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final tokens = FrostThemeTokens.of(context);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: FrostRoundedSurface(
        color: selected ? colors.primaryContainer : tokens.surfaceMuted,
        borderColor: Colors.transparent,
        child: FrostClickSurface(
          borderRadius: BorderRadius.circular(8),
          onTap: onPressed,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: FrostMetrics.controlHeight, minHeight: FrostMetrics.controlHeight),
            child: Center(
              child: Text(
                label,
                style: TextStyle(color: selected ? colors.onPrimaryContainer : colors.onSurfaceVariant, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
