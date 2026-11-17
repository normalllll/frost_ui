part of 'shell.dart';

/// Asks the [FrostShell] for the whole window while this page is the visible
/// page, for a page read or watched for long stretches (a reader, a player).
///
/// Beside a sidebar, the shell then hides the sidebar and the title row's
/// page content (Back, brand, page title, title-bar search and actions) and
/// lays the page out from the window's top-left corner, under the title row;
/// the page's top [MediaQuery] padding covers the row. The row keeps the
/// window buttons and drags the window everywhere else. When the page is
/// covered or leaves, the shell returns to its layout as it was, the sidebar's
/// expanded state included.
///
/// [titleRow] is the page's own top-bar controls. With the whole window they
/// sit in the title row and take clicks and hover while the rest of the row
/// drags; in layouts that give the page its content area instead (bottom bar,
/// phone) they sit at the top of the page.
class FrostShellWholeWindow extends StatefulWidget {
  const FrostShellWholeWindow({required this.child, this.titleRow, super.key});
  final Widget child;
  final Widget? titleRow;

  @override
  State<FrostShellWholeWindow> createState() => _FrostShellWholeWindowState();
}

class _FrostShellWholeWindowState extends State<FrostShellWholeWindow> {
  _WholeWindowClaims? _claims;

  /// Whether this page and every page holding its navigator inside the shell
  /// are current and on stage.
  bool _visible(BuildContext context, _WholeWindowClaims claims) {
    if (!TickerMode.valuesOf(context).enabled) return false;
    var route = ModalRoute.of(context);
    while (route != null) {
      final owner = route.navigator;
      if (owner == null || !identical(owner.context.getInheritedWidgetOfExactType<_WholeWindowScope>()?.claims, claims)) break;
      if (!route.isCurrent) return false;
      route = ModalRoute.of(owner.context);
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_WholeWindowScope>();
    final claims = scope?.claims;
    if (!identical(claims, _claims)) _claims?.release(this);
    _claims = claims;
    final granted = scope?.grants ?? false;
    if (claims != null && granted && _visible(context, claims)) {
      claims.claim(this, widget.titleRow);
    } else {
      claims?.release(this);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!granted && widget.titleRow != null) KeyedSubtree(key: const ValueKey('title-row'), child: widget.titleRow!),
        Expanded(key: const ValueKey('page'), child: widget.child),
      ],
    );
  }

  @override
  void dispose() {
    _claims?.release(this);
    super.dispose();
  }
}

/// The pages asking for the whole window; the last visible one wins.
class _WholeWindowClaims extends ChangeNotifier {
  final _claims = <(Object, Widget?)>[];
  bool _queued = false, _disposed = false;

  bool get active => _claims.isNotEmpty;
  Widget? get titleRow => _claims.lastOrNull?.$2;

  /// Called while the page builds; the shell hears after the frame.
  void claim(Object owner, Widget? titleRow) {
    final index = _claims.indexWhere((claim) => identical(claim.$1, owner));
    if (index >= 0) {
      if (identical(_claims[index].$2, titleRow)) return;
      _claims[index] = (owner, titleRow);
      if (index == _claims.length - 1) _notifyLater();
      return;
    }
    _claims.add((owner, titleRow));
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _queued = false;
      if (!_disposed) notifyListeners();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class _WholeWindowScope extends InheritedWidget {
  const _WholeWindowScope({required this.claims, required this.grants, required super.child});
  final _WholeWindowClaims claims;

  /// Whether the shell's layout gives a page the whole window (beside a
  /// sidebar).
  final bool grants;

  @override
  bool updateShouldNotify(_WholeWindowScope oldWidget) => !identical(claims, oldWidget.claims) || grants != oldWidget.grants;
}
