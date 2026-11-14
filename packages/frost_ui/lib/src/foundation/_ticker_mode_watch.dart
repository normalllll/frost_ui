import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '_listenable_rebuild.dart';

/// Tells a State when the tickers around it stop or start, as when its route
/// is covered or uncovered, without making the State a [TickerMode]
/// dependent. A dependent is rebuilt at every such change; a page of controls
/// that only need to drop a press or a hover then all rebuild for nothing.
///
/// [attach] from `didChangeDependencies` and [dispose] with the State.
/// The callback runs outside the build phase, so it may call `setState`; it
/// should do so only when what the State shows changes.
class FrostTickerModeWatch {
  FrostTickerModeWatch(this._changed);
  final VoidCallback _changed;
  ValueListenable<TickerModeData>? _mode;

  bool get enabled => _mode?.value.enabled ?? true;

  void attach(BuildContext context) {
    final mode = TickerMode.getValuesNotifier(context);
    if (identical(mode, _mode)) return;
    _mode?.removeListener(_notify);
    _mode = mode..addListener(_notify);
  }

  void _notify() => frostRunOutsideBuild(() {
    if (_mode != null) _changed();
  });

  void dispose() {
    _mode?.removeListener(_notify);
    _mode = null;
  }
}
