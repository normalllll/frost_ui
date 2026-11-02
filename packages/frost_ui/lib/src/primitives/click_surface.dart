import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../foundation/_focus_modality.dart';
import '../foundation/_touch_targets.dart';
import '../foundation/control_scope.dart';
import '../foundation/density.dart';
import '../foundation/feedback.dart';
import '../foundation/radius.dart';
import '../foundation/scope.dart';
import '_click_feedback.dart';
import '_click_surface_visuals.dart';

enum FrostClickFeedback { surface, quiet, media }

/// The shape of a [FrostClickSurface]'s hover, press and focus feedback.
sealed class FrostClickShape {
  const FrostClickShape();

  /// Rounded corners. Frost decides from the theme whether they are a rounded
  /// rectangle or a superellipse.
  const factory FrostClickShape.rounded(BorderRadius corners) = _RoundedClickShape;

  /// A circle, for round content such as an avatar.
  const factory FrostClickShape.circle() = _CircleClickShape;

  ShapeBorder _resolve(BuildContext context);
}

final class _RoundedClickShape extends FrostClickShape {
  const _RoundedClickShape(this.corners);

  final BorderRadius corners;

  @override
  ShapeBorder _resolve(BuildContext context) =>
      FrostScope.configOf(context).continuousCorners ? RoundedSuperellipseBorder(borderRadius: corners) : RoundedRectangleBorder(borderRadius: corners);

  @override
  bool operator ==(Object other) => other is _RoundedClickShape && other.corners == corners;

  @override
  int get hashCode => corners.hashCode;
}

final class _CircleClickShape extends FrostClickShape {
  const _CircleClickShape();

  @override
  ShapeBorder _resolve(BuildContext context) => const CircleBorder();
}

const _defaultShape = FrostClickShape.rounded(BorderRadius.all(Radius.circular(FrostRadius.md)));

/// Shared pointer feedback. Presses deepen the fill without moving content.
/// Library content cards explicitly opt into scaling; media stays unshaded.
/// Only keyboard focus
/// receives an outline. Layout never determines the available input methods.
class FrostClickSurface extends StatefulWidget {
  const FrostClickSurface({
    required this.child,
    this.onTap,
    this.onOpenInBackground,
    this.onOpenInNewTab,
    this.onLongPress,
    this.feedback = FrostClickFeedback.surface,
    this.shape,
    this.autofocus = false,
    this.focusNode,
    this.mouseCursor,
    this.onHover,
    this.onFocusChange,
    this.onPressedChange,
    super.key,
  });
  final Widget child;
  final VoidCallback? onTap;

  /// Optional middle-click action. Apps supply a localized touch menu separately.
  final VoidCallback? onOpenInBackground;

  /// Ctrl/Cmd+activation opens and selects a new tab. Ordinary activation stays
  /// in the current page when this callback is absent.
  final VoidCallback? onOpenInNewTab;
  final VoidCallback? onLongPress;
  final FrostClickFeedback feedback;

  /// The corner geometry of the hover, press and focus feedback. Defaults to
  /// rounded corners of [FrostRadius.md].
  final FrostClickShape? shape;
  final bool autofocus;
  final FocusNode? focusNode;
  final MouseCursor? mouseCursor;
  final ValueChanged<bool>? onHover;
  final ValueChanged<bool>? onFocusChange;

  /// Input-event notifications only. Disabling silently cancels the current
  /// press; consumers must also derive their visual state from availability.
  final ValueChanged<bool>? onPressedChange;

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
  bool _invalidPress = false;
  bool _disabledDuringPress = false;
  LogicalKeyboardKey? _activationKey;
  final FocusNode _ownedFocus = FocusNode();

  bool _scopeEnabled = true;
  bool get _enabled => _scopeEnabled && (widget.onTap != null || widget.onLongPress != null);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scopeEnabled = FrostControlScope.enabledOf(context);
    _cancelIfDisabled();
    if (!TickerMode.valuesOf(context).enabled) {
      // A covered route owns no active pointer/activation gesture. Cancel
      // silently, as on deactivate; callbacks here could mutate an ancestor
      // while the framework is rebuilding the route's ticker scope.
      _hovered = false;
      _pressed = false;
      _invalidPress = true;
      _disabledDuringPress = true;
      _activationKey = null;
    }
  }

  @override
  void didUpdateWidget(FrostClickSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    _cancelIfDisabled();
  }

  void _cancelIfDisabled() {
    if (!_enabled) {
      // A lifecycle cancellation is intentionally silent. Keep the gesture
      // invalid even if availability returns before this pointer is released.
      _hovered = false;
      _invalidPress = true;
      _disabledDuringPress = true;
      _pressed = false;
      _activationKey = null;
    }
  }

  void _setPressed(bool value) {
    if (!mounted || _pressed == value) return;
    setState(() => _pressed = value);
    widget.onPressedChange?.call(value);
  }

  bool _touchPress = false;
  void _pointerDown(PointerDownEvent event) {
    _touchPress = event.kind == PointerDeviceKind.touch || event.kind == PointerDeviceKind.stylus || event.kind == PointerDeviceKind.invertedStylus;
    _invalidPress = !_enabled;
    _disabledDuringPress = !_enabled;
    if (_enabled && !_overNestedControl(event)) {
      // Pointer activation keeps the current editing focus. Keyboard traversal
      // owns focus acquisition, as with Flutter buttons.
      _setPressed(true);
    }
  }

  void _cancelPress() {
    _invalidPress = true;
    _setPressed(false);
  }

  void _activate() {
    if (!_enabled || _invalidPress) return;
    final modified = HardwareKeyboard.instance.isControlPressed || HardwareKeyboard.instance.isMetaPressed;
    (modified && widget.onOpenInNewTab != null ? widget.onOpenInNewTab : widget.onTap)?.call();
  }

  KeyEventResult _keyEvent(FocusNode node, KeyEvent event) {
    final key = event.logicalKey;
    if (FrostClickKeyboardScope.passes(context, key)) return KeyEventResult.ignored;
    if (key != LogicalKeyboardKey.space && key != LogicalKeyboardKey.enter) return KeyEventResult.ignored;
    if (event is KeyDownEvent && _enabled) {
      _invalidPress = false;
      _activationKey = key;
      _setPressed(true);
      return KeyEventResult.handled;
    } else if (event is KeyUpEvent && _activationKey == key) {
      _activationKey = null;
      _setPressed(false);
      _activate();
      return KeyEventResult.handled;
    }
    // Windows can batch unrelated key events with a synthesized release. An
    // unmatched release must not swallow Escape on its way to a modal parent.
    return event is KeyRepeatEvent && _activationKey == key ? KeyEventResult.handled : KeyEventResult.ignored;
  }

  void _updateHover(PointerEvent event) {
    if (!FrostInputModality.instance.acceptsHover(event)) return;
    _setHovered(!_overNestedControl(event));
  }

  /// Whether the pointer is on a control nested in this surface, which then
  /// has the feedback to itself. Read-only text is part of this surface.
  bool _overNestedControl(PointerEvent event) {
    final result = HitTestResult();
    GestureBinding.instance.hitTestInView(result, event.position, event.viewId);
    var editable = false;
    for (final entry in result.path) {
      final target = entry.target;
      if (target is RenderMetaData && identical(target.metaData, this)) break;
      if (target is RenderEditable && !target.readOnly) editable = true;
      // Material buttons and nested click surfaces resolve their cursor on the
      // render object. Stop parent feedback even over a disabled child control.
      if (target is RenderMouseRegion && target.cursor != MouseCursor.defer && (target.cursor != SystemMouseCursors.text || editable)) return true;
    }
    return false;
  }

  void _setHovered(bool value) {
    if (_hovered == value) return;
    setState(() => _hovered = value);
    widget.onHover?.call(value);
  }

  @override
  void initState() {
    super.initState();
    FrostInputModality.instance.attach();
    FrostInputModality.instance.addListener(_modalityChanged);
    FocusManager.instance.addHighlightModeListener(_highlightModeChanged);
  }

  void _modalityChanged() {
    if (!mounted) return;
    if (FrostInputModality.instance.touch) _setHovered(false);
    setState(() {});
  }

  void _highlightModeChanged(FocusHighlightMode mode) {
    if (mounted) setState(() {});
  }

  @override
  void deactivate() {
    // Disposing the last tap recognizer can call onTapCancel while children
    // unmount. Clear input state before that lifecycle cancellation, silently.
    _invalidPress = true;
    _disabledDuringPress = true;
    _pressed = false;
    _activationKey = null;
    super.deactivate();
  }

  @override
  void dispose() {
    FrostInputModality.instance.removeListener(_modalityChanged);
    FrostInputModality.instance.detach();
    FocusManager.instance.removeHighlightModeListener(_highlightModeChanged);
    _ownedFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = _enabled;
    final states = <WidgetState>{
      if (!enabled) WidgetState.disabled,
      if (_hovered) WidgetState.hovered,
      if (_pressed) WidgetState.pressed,
      if (_focused) WidgetState.focused,
    };
    final shape = (widget.shape ?? _defaultShape)._resolve(context);
    final delegated = FrostClickSurfaceVisuals.delegatedOf(context);
    Widget content = MetaData(
      metaData: this,
      behavior: HitTestBehavior.translucent,
      child: FrostClickSurfaceVisuals.standard(
        child: _HoverScope(hovered: enabled && _hovered, child: widget.child),
      ),
    );
    if (!delegated) {
      final row = context.dependOnInheritedWidgetOfExactType<FrostClickHighlight>();
      final rowCurrent = row != null && (row.highlighted || frostShowsFocus(states));
      content = FrostClickFeedbackVisual(
        // A row owns one whole-row highlight, including keyboard movement.
        // Nested buttons delegate their visuals and retain their own rings.
        states: row == null ? states : (states.toSet()..remove(WidgetState.focused)),
        feedback: widget.feedback,
        shape: shape,
        clipsContent: FrostClickSurfaceVisuals.clipsContentOf(context),
        fillsBounds: FrostClickSurfaceVisuals.fillsBoundsOf(context),
        scalesOnPress: FrostClickSurfaceVisuals.scalesOnPressOf(context),
        mediaImages: FrostClickSurfaceVisuals.mediaImagesOf(context),
        highlighted: rowCurrent,
        child: content,
      );
    }
    final longPress = enabled && widget.onLongPress != null
        ? () {
            if (_touchPress && !_disabledDuringPress) widget.onLongPress?.call();
          }
        : null;
    return FrostTouchTarget(
      enabled: enabled && FrostDensity.of(context).usesPointer,
      child: MouseRegion(
        cursor: widget.mouseCursor ?? frostClickCursor.resolve(states),
        onEnter: _updateHover,
        onHover: _updateHover,
        onExit: (_) => _setHovered(false),
        child: Actions(
          actions: {
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                if (_enabled) widget.onTap?.call();
                return null;
              },
            ),
          },
          child: Semantics(
            enabled: enabled ? null : false,
            child: Focus(
              canRequestFocus: enabled,
              onKeyEvent: _keyEvent,
              autofocus: widget.autofocus,
              focusNode: widget.focusNode ?? _ownedFocus,
              onFocusChange: (value) {
                setState(() => _focused = value);
                widget.onFocusChange?.call(value);
              },
              child: Listener(
                onPointerDown: _pointerDown,
                onPointerUp: (_) => _setPressed(false),
                onPointerCancel: (_) => _cancelPress(),
                child: RawGestureDetector(
                  behavior: HitTestBehavior.opaque,
                  semantics: _PressSemantics(onTap: enabled ? _activate : null, onLongPress: longPress),
                  gestures: {
                    _PressTapGestureRecognizer: GestureRecognizerFactoryWithHandlers<_PressTapGestureRecognizer>(
                      () => _PressTapGestureRecognizer(debugOwner: this),
                      (recognizer) => recognizer
                        ..onTap = enabled ? _activate : null
                        ..onTertiaryTapUp = enabled && widget.onOpenInBackground != null ? (_) => widget.onOpenInBackground?.call() : null
                        ..onTapCancel = _cancelPress
                        ..onRejected = _cancelPress
                        ..gestureSettings = MediaQuery.maybeGestureSettingsOf(context),
                    ),
                    if (longPress != null)
                      LongPressGestureRecognizer: GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
                        () => LongPressGestureRecognizer(debugOwner: this),
                        (recognizer) => recognizer
                          ..onLongPress = longPress
                          ..gestureSettings = MediaQuery.maybeGestureSettingsOf(context),
                      ),
                  },
                  child: content,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A tap recognizer that also reports losing the arena before tap-down. A
/// scroll or swipe that wins within the press timeout never sends tap-down, so
/// tap-cancel alone would leave a touch press highlighted until the finger lifts.
class _PressTapGestureRecognizer extends TapGestureRecognizer {
  _PressTapGestureRecognizer({super.debugOwner});
  VoidCallback? onRejected;

  @override
  void rejectGesture(int pointer) {
    super.rejectGesture(pointer);
    onRejected?.call();
  }
}

/// The tap and long-press actions [GestureDetector] would expose, for the
/// press recognizer that the default delegate does not know.
class _PressSemantics extends SemanticsGestureDelegate {
  const _PressSemantics({required this.onTap, required this.onLongPress});
  final VoidCallback? onTap, onLongPress;

  @override
  void assignSemantics(RenderSemanticsGestureHandler renderObject) => renderObject
    ..onTap = onTap
    ..onLongPress = onLongPress;
}
