import 'dart:async';

import 'package:flutter/widgets.dart';

import '../foundation/control_scope.dart';
import '../foundation/icon_data.dart';
import '../foundation/scope.dart';
import '../foundation/sizes.dart';
import '../foundation/typography.dart';
import '../primitives/status_glyph.dart';
import '_button_control.dart';
import '_button_types.dart';
import 'action_state.dart';

export '_button_types.dart' show FrostButtonChevron, FrostButtonEdgeAlignment, FrostButtonRole, FrostButtonShape;
export 'action_state.dart';
export 'switch.dart';

// Hold begins after the result stroke is complete, not when its Future ends.
const _buttonResultHold = Duration(milliseconds: 1200);
// Longer than the slowest double click a platform allows.
const _cancelArmDelay = Duration(milliseconds: 500);

/// A text or icon button. The default constructor is the standard button;
/// named constructors are the other kinds, each with only its own arguments.
/// [state] shows a running operation and its result apart from [onPressed];
/// [FrostActionRunner] keeps that state for an asynchronous action.
class FrostButton extends StatefulWidget {
  /// The standard button. [selected] shows a toggled state.
  const FrostButton({
    required this.label,
    this.onPressed,
    this.icon,
    this.labelWidget,
    this.role = FrostButtonRole.normal,
    this.size,
    this.shape = FrostButtonShape.rounded,
    this.selected,
    this.chevron = FrostButtonChevron.none,
    this.state = FrostActionState.idle,
    this.tooltip,
    super.key,
  }) : _variant = FrostButtonVariant.standard,
       _style = null,
       _quiet = false,
       edgeAlignment = null;

  /// The one primary action of a view.
  const FrostButton.prominent({
    required this.label,
    this.onPressed,
    this.icon,
    this.labelWidget,
    this.role = FrostButtonRole.normal,
    this.size,
    this.shape = FrostButtonShape.rounded,
    this.chevron = FrostButtonChevron.none,
    this.state = FrostActionState.idle,
    this.tooltip,
    super.key,
  }) : _variant = FrostButtonVariant.prominent,
       _style = null,
       _quiet = false,
       selected = null,
       edgeAlignment = null;

  /// A tinted fill for secondary emphasis.
  const FrostButton.tinted({
    required this.label,
    this.onPressed,
    this.icon,
    this.labelWidget,
    this.role = FrostButtonRole.normal,
    this.size,
    this.shape = FrostButtonShape.rounded,
    this.chevron = FrostButtonChevron.none,
    this.state = FrostActionState.idle,
    this.tooltip,
    super.key,
  }) : _variant = FrostButtonVariant.tinted,
       _style = null,
       _quiet = false,
       selected = null,
       edgeAlignment = null;

  /// An outline without fill.
  const FrostButton.outlined({
    required this.label,
    this.onPressed,
    this.icon,
    this.labelWidget,
    this.role = FrostButtonRole.normal,
    this.size,
    this.shape = FrostButtonShape.rounded,
    this.chevron = FrostButtonChevron.none,
    this.state = FrostActionState.idle,
    this.tooltip,
    super.key,
  }) : _variant = FrostButtonVariant.outlined,
       _style = null,
       _quiet = false,
       selected = null,
       edgeAlignment = null;

  /// Text without a resting fill.
  const FrostButton.plain({
    required this.label,
    this.onPressed,
    this.icon,
    this.labelWidget,
    this.role = FrostButtonRole.normal,
    this.size,
    this.shape = FrostButtonShape.rounded,
    this.chevron = FrostButtonChevron.none,
    this.state = FrostActionState.idle,
    this.tooltip,
    this.edgeAlignment,
    super.key,
  }) : _variant = FrostButtonVariant.plain,
       _style = null,
       _quiet = false,
       selected = null;

  /// A secondary text action with ordinary button typography and no resting fill.
  /// It keeps the ordinary density-dependent hit target, feedback and focus.
  const FrostButton.quiet({
    required this.label,
    this.onPressed,
    this.size,
    this.shape = FrostButtonShape.rounded,
    this.state = FrostActionState.idle,
    this.tooltip,
    this.edgeAlignment,
    super.key,
  }) : icon = null,
       labelWidget = null,
       role = FrostButtonRole.normal,
       chevron = FrostButtonChevron.none,
       selected = null,
       _variant = FrostButtonVariant.plain,
       _style = null,
       _quiet = true;

  /// An icon without a resting fill; [label] is its tooltip and semantics.
  /// [selected] shows a toggled state, such as looping on.
  const FrostButton.icon({
    required FrostIconData this.icon,
    required this.label,
    this.onPressed,
    this.role = FrostButtonRole.normal,
    this.size,
    this.shape = FrostButtonShape.rounded,
    this.selected,
    this.state = FrostActionState.idle,
    this.tooltip,
    this.edgeAlignment,
    super.key,
  }) : labelWidget = null,
       chevron = FrostButtonChevron.none,
       _variant = FrostButtonVariant.plain,
       _style = FrostIconButtonStyle.plain,
       _quiet = false;

  /// An icon on the standard filled surface.
  const FrostButton.iconFilled({
    required FrostIconData this.icon,
    required this.label,
    this.onPressed,
    this.role = FrostButtonRole.normal,
    this.size,
    this.shape = FrostButtonShape.rounded,
    this.selected,
    this.state = FrostActionState.idle,
    this.tooltip,
    super.key,
  }) : labelWidget = null,
       chevron = FrostButtonChevron.none,
       edgeAlignment = null,
       _variant = FrostButtonVariant.plain,
       _style = FrostIconButtonStyle.standard,
       _quiet = false;

  /// An icon over images and video, with its own legible chrome.
  const FrostButton.iconOnMedia({
    required FrostIconData this.icon,
    required this.label,
    this.onPressed,
    this.role = FrostButtonRole.normal,
    this.size,
    this.shape = FrostButtonShape.rounded,
    this.selected,
    this.state = FrostActionState.idle,
    this.tooltip,
    super.key,
  }) : labelWidget = null,
       chevron = FrostButtonChevron.none,
       edgeAlignment = null,
       _variant = FrostButtonVariant.plain,
       _style = FrostIconButtonStyle.onMedia,
       _quiet = false;

  /// Aligns visible content to a shared content/container keyline while the
  /// surface, hit target and focus ring extend into the outside padding. Null
  /// retains ordinary layout; a shared row aligns its terminal plain icon
  /// automatically.
  final FrostButtonEdgeAlignment? edgeAlignment;
  final String label;
  final VoidCallback? onPressed;
  final FrostIconData? icon;

  /// Dynamic text only (for example rolling numbers). The button supplies its
  /// DefaultTextStyle; do not use this slot to override typography or colours.
  final Widget? labelWidget;
  final FrostButtonRole role;
  final FrostControlSize? size;
  final FrostButtonShape shape;
  final FrostButtonChevron chevron;

  /// A running operation shows a spinner and ignores presses; with an
  /// onCancel the button stays enabled, reads as the App's cancel label and a
  /// press cancels. Each new result draws once and holds for 1200 ms after
  /// drawing, then the original content returns.
  final FrostActionState state;
  final String? tooltip;
  final bool? selected;
  final FrostButtonVariant _variant;
  final FrostIconButtonStyle? _style;
  final bool _quiet;

  @override
  State<FrostButton> createState() => _FrostButtonState();
}

class _FrostButtonState extends State<FrostButton> {
  FrostStatusGlyphKind? _result;
  Object? _shown;
  Timer? _hold, _arming;
  int _operation = 0;

  // Nothing was pressed to start a run the button mounts with.
  bool _cancelArmed = true;

  @override
  void initState() {
    super.initState();
    _show(widget.state);
  }

  static VoidCallback? _cancelOf(FrostActionState state) => state is FrostActionRunning ? state.onCancel : null;

  /// A run that just started does not take presses yet, so the press that
  /// started it and the rest of a double click do not cancel it.
  void _armCancel(FrostActionState previous) {
    if (_cancelOf(widget.state) == null) {
      _arming?.cancel();
      _arming = null;
    } else if (_cancelOf(previous) == null) {
      _cancelArmed = false;
      _arming?.cancel();
      _arming = Timer(_cancelArmDelay, () {
        if (mounted) setState(() => _cancelArmed = true);
      });
    }
  }

  void _ignorePress() {}

  @override
  void didUpdateWidget(FrostButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state == FrostActionState.idle && _result != null) {
      _operation++;
      _hold?.cancel();
      _hold = null;
      _result = null;
    }
    _show(widget.state);
    _armCancel(oldWidget.state);
  }

  // Draws each finished operation once.
  void _show(FrostActionState state) {
    if (state is! FrostActionResult || identical(state.operation, _shown)) return;
    _shown = state.operation;
    _operation++;
    _hold?.cancel();
    _hold = null;
    _result = state is FrostActionSucceeded ? FrostStatusGlyphKind.success : FrostStatusGlyphKind.failure;
  }

  void _resultDrawn(int operation) {
    if (!mounted || operation != _operation || _hold != null) return;
    _hold = Timer(_buttonResultHold, () {
      if (!mounted || operation != _operation) return;
      _hold = null;
      setState(() => _result = null);
    });
  }

  @override
  void dispose() {
    _operation++;
    _hold?.cancel();
    _arming?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final labels = FrostScope.labelsOf(context);
    final size = widget.size ?? FrostControlScope.sizeOf(context);
    final operation = _operation;
    final state = widget.state;
    final running = state is FrostActionRunning;
    final onCancel = _cancelOf(state);
    final cancels = onCancel != null && _cancelArmed;
    return FrostButtonControl(
      presentation: widget._quiet ? FrostButtonPresentation.quiet : FrostButtonPresentation.action,
      textRole: FrostTextRole.callout,
      label: cancels ? labels.cancel : widget.label,
      onPressed: onCancel == null ? widget.onPressed : (cancels ? onCancel : _ignorePress),
      icon: widget.icon,
      labelWidget: widget.labelWidget,
      variant: widget._variant,
      role: widget.role,
      size: widget.size,
      chevron: widget.chevron,
      activity: FrostButtonActivity(
        loading: running,
        cancellable: onCancel != null,
        contentLabel: onCancel == null ? null : widget.label,
        result: _result == null
            ? null
            : FrostProgressResult(
                key: ValueKey(operation),
                result: _result,
                size: size == FrostControlSize.compact ? 16 : 20,
                onResultDrawn: () => _resultDrawn(operation),
              ),
        resultLabel: _result == null
            ? null
            : _result == FrostStatusGlyphKind.success
            ? labels.actionSucceeded
            : labels.actionFailed,
      ),
      tooltip: widget.tooltip,
      edgeAlignment: widget.edgeAlignment,
      iconStyle: widget._style,
      selected: widget.selected,
      shape: widget.shape,
    );
  }
}

/// Whether [button] is one of the icon kinds, for layouts that align an
/// icon's ink rather than a label's text edge. Not exported.
bool frostButtonIsIcon(FrostButton button) => button._style != null;
