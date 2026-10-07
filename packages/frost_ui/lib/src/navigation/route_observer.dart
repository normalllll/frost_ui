import 'package:flutter/widgets.dart';
import 'package:flutter/scheduler.dart';

/// Route changes include popup menus and dialogs, unlike router URI changes.
class FrostRouteObserver extends NavigatorObserver {
  final changes = ValueNotifier<int>(0);
  Route<dynamic>? topRoute;
  final _menus = <Object>{};
  bool get menuOpen => _menus.isNotEmpty;
  void menuOpened(Object owner) {
    if (_menus.add(owner)) _notice();
  }

  void menuClosed(Object owner) {
    if (_menus.remove(owner)) _notice();
  }

  void _notice() {
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) => changes.value++);
    } else {
      changes.value++;
    }
  }

  @override
  void didChangeTop(Route<dynamic> topRoute, Route<dynamic>? previousTopRoute) {
    this.topRoute = topRoute;
    _notice();
  }
}

final frostRootRouteObserver = FrostRouteObserver();
final frostContentRouteObserver = FrostRouteObserver();
