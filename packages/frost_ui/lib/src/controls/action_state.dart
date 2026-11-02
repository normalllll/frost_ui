import 'package:flutter/foundation.dart';

/// The state of one operation a control starts, kept apart from its press
/// callback. Controls show a spinner while [FrostActionState.running], and
/// draw a result once for each new [FrostActionState.succeeded] or
/// [FrostActionState.failed] operation.
@immutable
sealed class FrostActionState {
  const FrostActionState._();

  /// Nothing is running.
  static const FrostActionState idle = _Idle();

  /// The operation runs; repeat presses are ignored. With [onCancel] the
  /// control stays enabled, reads as the App's cancel label, and a press
  /// calls [onCancel] instead.
  const factory FrostActionState.running({VoidCallback? onCancel}) = FrostActionRunning;

  /// The operation identified by [operation] succeeded.
  const factory FrostActionState.succeeded({required Object operation}) = FrostActionSucceeded;

  /// The operation identified by [operation] failed.
  const factory FrostActionState.failed({required Object operation}) = FrostActionFailed;
}

final class _Idle extends FrostActionState {
  const _Idle() : super._();
}

/// See [FrostActionState.running].
final class FrostActionRunning extends FrostActionState {
  const FrostActionRunning({this.onCancel}) : super._();
  final VoidCallback? onCancel;
}

/// A finished operation; see [FrostActionState.succeeded] and
/// [FrostActionState.failed]. A control draws the result once per [operation].
sealed class FrostActionResult extends FrostActionState {
  const FrostActionResult({required this.operation}) : super._();
  final Object operation;
}

/// See [FrostActionState.succeeded].
final class FrostActionSucceeded extends FrostActionResult {
  const FrostActionSucceeded({required super.operation});
}

/// See [FrostActionState.failed].
final class FrostActionFailed extends FrostActionResult {
  const FrostActionFailed({required super.operation});
}

/// Runs one asynchronous operation at a time and keeps its [state]. Pass
/// `() => runner.run(action)` as a control's press callback and `runner.state`
/// as its state, and rebuild the control when the runner notifies.
class FrostActionRunner extends ChangeNotifier {
  FrostActionState _state = FrostActionState.idle;
  int _generation = 0;

  FrostActionState get state => _state;

  /// Runs [action] unless an operation is already running. True succeeds and
  /// false fails; an exception fails and is reported through [FlutterError].
  Future<void> run(Future<bool> Function() action) async {
    if (_state is FrostActionRunning) return;
    final generation = ++_generation;
    _set(const FrostActionState.running());
    bool success;
    try {
      success = await action();
    } catch (error, stack) {
      success = false;
      FlutterError.reportError(
        FlutterErrorDetails(exception: error, stack: stack, library: 'frost_ui', context: ErrorDescription('while running a control action')),
      );
    }
    if (generation != _generation) return;
    final operation = Object();
    _set(success ? FrostActionState.succeeded(operation: operation) : FrostActionState.failed(operation: operation));
  }

  /// Discards a pending operation's result and returns to idle.
  void cancel() {
    _generation++;
    _set(FrostActionState.idle);
  }

  void _set(FrostActionState value) {
    _state = value;
    notifyListeners();
  }
}
