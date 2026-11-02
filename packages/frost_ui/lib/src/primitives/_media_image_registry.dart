import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Local ownership, like fields registered with a Form; never a global table.
/// Listeners drive render transforms, not ancestor widget rebuilds. This makes
/// registration during a child's build safe and removes scaling in the same
/// frame that the last displayed image becomes error/placeholder content.
///
/// Besides displayed images the registry knows of images that are still
/// pending (loading, or failed and replaced by a placeholder) and of the
/// opacity a fading image has reached. A registry whose scope sits inside
/// another scope forwards everything to it, so an enclosing frame learns of
/// images under a card's own scope.
class FrostMediaImageRegistry extends ChangeNotifier {
  final _images = <Object>{};
  final _pending = <Object>{};
  final _reveals = <Object, double>{};
  FrostMediaImageRegistry? _parent;
  bool _disposed = false;
  bool get hasImages => _images.isNotEmpty;

  /// Some enclosed image has not produced a frame, or failed to.
  bool get hasPending => _pending.isNotEmpty;

  /// How far the most revealed fading image has faded in; 1 when none fades.
  double get reveal => _reveals.isEmpty ? 1 : _reveals.values.reduce(math.max);

  set parent(FrostMediaImageRegistry? value) {
    if (_disposed || identical(value, _parent)) return;
    final old = _parent;
    _parent = value;
    for (final image in _images) {
      old?.remove(image);
      value?.add(image);
    }
    for (final image in _pending) {
      old?.removePending(image);
      value?.addPending(image);
    }
    _reveals.forEach((source, opacity) {
      old?.clearReveal(source);
      value?.setReveal(source, opacity);
    });
  }

  void _change(void Function() mutate) {
    if (_disposed) return;
    final images = hasImages, pending = hasPending, reveal = this.reveal;
    mutate();
    if (images != hasImages || pending != hasPending || reveal != this.reveal) notifyListeners();
  }

  void add(Object image) {
    if (_disposed) return;
    _change(() => _images.add(image));
    _parent?.add(image);
  }

  void remove(Object image) {
    if (_disposed) return;
    _change(() => _images.remove(image));
    _parent?.remove(image);
  }

  void addPending(Object image) {
    if (_disposed) return;
    _change(() => _pending.add(image));
    _parent?.addPending(image);
  }

  void removePending(Object image) {
    if (_disposed) return;
    _change(() => _pending.remove(image));
    _parent?.removePending(image);
  }

  void setReveal(Object source, double opacity) {
    if (_disposed) return;
    _change(() => _reveals[source] = opacity);
    _parent?.setReveal(source, opacity);
  }

  void clearReveal(Object source) {
    if (_disposed) return;
    _change(() => _reveals.remove(source));
    _parent?.clearReveal(source);
  }

  @override
  void dispose() {
    _disposed = true;
    _images.clear();
    _pending.clear();
    _reveals.clear();
    _parent = null;
    super.dispose();
  }
}

class _MediaImageScope extends InheritedWidget {
  const _MediaImageScope({required this.registry, required super.child});
  final FrostMediaImageRegistry? registry;
  @override
  bool updateShouldNotify(_MediaImageScope oldWidget) => registry != oldWidget.registry;
}

/// Offers [registry] to the images below and links it to the scope above, so
/// the outer owner also hears of them. A null registry closes the scope: images
/// below it belong to no outer owner.
class FrostMediaImageRegistryScope extends StatefulWidget {
  const FrostMediaImageRegistryScope({required this.registry, required this.child, super.key});
  final FrostMediaImageRegistry? registry;
  final Widget child;

  /// The nearest registry, and a dependency on it.
  static FrostMediaImageRegistry? maybeOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<_MediaImageScope>()?.registry;
  @override
  State<FrostMediaImageRegistryScope> createState() => _MediaImageRegistryScopeState();
}

class _MediaImageRegistryScopeState extends State<FrostMediaImageRegistryScope> {
  FrostMediaImageRegistry? _linked;

  void _link() {
    // This lookup starts above the inherited widget built below, so it finds
    // the outer scope.
    final outer = FrostMediaImageRegistryScope.maybeOf(context);
    final registry = widget.registry;
    if (!identical(_linked, registry)) _linked?.parent = null;
    _linked = registry;
    registry?.parent = outer;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _link();
  }

  @override
  void didUpdateWidget(FrostMediaImageRegistryScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    _link();
  }

  @override
  void dispose() {
    _linked?.parent = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _MediaImageScope(registry: widget.registry, child: widget.child);
}

/// Registers its state with the nearest registry while mounted. Re-attaching
/// the state under a different scope, for example through a GlobalKey, moves
/// the registration because the scope is an inherited dependency.
mixin FrostMediaImageClaim<T extends StatefulWidget> on State<T> {
  FrostMediaImageRegistry? _claimed;

  /// A pending claim stands for an image that has not produced a frame; the
  /// default claim stands for a displayed image.
  bool get claimsPending => false;

  void _claim() {
    final next = FrostMediaImageRegistryScope.maybeOf(context);
    if (identical(next, _claimed)) return;
    _release();
    _claimed = next;
    if (claimsPending) {
      next?.addPending(this);
    } else {
      next?.add(this);
    }
  }

  void _release() {
    if (claimsPending) {
      _claimed?.removePending(this);
    } else {
      _claimed?.remove(this);
    }
    _claimed = null;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _claim();
  }

  @override
  void deactivate() {
    _release();
    super.deactivate();
  }
}

/// Marks content standing in for an image that has not produced a frame: a
/// loading placeholder, a skeleton or an error placeholder. The enclosing media
/// frame paints no stroke around it.
class FrostMediaImagePending extends StatefulWidget {
  const FrostMediaImagePending({required this.child, super.key});
  final Widget child;
  @override
  State<FrostMediaImagePending> createState() => _MediaImagePendingState();
}

class _MediaImagePendingState extends State<FrostMediaImagePending> with FrostMediaImageClaim {
  @override
  bool get claimsPending => true;
  @override
  Widget build(BuildContext context) => widget.child;
}

class FrostMediaImageHost extends StatefulWidget {
  const FrostMediaImageHost({required this.builder, super.key});
  final Widget Function(BuildContext context, FrostMediaImageRegistry registry) builder;
  @override
  State<FrostMediaImageHost> createState() => _ImageHostState();
}

class _ImageHostState extends State<FrostMediaImageHost> {
  final _registry = FrostMediaImageRegistry();
  @override
  void dispose() {
    _registry.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FrostMediaImageRegistryScope(registry: null, child: widget.builder(context, _registry));
}
