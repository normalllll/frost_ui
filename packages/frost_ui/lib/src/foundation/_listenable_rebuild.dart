import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Runs [callback] now, or after the frame when widgets are being built: a
/// notification that arrives while an unrelated widget builds must not mark
/// another one dirty.
void frostRunOutsideBuild(VoidCallback callback) {
  if (SchedulerBinding.instance.schedulerPhase != SchedulerPhase.persistentCallbacks) return callback();
  SchedulerBinding.instance.addPostFrameCallback((_) => callback());
  SchedulerBinding.instance.ensureVisualUpdate();
}

/// Builds with [builder] again whenever [listenable] notifies, and only once
/// while it is null. Unlike choosing between a [ListenableBuilder] and a plain
/// widget, the element is the same either way, so what [builder] returns
/// keeps its state as [listenable] comes and goes. [child] is built once.
class FrostListenableRebuild extends StatefulWidget {
  const FrostListenableRebuild({required this.listenable, required this.builder, this.child, super.key});
  final Listenable? listenable;
  final TransitionBuilder builder;
  final Widget? child;

  @override
  State<FrostListenableRebuild> createState() => _FrostListenableRebuildState();
}

class _FrostListenableRebuildState extends State<FrostListenableRebuild> {
  @override
  void initState() {
    super.initState();
    widget.listenable?.addListener(_changed);
  }

  @override
  void didUpdateWidget(FrostListenableRebuild oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.listenable, widget.listenable)) return;
    oldWidget.listenable?.removeListener(_changed);
    widget.listenable?.addListener(_changed);
  }

  @override
  void dispose() {
    widget.listenable?.removeListener(_changed);
    super.dispose();
  }

  void _changed() => frostRunOutsideBuild(() {
    if (mounted) setState(() {});
  });

  @override
  Widget build(BuildContext context) => widget.builder(context, widget.child);
}
