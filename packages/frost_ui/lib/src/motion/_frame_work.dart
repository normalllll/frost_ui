import 'dart:collection';

import 'package:flutter/scheduler.dart';

/// Cancellable UI work shared across page owners, never a business-work queue.
/// At most one callback releases a paint gate for the following frame.
class FrostFrameWork {
  FrostFrameWork._(this._callback);
  VoidCallback? _callback;
  void cancel() => _callback = null;
}

class FrostFrameWorkQueue {
  static final _pending = Queue<FrostFrameWork>();
  static bool _scheduled = false;

  static FrostFrameWork enqueue(VoidCallback callback) {
    final work = FrostFrameWork._(callback);
    _pending.add(work);
    _schedule();
    return work;
  }

  static void _schedule() {
    if (_scheduled || _pending.isEmpty) return;
    _scheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      while (_pending.isNotEmpty) {
        final work = _pending.removeFirst();
        final callback = work._callback;
        work.cancel();
        if (callback == null) continue;
        callback();
        break;
      }
      _schedule();
    });
    SchedulerBinding.instance.ensureVisualUpdate();
  }
}
