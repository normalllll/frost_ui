import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Library-only: the page title a shell's title row or top bar shows. The
/// visible page's header claims it with its declared title and stops drawing
/// that title itself; the last claim among the visible headers wins, so a page
/// pushed over another, or a split view's detail, names the window.
class FrostShellPageTitle extends ChangeNotifier {
  final _claims = <(Object, Widget)>[];
  bool _queued = false, _disposed = false;

  Object? get owner => _claims.lastOrNull?.$1;
  Widget? get title => _claims.lastOrNull?.$2;

  /// Whether [owner]'s title is the one the shell shows.
  bool shows(Object owner) => identical(this.owner, owner);

  /// Called while the header builds: the header can decide in the same frame,
  /// and the title row hears after it.
  void claim(Object owner, Widget title) {
    final index = _claims.indexWhere((claim) => identical(claim.$1, owner));
    if (index >= 0) {
      if (identical(_claims[index].$2, title) || _claims[index].$2 == title) return;
      _claims[index] = (owner, title);
      if (index == _claims.length - 1) _notifyLater();
      return;
    }
    _claims.add((owner, title));
    _notifyLater();
  }

  void release(Object owner) {
    final index = _claims.indexWhere((claim) => identical(claim.$1, owner));
    if (index < 0) return;
    _claims.removeAt(index);
    if (index == _claims.length) _notifyLater();
  }

  void _notifyLater() {
    if (_queued) return;
    _queued = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _queued = false;
      if (!_disposed) notifyListeners();
    });
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class FrostShellPageTitleScope extends InheritedWidget {
  const FrostShellPageTitleScope({required this.title, required super.child, super.key});

  /// Null where the shell has no row that shows page titles: page headers then
  /// draw their own.
  final FrostShellPageTitle? title;

  static FrostShellPageTitle? maybeOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<FrostShellPageTitleScope>()?.title;

  @override
  bool updateShouldNotify(FrostShellPageTitleScope oldWidget) => !identical(title, oldWidget.title);
}
