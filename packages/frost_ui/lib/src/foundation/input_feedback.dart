import 'package:flutter/widgets.dart';

import '_focus_modality.dart';
import '_touch_targets.dart';
import 'density.dart';

/// What input the device offers and which one is in use now. Default sizes follow
/// `FrostDensity.usesPointer`, so a late mouse or touch never moves a control;
/// hover-only content follows [hoverAvailable].
///
/// Read it with [of]; a widget that does rebuilds when the input changes.
@immutable
class FrostInputCapability {
  const FrostInputCapability._(this._pointerBaseline, this.touch, this._mouseSeen);

  factory FrostInputCapability._current(BuildContext context) {
    final input = FrostInputModality.instance;
    return FrostInputCapability._(FrostDensity.of(context).usesPointer, input.touch, input.mouseSeen);
  }

  final bool _pointerBaseline;

  /// Whether the latest pointer was a finger.
  final bool touch;
  final bool _mouseSeen;

  /// Whether the device has a mouse, by its baseline or because one was used.
  bool get mouseAvailable => _pointerBaseline || _mouseSeen;

  /// Whether content that waits for hover can be reached right now. When false,
  /// an action must not rely on hover alone.
  bool get hoverAvailable => mouseAvailable && !touch;

  /// The capability at [context]. `FrostApp` provides it.
  static FrostInputCapability of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_InputScope>();
    if (scope == null) {
      throw FlutterError.fromParts([
        ErrorSummary('FrostInputCapability.of() was called without a FrostApp above the context.'),
        ErrorHint('Build the app with FrostApp.router, or place a FrostInputFeedback above this widget.'),
      ]);
    }
    return FrostInputCapability._current(context);
  }

  @override
  bool operator ==(Object other) =>
      other is FrostInputCapability && other._pointerBaseline == _pointerBaseline && other.touch == touch && other._mouseSeen == _mouseSeen;

  @override
  int get hashCode => Object.hash(_pointerBaseline, touch, _mouseSeen);
}

class _InputScope extends InheritedNotifier<FrostInputModality> {
  const _InputScope({required super.notifier, required super.child});
}

/// Keeps the shared input tracker running for the app's whole life and
/// publishes it to [FrostInputCapability.of]. Touches no framework state.
class FrostInputFeedback extends StatefulWidget {
  const FrostInputFeedback({required this.child, super.key});

  final Widget child;

  @override
  State<FrostInputFeedback> createState() => _FrostInputFeedbackState();
}

class _FrostInputFeedbackState extends State<FrostInputFeedback> {
  @override
  void initState() {
    super.initState();
    FrostInputModality.instance.attach();
  }

  @override
  void dispose() {
    FrostInputModality.instance.detach();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FrostTouchTargetRoot(
    child: _InputScope(notifier: FrostInputModality.instance, child: widget.child),
  );
}

/// Rebuilds [builder] when the shared input tracker changes. Library-only, for
/// components that also work under a bare Frost theme without `FrostApp`.
class FrostInputBuilder extends StatefulWidget {
  const FrostInputBuilder({required this.builder, super.key});

  final Widget Function(BuildContext context, FrostInputCapability input) builder;

  @override
  State<FrostInputBuilder> createState() => _FrostInputBuilderState();
}

class _FrostInputBuilderState extends State<FrostInputBuilder> {
  FrostInputCapability? _last;

  @override
  void initState() {
    super.initState();
    FrostInputModality.instance.attach();
    FrostInputModality.instance.addListener(_changed);
  }

  void _changed() {
    if (mounted && FrostInputCapability._current(context) != _last) setState(() {});
  }

  @override
  void dispose() {
    FrostInputModality.instance.removeListener(_changed);
    FrostInputModality.instance.detach();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _last = FrostInputCapability._current(context));
}
