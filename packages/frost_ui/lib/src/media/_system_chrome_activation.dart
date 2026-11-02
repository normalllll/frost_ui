import 'package:flutter/widgets.dart';

import '../foundation/metrics.dart';

/// How much the [active] state of the media below applies to its system-bar
/// protection. A change eases over, so media scrolling under a header does not
/// cut the protection off. Its ticker sits above whatever the state hides.
class FrostSystemChromeActivation extends StatefulWidget {
  const FrostSystemChromeActivation({required this.active, required this.child, super.key});
  final bool active;
  final Widget child;

  /// The nearest activation; without one, media always counts as active.
  static Animation<double>? of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<_ActivationScope>()?.value;

  @override
  State<FrostSystemChromeActivation> createState() => _ActivationState();
}

class _ActivationState extends State<FrostSystemChromeActivation> with SingleTickerProviderStateMixin {
  late final _value = AnimationController(vsync: this, value: widget.active ? 1 : 0);

  @override
  void didUpdateWidget(FrostSystemChromeActivation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active != oldWidget.active) {
      _value.animateTo(widget.active ? 1 : 0, duration: FrostMotion.duration(context, FrostMotion.snappyDuration));
    }
  }

  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _ActivationScope(value: _value, child: widget.child);
}

class _ActivationScope extends InheritedWidget {
  const _ActivationScope({required this.value, required super.child});
  final Animation<double> value;
  @override
  bool updateShouldNotify(_ActivationScope oldWidget) => value != oldWidget.value;
}
