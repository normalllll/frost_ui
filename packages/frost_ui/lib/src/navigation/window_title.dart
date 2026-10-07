import 'package:flutter/widgets.dart';

/// What a mounted page tells the window about itself: a title for the
/// caption and taskbar, and optionally an image that tints the ambient
/// backdrop. [id] is only compared, to skip repeated updates; [kind] is a
/// free tag for the app's own title rules.
@immutable
class FrostPageTitle {
  const FrostPageTitle({required this.id, required this.title, this.kind, this.imageUrl});

  final Object id;
  final String title;
  final String? kind;
  final String? imageUrl;

  @override
  bool operator ==(Object other) => other is FrostPageTitle && other.id == id && other.title == title && other.kind == kind && other.imageUrl == imageUrl;

  @override
  int get hashCode => Object.hash(id, title, kind, imageUrl);
}

/// Page data is contributed by the mounted page, so the window chrome never
/// starts another request just to render a title. The app reports the
/// visible location with [updateLocation] (from its router) and resolves the
/// caption from [location] and [page].
class FrostWindowTitleRegistry extends ChangeNotifier {
  final Map<String, Map<Object, FrostPageTitle>> _pages = {};
  bool _locationQueued = false;
  bool _noticeQueued = false;
  bool _disposed = false;
  Uri _location = Uri(path: '/');
  Uri? _pendingLocation;

  /// The visible location, as last reported.
  Uri get location => _location;

  /// Reports the visible location. Routers may notify while a nested Router
  /// is building; the change is published once that frame has completed so
  /// the outer title bar can rebuild safely.
  void updateLocation(Uri location) {
    _pendingLocation = location;
    if (_locationQueued) return;
    _locationQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _locationQueued = false;
      final next = _pendingLocation;
      if (_disposed || next == null || next == _location) return;
      _location = next;
      notifyListeners();
    });
  }

  /// The latest contribution for [path], if a page there is mounted.
  FrostPageTitle? page(String path) {
    final owners = _pages[path];
    return owners == null || owners.isEmpty ? null : owners.values.last;
  }

  void setPage(String path, Object owner, FrostPageTitle? page) {
    if (page == null) {
      remove(path, owner);
      return;
    }
    final owners = _pages.putIfAbsent(path, () => {});
    if (owners[owner] == page) return;
    owners[owner] = page;
    notifyListeners();
  }

  void remove(String path, Object owner) {
    final owners = _pages[path];
    if (owners == null || owners.remove(owner) == null) return;
    if (owners.isEmpty) _pages.remove(path);
    // Page disposal happens while Flutter finalizes a frame and the widget
    // tree is locked. Its removal can only be published after that frame.
    if (_noticeQueued) return;
    _noticeQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _noticeQueued = false;
      if (!_disposed) notifyListeners();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class FrostWindowTitleScope extends InheritedWidget {
  const FrostWindowTitleScope({required this.registry, required super.child, super.key});

  final FrostWindowTitleRegistry registry;

  static FrostWindowTitleRegistry? maybeOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<FrostWindowTitleScope>()?.registry;

  @override
  bool updateShouldNotify(FrostWindowTitleScope oldWidget) => !identical(registry, oldWidget.registry);
}

/// Contributes [page] for [path] while mounted.
class FrostWindowTitleContribution extends StatefulWidget {
  const FrostWindowTitleContribution({required this.path, required this.page, required this.child, super.key});

  final String path;
  final FrostPageTitle? page;
  final Widget child;

  @override
  State<FrostWindowTitleContribution> createState() => _FrostWindowTitleContributionState();
}

class _FrostWindowTitleContributionState extends State<FrostWindowTitleContribution> {
  final Object _owner = Object();
  FrostWindowTitleRegistry? _registry;
  String? _registeredPath;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _registry = FrostWindowTitleScope.maybeOf(context);
    _scheduleUpdate();
  }

  @override
  void didUpdateWidget(FrostWindowTitleContribution oldWidget) {
    super.didUpdateWidget(oldWidget);
    _scheduleUpdate();
  }

  void _scheduleUpdate() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_registeredPath case final registered? when registered != widget.path) _registry?.remove(registered, _owner);
      _registeredPath = widget.path;
      _registry?.setPage(widget.path, _owner, widget.page);
    });
  }

  @override
  void dispose() {
    if (_registeredPath case final path?) _registry?.remove(path, _owner);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
