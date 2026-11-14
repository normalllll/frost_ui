import 'package:flutter/widgets.dart';

import '../foundation/density.dart';
import '../overlays/overlay_region.dart';

// Internal bridge from the shell's live content region to the app-level host.
// The host stays above the Navigator; no second toast host or route is created.
class FrostToastViewportRegistry extends ChangeNotifier {
  final _owners = <FrostToastViewportState>[];
  bool _queued = false, _disposed = false;
  FrostToastViewportState? get owner => _owners.where((o) => o.mounted && o.enabled).lastOrNull;
  void attach(FrostToastViewportState owner) {
    if (!_owners.contains(owner)) _owners.add(owner);
    changed();
  }

  void detach(FrostToastViewportState owner) {
    _owners.remove(owner);
    changed();
  }

  void changed() {
    if (_queued || _disposed) return;
    _queued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _queued = false;
      if (!_disposed) notifyListeners();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class FrostToastViewportScope extends InheritedWidget {
  const FrostToastViewportScope({required this.registry, required super.child, super.key});
  final FrostToastViewportRegistry registry;
  static FrostToastViewportRegistry? maybeOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<FrostToastViewportScope>()?.registry;
  @override
  bool updateShouldNotify(FrostToastViewportScope oldWidget) => registry != oldWidget.registry;
}

class FrostToastViewport extends StatefulWidget {
  const FrostToastViewport({required super.key, required this.child, this.bottomInset = 0});
  final Widget child;

  /// The height at the bottom of the viewport that a bar lies over; toasts
  /// stay above it.
  final double bottomInset;
  @override
  State<FrostToastViewport> createState() => FrostToastViewportState();
}

class FrostToastViewportState extends State<FrostToastViewport> {
  FrostToastViewportRegistry? _registry;
  FrostOverlayBounds? bounds;
  bool touch = false, enabled = true;
  MediaQueryData? media;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    touch = !FrostDensity.of(context).usesPointer;
    enabled = TickerMode.valuesOf(context).enabled;
    media = MediaQuery.of(context);
    final next = FrostToastViewportScope.maybeOf(context);
    if (_registry != next) {
      _registry?.detach(this);
      _registry = next;
    }
    final region = FrostOverlayRegionData.maybeOf(context);
    if (region != bounds) {
      bounds?.removeListener(_changed);
      bounds = region;
      bounds?.addListener(_changed);
    }
    _registry?.attach(this);
  }

  void _changed() => _registry?.changed();
  @override
  void dispose() {
    bounds?.removeListener(_changed);
    _registry?.detach(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
