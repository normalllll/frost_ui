import 'package:flutter/widgets.dart';

/// Marks one of several bodies kept under a [FrostPinnedChrome], such as the
/// sections of a tab view, as the one on screen. The chrome's glass and its
/// sliding header row follow only that body's scrolling, and catch up with its
/// position when it becomes the one on screen.
class FrostChromeActiveBody extends StatefulWidget {
  const FrostChromeActiveBody({required this.active, required this.child, super.key});
  final bool active;
  final Widget child;

  /// Whether scrolling at [context] belongs to the body on screen. Bodies
  /// outside any marked group always do.
  static bool isActive(BuildContext? context) => context?.getInheritedWidgetOfExactType<_ActiveBodyScope>()?.active ?? true;

  @override
  State<FrostChromeActiveBody> createState() => _ChromeActiveBodyState();
}

/// Library-only: tells the pinned chrome above that its body on screen changed.
class FrostChromeBodyActivated extends Notification {}

class _ChromeActiveBodyState extends State<FrostChromeActiveBody> {
  @override
  void didUpdateWidget(FrostChromeActiveBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.active || oldWidget.active) return;
    // After the frame, so the other bodies already read as inactive.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.active) FrostChromeBodyActivated().dispatch(context);
    });
  }

  @override
  Widget build(BuildContext context) => _ActiveBodyScope(active: widget.active, child: widget.child);
}

class _ActiveBodyScope extends InheritedWidget {
  const _ActiveBodyScope({required this.active, required super.child});
  final bool active;
  @override
  bool updateShouldNotify(_ActiveBodyScope oldWidget) => active != oldWidget.active;
}
