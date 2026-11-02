import 'package:flutter/widgets.dart';

/// Library-only: marks one of several bodies kept under a [FrostPinnedChrome],
/// such as the sections of a browse page, as the one on screen. The chrome's
/// glass and its sliding header row follow only that body's scrolling.
class FrostChromeActiveBody extends InheritedWidget {
  const FrostChromeActiveBody({required this.active, required super.child, super.key});
  final bool active;

  /// Whether scrolling at [context] belongs to the body on screen. Bodies
  /// outside any marked group always do.
  static bool isActive(BuildContext? context) => context?.getInheritedWidgetOfExactType<FrostChromeActiveBody>()?.active ?? true;

  @override
  bool updateShouldNotify(FrostChromeActiveBody oldWidget) => active != oldWidget.active;
}
