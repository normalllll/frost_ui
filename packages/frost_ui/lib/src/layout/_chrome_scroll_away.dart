import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Library-only link between [FrostPinnedChrome] and chrome whose top part
/// slides away while the body scrolls on. The chrome reports that part's
/// height and whether it must stay; the pinned bar follows the scroll
/// direction and drives [hidden]. The body's reserved height never changes.
class FrostChromeScrollAway extends ChangeNotifier {
  FrostChromeScrollAway(this.hidden);

  /// 0 while the part is shown, 1 once it has slid away.
  final Animation<double> hidden;

  double _extent = 0;
  bool _held = false, _notifyScheduled = false, _disposed = false;

  /// Height of the part that slides away; 0 when nothing does.
  double get extent => _extent;

  /// Focus or an expanded search in the part keeps it shown.
  bool get held => _held;

  /// How far the part has currently moved up.
  double get offset => _extent * hidden.value;

  /// Written from layout; listeners hear of it once the frame ends.
  void report({required double extent, required bool held}) {
    if (_extent == extent && _held == held) return;
    _extent = extent;
    _held = held;
    if (SchedulerBinding.instance.schedulerPhase != SchedulerPhase.persistentCallbacks) {
      notifyListeners();
      return;
    }
    if (_notifyScheduled) return;
    _notifyScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _notifyScheduled = false;
      if (!_disposed) notifyListeners();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class FrostChromeScrollAwayScope extends InheritedWidget {
  const FrostChromeScrollAwayScope({required this.link, required super.child, super.key});
  final FrostChromeScrollAway link;
  static FrostChromeScrollAway? maybeOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<FrostChromeScrollAwayScope>()?.link;
  @override
  bool updateShouldNotify(FrostChromeScrollAwayScope oldWidget) => link != oldWidget.link;
}
