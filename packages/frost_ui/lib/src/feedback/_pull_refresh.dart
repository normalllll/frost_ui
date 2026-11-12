import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../foundation/metrics.dart';

/// Where a pull-to-refresh is in its life.
///
/// [idle] is at rest; [drag] and [armed] are a finger pulling below and at or
/// above [FrostPullRefresh.holdExtent]; [refreshing] runs the refresh action;
/// [done] and [failed] are its outcome while the extent retracts or holds.
enum FrostPullRefreshPhase { idle, drag, armed, refreshing, done, failed }

/// The phase and the pulled-down extent, published together.
@immutable
class FrostPullRefreshValue {
  const FrostPullRefreshValue({required this.phase, required this.extent});

  final FrostPullRefreshPhase phase;
  final double extent;

  @override
  bool operator ==(Object other) => other is FrostPullRefreshValue && other.phase == phase && other.extent == extent;

  @override
  int get hashCode => Object.hash(phase, extent);

  @override
  String toString() => 'FrostPullRefreshValue($phase, $extent)';
}

/// Scroll physics of a refresh viewport: it never overscrolls, and it accepts
/// a drag even when the content is shorter than the viewport.
class FrostRefreshPhysics extends ClampingScrollPhysics {
  const FrostRefreshPhysics({super.parent});

  @override
  FrostRefreshPhysics applyTo(ScrollPhysics? ancestor) => FrostRefreshPhysics(parent: buildParent(ancestor));

  @override
  bool shouldAcceptUserOffset(ScrollMetrics position) => true;
}

/// Owns the pull-to-refresh state machine of the scroll views below it.
///
/// A pull starts when a vertical scroll starts at the top. Each overscroll
/// moves the extent by half its distance; releasing past [holdExtent] runs
/// [onRefresh], and the extent stays at [holdExtent] until it completes. A
/// failure holds for [failedHold] so the header can be tapped to retry. The
/// header reads [FrostPullRefreshState.value] through [maybeOf].
class FrostPullRefresh extends StatefulWidget {
  const FrostPullRefresh({required this.onRefresh, required this.child, this.enabled = true, this.nested = false, super.key});

  /// The extent a refresh holds, and the extent that arms a pull.
  static const holdExtent = 56.0;

  /// The farthest the header can be pulled.
  static const maxExtent = 120.0;

  /// How long a failed refresh stays before it retracts.
  static const failedHold = Duration(seconds: 3);

  /// Completes with whether the refresh succeeded. A thrown error is reported
  /// and counts as a failure.
  final Future<bool> Function() onRefresh;
  final Widget child;
  final bool enabled;

  /// Whether scroll views below another scrollable also pull, such as the body
  /// of a nested scroll view. Otherwise only the nearest one does.
  final bool nested;

  /// The pull refresh above [context], or null; the caller depends on it.
  static FrostPullRefreshState? maybeOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<_PullRefreshScope>()?.state;

  @override
  State<FrostPullRefresh> createState() => FrostPullRefreshState();
}

class FrostPullRefreshState extends State<FrostPullRefresh> with SingleTickerProviderStateMixin {
  late final AnimationController _motion = AnimationController(vsync: this, upperBound: FrostPullRefresh.maxExtent)..addListener(_publish);
  final _value = ValueNotifier<FrostPullRefreshValue>(const FrostPullRefreshValue(phase: FrostPullRefreshPhase.idle, extent: 0));

  FrostPullRefreshPhase _phase = FrostPullRefreshPhase.idle;
  bool _pulling = false;

  // The extent the current pull began at. A pull that begins at or above the
  // hold extent (from a failed hold) arms only once pulled further down.
  double _pullStart = 0;
  Timer? _hold;
  Completer<void>? _pending;

  // Both change whenever something takes over the extent, so an older
  // animation or refresh that finishes later knows it was replaced.
  int _epoch = 0;
  int _run = 0;

  /// The current phase and extent. A late listener reads the current value at
  /// once.
  ValueListenable<FrostPullRefreshValue> get value => _value;

  /// Runs the refresh from the current extent, as if it had been pulled. While
  /// one runs it returns the same pending future. It completes when the
  /// refresh has ended, or when this state is disposed.
  Future<void> refresh() {
    if (!widget.enabled || !mounted) return Future<void>.value();
    final pending = _pending;
    if (_phase == FrostPullRefreshPhase.refreshing && pending != null) return pending.future;
    return _startRefresh();
  }

  @override
  void didUpdateWidget(FrostPullRefresh oldWidget) {
    super.didUpdateWidget(oldWidget);
    final held = _phase == FrostPullRefreshPhase.drag || _phase == FrostPullRefreshPhase.armed || _phase == FrostPullRefreshPhase.failed;
    if (oldWidget.enabled && !widget.enabled && held) {
      _pulling = false;
      _hold?.cancel();
      _retract();
    }
  }

  @override
  void dispose() {
    _epoch++;
    _run++;
    _hold?.cancel();
    final pending = _pending;
    if (pending != null && !pending.isCompleted) pending.complete();
    _motion.dispose();
    _value.dispose();
    super.dispose();
  }

  void _publish() {
    if (!mounted) return;
    _value.value = FrostPullRefreshValue(phase: _phase, extent: _motion.value);
  }

  void _setPhase(FrostPullRefreshPhase phase) {
    _phase = phase;
    _publish();
  }

  Duration _duration(Duration value) => FrostMotion.duration(context, value);

  /// Takes the extent over from any running motion and sets it.
  void _setExtent(double extent, {FrostPullRefreshPhase? phase}) {
    _epoch++;
    _motion.stop();
    if (phase != null) _phase = phase;
    _motion.value = extent.clamp(0.0, FrostPullRefresh.maxExtent);
    _publish();
  }

  void _pull(double extent) {
    final clamped = extent.clamp(0.0, FrostPullRefresh.maxExtent);
    final armed = clamped >= FrostPullRefresh.holdExtent && clamped > _pullStart;
    _setExtent(clamped, phase: armed ? FrostPullRefreshPhase.armed : FrostPullRefreshPhase.drag);
  }

  void _holdExtent() {
    _epoch++;
    unawaited(_motion.animateTo(FrostPullRefresh.holdExtent, duration: _duration(FrostMotion.snappyDuration), curve: Curves.easeOutCubic));
  }

  /// Retracts to zero and then rests at idle, unless something takes over.
  Future<void> _retract() async {
    if (_motion.value == 0) {
      _epoch++;
      _setPhase(FrostPullRefreshPhase.idle);
      return;
    }
    final epoch = ++_epoch;
    await _motion.animateTo(0, duration: _duration(FrostMotion.exit), curve: Curves.easeOutCubic);
    if (!mounted || epoch != _epoch) return;
    _setPhase(FrostPullRefreshPhase.idle);
  }

  Future<void> _startRefresh() {
    _hold?.cancel();
    _pulling = false;
    final run = ++_run;
    final pending = Completer<void>();
    _pending = pending;
    _setPhase(FrostPullRefreshPhase.refreshing);
    _holdExtent();
    Future<bool> result;
    try {
      result = widget.onRefresh();
    } catch (error, stack) {
      FlutterError.reportError(FlutterErrorDetails(exception: error, stack: stack, library: 'frost_ui', context: ErrorDescription('while refreshing')));
      _finish(run, false);
      return pending.future;
    }
    result.then<void>(
      (ok) => _finish(run, ok),
      onError: (Object error, StackTrace stack) {
        // A result for a view that is gone or a run that was replaced is stale.
        if (!mounted || run != _run) return;
        _report(error, stack);
        _finish(run, false);
      },
    );
    return pending.future;
  }

  void _report(Object error, StackTrace stack) {
    FlutterError.reportError(FlutterErrorDetails(exception: error, stack: stack, library: 'frost_ui', context: ErrorDescription('while refreshing')));
  }

  void _finish(int run, bool ok) {
    if (!mounted || run != _run) return;
    final pending = _pending;
    if (ok) {
      _setPhase(FrostPullRefreshPhase.done);
      unawaited(_retract());
    } else {
      _setPhase(FrostPullRefreshPhase.failed);
      _hold?.cancel();
      _hold = Timer(FrostPullRefresh.failedHold, _endFailedHold);
    }
    if (pending != null && !pending.isCompleted) pending.complete();
  }

  void _endFailedHold() {
    if (!mounted || _phase != FrostPullRefreshPhase.failed) return;
    unawaited(_retract());
  }

  void _begin() {
    _hold?.cancel();
    _pulling = true;
    _pullStart = _motion.value;
    _pull(_motion.value);
  }

  void _release() {
    _pulling = false;
    if (_phase == FrostPullRefreshPhase.armed) {
      unawaited(_startRefresh());
    } else {
      unawaited(_retract());
    }
  }

  bool _onScroll(ScrollNotification notification) {
    if (!widget.enabled || notification.metrics.axis != Axis.vertical) return false;
    if (!widget.nested && notification.depth != 0) return false;
    final metrics = notification.metrics;
    if (notification is ScrollStartNotification) {
      if (_pulling) {
        // The scrollable of the last pull went away without an end.
        _pulling = false;
        unawaited(_retract());
      }
      if (_phase != FrostPullRefreshPhase.refreshing && metrics.extentBefore == 0) _begin();
    } else if (!_pulling) {
      return false;
    } else if (notification is OverscrollNotification) {
      _pull(_motion.value - notification.overscroll / 2);
    } else if (notification is ScrollUpdateNotification) {
      if (metrics.extentBefore > 0) {
        // The content left the top: an armed pull refreshes, any other ends.
        _release();
      } else {
        _pull(_motion.value - (notification.scrollDelta ?? 0));
        if (_phase == FrostPullRefreshPhase.armed && notification.dragDetails == null) _release();
      }
    } else if (notification is ScrollEndNotification) {
      _release();
    }
    return false;
  }

  bool _onGlow(OverscrollIndicatorNotification notification) {
    if (!notification.leading || !_pulling || !widget.enabled) return false;
    if (!widget.nested && notification.depth != 0) return false;
    notification.disallowIndicator();
    return true;
  }

  @override
  Widget build(BuildContext context) => _PullRefreshScope(
    state: this,
    child: NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      child: NotificationListener<OverscrollIndicatorNotification>(onNotification: _onGlow, child: widget.child),
    ),
  );
}

class _PullRefreshScope extends InheritedWidget {
  const _PullRefreshScope({required this.state, required super.child});

  final FrostPullRefreshState state;

  @override
  bool updateShouldNotify(_PullRefreshScope oldWidget) => state != oldWidget.state;
}
