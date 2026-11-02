import 'dart:async';
import 'package:flutter/widgets.dart';

import '../controls/buttons.dart';
import '../foundation/scope.dart';
import '../foundation/sizes.dart';

/// The presenter's recovery action, sharing button loading/duplicate guards.
/// True invokes [onResolved] exactly once. False, exceptions, replaced errors
/// and unmounted owners never retry. Exceptions follow FrostButton reporting;
/// the App action handles expected failures and its localized feedback.
class FrostErrorActionButton extends StatefulWidget {
  const FrostErrorActionButton({required this.error, required this.onResolved, this.size, super.key}) : _iconOnly = false;
  const FrostErrorActionButton.icon({required this.error, required this.onResolved, this.size, super.key}) : _iconOnly = true;
  final Object error;
  final FutureOr<void> Function()? onResolved;
  final FrostControlSize? size;
  final bool _iconOnly;
  @override
  State<FrostErrorActionButton> createState() => _ErrorActionButtonState();
}

class _ErrorActionButtonState extends State<FrostErrorActionButton> {
  final _runner = FrostActionRunner();
  int _generation = 0;
  @override
  void didUpdateWidget(FrostErrorActionButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.error, widget.error)) {
      _generation++;
      _runner.cancel();
    }
  }

  @override
  void dispose() {
    _generation++;
    _runner
      ..cancel()
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final action = FrostScope.errorsOf(context).action?.call(context, widget.error);
    if (action == null) return const SizedBox.shrink();
    final generation = _generation;
    Future<bool> run() async {
      final resolved = await action.onPressed();
      if (!mounted || generation != _generation) return false;
      if (resolved) await widget.onResolved?.call();
      return resolved;
    }

    return ListenableBuilder(
      listenable: _runner,
      builder: (context, _) => widget._iconOnly
          ? FrostButton.icon(
              key: ObjectKey(widget.error),
              icon: action.icon,
              label: action.label,
              size: widget.size,
              onPressed: () => _runner.run(run),
              state: _runner.state,
            )
          : FrostButton(
              key: ObjectKey(widget.error),
              icon: action.icon,
              label: action.label,
              size: widget.size,
              onPressed: () => _runner.run(run),
              state: _runner.state,
            ),
    );
  }
}
