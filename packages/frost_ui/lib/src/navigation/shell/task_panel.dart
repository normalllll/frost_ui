part of 'shell.dart';

/// Content a [FrostShellTaskEntry] opens from its [FrostShellTaskButton]. In
/// bottom-bar layouts the button expands into a floating panel at its
/// position: [title] heads it and is the handle that drags it, beside a close
/// button. Where the panel does not fit, the content opens in a sheet with the
/// same title; in the sidebar, in a popover anchored to the entry.
@immutable
class FrostShellTaskPanel {
  const FrostShellTaskPanel({required this.title, required this.builder});

  final String title;

  /// Builds the panel's content from Frost components. The panel scrolls it
  /// when it is taller than the room above the bottom bar.
  final WidgetBuilder builder;
}

// Narrower than a popover, so a phone keeps room beside the panel to move it
// toward either edge; it yields to narrower windows.
const _floatingPanelMaxWidth = 320.0;

// Below this room, or at double text size, the panel opens as a sheet.
const _floatingPanelMinWidth = 300.0;
const _floatingPanelMinHeight = 320.0;
const _floatingPanelMaxTextScale = 2.0;

/// The floating panel a [FrostShellTaskButton] opens: it grows from the button,
/// moves by its title bar inside the band the button keeps to, and collapses
/// into the button again. A panel that was not moved puts the button back
/// where it was; a moved one rests the button by the panel's nearer side.
mixin _FloatingTaskPanelHost on State<_FloatingTaskLayer>, TickerProvider {
  // From the layer: the button's band, at the button's laid-out size.
  Rect get _band;
  Size get _layerSize;
  Size get _entrySize;
  bool get _ltr;
  double get _keyboardInset;
  Offset _current(Rect band);
  void _stopEntryMotion();

  late final AnimationController _reveal = AnimationController(vsync: this);
  final _entryFocus = FocusNode(debugLabel: 'Task entry');
  final _panelFocus = FocusScopeNode(debugLabel: 'Task panel');
  late final _back = _TaskPanelBack(handles: _handlesBack, onBack: _closePanel);
  bool _panelOpen = false, _sheetOpen = false;

  /// Whether the title bar moved the panel since it opened.
  bool _panelDragged = false;

  /// Whether the layer stepped aside last build; Back then belongs to what
  /// covers it.
  bool _layerHidden = false;

  /// Whether the route now over the shell's route was opened from the panel,
  /// which then stays up beneath it.
  bool _coverFromPanel = false;

  /// The route the layer is in, from the last build.
  ModalRoute<Object?>? _route;

  /// The panel's top-left where the user left it; null until it is placed
  /// beside the button. The keyboard only lifts it for as long as it is up.
  Offset? _panelAt;

  /// The top-left as last laid out, above the keyboard.
  Offset? _panelShownAt;
  Size _panelSize = Size.zero;

  bool get _panelShown => widget.entry.panel != null && (_panelOpen || _reveal.value > 0);

  bool _handlesBack() => _panelOpen && !_layerHidden && !widget.covered && (_route?.isCurrent ?? true);

  @override
  void initState() {
    super.initState();
    _panelFocus.addListener(_panelFocusChanged);
  }

  // A dialog or sheet the panel's content opens takes focus from the panel
  // right after its route covers the shell's route.
  void _panelFocusChanged() {
    if (!_panelFocus.hasFocus && _panelOpen && !_coverFromPanel && _route?.isCurrent == false) setState(() => _coverFromPanel = true);
  }

  /// The room the panel may cover: the button's band at full extent, above
  /// the keyboard unless [keyboard] is false.
  Rect _area({bool keyboard = true}) {
    final band = _band;
    var bottom = band.bottom + _entrySize.height;
    if (keyboard && _keyboardInset > 0) bottom = math.max(band.top, math.min(bottom, _layerSize.height - _keyboardInset - _floatingEntryMargin));
    return Rect.fromLTRB(band.left, band.top, band.right + _entrySize.width, bottom);
  }

  Rect get _panelArea => _area();

  bool get _panelFits {
    final area = _area(keyboard: false);
    final textScale = MediaQuery.textScalerOf(context).scale(16) / 16;
    return area.width >= _floatingPanelMinWidth && area.height >= _floatingPanelMinHeight && textScale < _floatingPanelMaxTextScale;
  }

  void _togglePanel() => _panelOpen ? _closePanel() : _openPanel();

  void _openPanel() {
    final panel = widget.entry.panel;
    if (panel == null || _sheetOpen) return;
    if (!_panelFits) {
      _openSheet(panel);
      return;
    }
    _stopEntryMotion();
    setState(() {
      _panelOpen = true;
      _panelDragged = false;
      _coverFromPanel = false;
      // Reopened while collapsing, it grows back from where it is.
      if (_reveal.value == 0) _panelAt = _panelShownAt = null;
    });
    _back.claim(context);
    FrostMotion.springTo(context, _reveal, 1, FrostMotion.standard);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _panelOpen) _panelFocus.requestFocus();
    });
  }

  /// The button's rest after the panel closes, or null to keep its place.
  FrostFloatingEntryPosition? _restOnClose() {
    final at = _panelShownAt;
    return _panelDragged && at != null ? _restFor(at & _panelSize) : null;
  }

  void _closePanel() {
    if (!_panelOpen) return;
    final returnFocus = _panelFocus.hasFocus;
    final rest = _restOnClose();
    setState(() {
      _panelOpen = false;
      _panelDragged = false;
      _coverFromPanel = false;
    });
    _back.release();
    if (rest != null) widget.onPositionChanged(rest);
    _collapse = FrostMotion.springTo(context, _reveal, 0, FrostMotion.standard)
      ..whenCompleteOrCancel(() {
        if (mounted && !_panelOpen) setState(() {});
      });
    if (returnFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_panelOpen) _entryFocus.requestFocus();
      });
    }
  }

  /// The collapse [_closePanel] started last.
  TickerFuture? _collapse;

  /// Closes the panel as a press outside does, for [closeFrostPanelThen]:
  /// true once it has collapsed, false when it was not open or reopened first.
  Future<bool> _closePanelForAction() async {
    if (!_panelOpen) return false;
    _closePanel();
    if (_collapse case final collapse?) {
      final settled = Completer<void>();
      collapse.whenCompleteOrCancel(settled.complete);
      await settled.future;
    }
    return mounted && !_panelOpen && _reveal.value == 0;
  }

  /// Closes the panel at once when it cannot stay: its entry hid or lost the
  /// panel (called while the layer updates), or the layer is going away, for
  /// example because the layout moved the entry into the sidebar. A move is
  /// reported after the frame. Focus in the panel goes back to the entry when
  /// the entry can take it, else to what had it before the panel.
  void _forceClosePanel({required bool disposing}) {
    if (!_panelOpen) return;
    final hadFocus = _panelFocus.hasFocus;
    final rest = _restOnClose();
    final report = widget.onPositionChanged;
    _panelOpen = false;
    _panelDragged = false;
    _coverFromPanel = false;
    _back.release();
    _reveal.value = 0;
    _panelAt = _panelShownAt = null;
    if (rest != null) WidgetsBinding.instance.addPostFrameCallback((_) => report(rest));
    if (!hadFocus) return;
    if (!disposing && widget.entry.visible) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_panelOpen) _entryFocus.requestFocus();
      });
    } else {
      _panelFocus.unfocus(disposition: UnfocusDisposition.previouslyFocusedChild);
    }
  }

  Future<void> _openSheet(FrostShellTaskPanel panel) async {
    _sheetOpen = true;
    try {
      await showFrostSheet<void>(context: context, title: panel.title, detents: const [FrostSheetDetent.fitted], builder: panel.builder);
    } finally {
      _sheetOpen = false;
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _entryFocus.requestFocus();
        });
      }
    }
  }

  void _disposePanel() {
    _forceClosePanel(disposing: true);
    _panelFocus.removeListener(_panelFocusChanged);
    _back.dispose();
    _reveal.dispose();
    _entryFocus.dispose();
    _panelFocus.dispose();
  }

  /// Where the button rests after a moved panel closes: the inverse of
  /// [_placePanel], so opening there and closing again keeps the place. The
  /// button takes the panel's nearer side and the corner the panel grows from.
  FrostFloatingEntryPosition _restFor(Rect panel) {
    final band = _band;
    final area = _area(keyboard: false);
    final right = panel.center.dx > area.center.dx;
    final top = panel.center.dy > area.center.dy ? panel.bottom - _entrySize.height : panel.top;
    return FrostFloatingEntryPosition(
      edge: right == _ltr ? FrostFloatingEntryEdge.end : FrostFloatingEntryEdge.start,
      fraction: band.height <= 0 ? widget.position.fraction : ((top - band.top) / band.height).clamp(0.0, 1.0),
    );
  }

  Offset _clampPanel(Offset at, {bool keyboard = true}) {
    final area = _area(keyboard: keyboard);
    return Offset(
      at.dx.clamp(area.left, math.max(area.left, area.right - _panelSize.width)),
      at.dy.clamp(area.top, math.max(area.top, area.bottom - _panelSize.height)),
    );
  }

  /// Places the panel; called while the layer lays out. It opens over the
  /// button, aligned with the button's corner nearest the middle of the band.
  Offset _placePanel(Size panel) {
    _panelSize = panel;
    var at = _panelAt;
    if (at == null) {
      final area = _area(keyboard: false);
      final button = _current(_band) & _entrySize;
      at = Offset(
        button.center.dx > area.center.dx ? button.right - panel.width : button.left,
        button.center.dy > area.center.dy ? button.bottom - panel.height : button.top,
      );
    }
    _panelAt = _clampPanel(at, keyboard: false);
    return _panelShownAt = _clampPanel(_panelAt!);
  }

  void _movePanel(Offset delta) {
    final desired = _panelAt;
    if (desired == null || !_panelOpen) return;
    // From the place last set, not last laid out: moves arrive between layouts.
    final at = _clampPanel(desired);
    final next = _clampPanel(at + delta);
    if (next == at) return;
    setState(() {
      _panelAt = next;
      _panelDragged = true;
    });
  }

  /// Maps the panel onto the button's rect at 0 and onto itself at 1.
  Matrix4 _growTransform(double t) {
    final at = _panelShownAt;
    if (t >= 1 || at == null || _panelSize.isEmpty) return Matrix4.identity();
    final panel = at & _panelSize;
    final rect = Rect.lerp(_current(_band) & _entrySize, panel, t)!;
    return Matrix4.diagonal3Values(rect.width / panel.width, rect.height / panel.height, 1)..setTranslationRaw(rect.left - panel.left, rect.top - panel.top, 0);
  }

  /// The panel over the layer and, while it is open, the area around it that
  /// closes it on a press. The press still reaches the page; menus and
  /// tooltips the panel opens sit in the Overlay above both.
  List<Widget> _panelLayers() {
    final panel = widget.entry.panel;
    if (panel == null || !_panelShown) return const [];
    return [
      if (_panelOpen)
        Positioned.fill(
          key: const ValueKey('frost-shell-task-panel-outside'),
          child: Listener(behavior: HitTestBehavior.translucent, onPointerDown: (_) => _closePanel()),
        ),
      CustomSingleChildLayout(
        key: const ValueKey('frost-shell-task-panel'),
        delegate: _FloatingPanelLayout(this),
        child: IgnorePointer(
          ignoring: !_panelOpen,
          child: ExcludeFocus(
            excluding: !_panelOpen,
            child: ExcludeSemantics(
              excluding: !_panelOpen,
              child: AnimatedBuilder(
                animation: _reveal,
                builder: (context, child) => FrostMaterialReveal(
                  opacity: _reveal.value,
                  child: Transform(transform: _growTransform(_reveal.value), child: child),
                ),
                child: FrostPanelActionScope(
                  origin: context,
                  close: _closePanelForAction,
                  child: _FloatingTaskPanel(panel: panel, focusNode: _panelFocus, onClose: _closePanel, onDrag: _movePanel),
                ),
              ),
            ),
          ),
        ),
      ),
    ];
  }

  /// Hides the button while the panel stands in for it.
  Widget _entryWhilePanel(Widget button) => AnimatedBuilder(
    animation: _reveal,
    builder: (context, child) => Opacity(opacity: 1 - _reveal.value, child: child),
    child: IgnorePointer(
      ignoring: _panelOpen,
      child: ExcludeFocus(
        excluding: _panelOpen,
        child: ExcludeSemantics(excluding: _panelOpen, child: button),
      ),
    ),
  );
}

class _FloatingPanelLayout extends SingleChildLayoutDelegate {
  _FloatingPanelLayout(this.host);
  final _FloatingTaskPanelHost host;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final area = host._panelArea;
    return BoxConstraints(maxWidth: math.max(0, math.min(_floatingPanelMaxWidth, area.width)), maxHeight: math.max(0, area.height));
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) => host._placePanel(childSize);

  // Drags rebuild the layer with a new delegate.
  @override
  bool shouldRelayout(_FloatingPanelLayout oldDelegate) => true;
}

/// The panel's material: a title bar that drags it and closes it, above the
/// app's content.
class _FloatingTaskPanel extends StatelessWidget {
  const _FloatingTaskPanel({required this.panel, required this.focusNode, required this.onClose, required this.onDrag});
  final FrostShellTaskPanel panel;
  final FocusScopeNode focusNode;
  final VoidCallback onClose;
  final ValueChanged<Offset> onDrag;

  @override
  Widget build(BuildContext context) => Shortcuts(
    shortcuts: const {SingleActivator(LogicalKeyboardKey.escape): DismissIntent()},
    child: Actions(
      actions: {
        DismissIntent: CallbackAction<DismissIntent>(
          onInvoke: (_) {
            onClose();
            return null;
          },
        ),
      },
      child: FocusScope(
        node: focusNode,
        child: Semantics(
          container: true,
          explicitChildNodes: true,
          child: FrostControlScope(
            size: FrostControlSize.regular,
            toolbar: false,
            enabled: true,
            child: FrostSurface(
              role: FrostSurfaceRole.overlay,
              borderRadius: FrostRadius.borderRadius(FrostRadius.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GestureDetector(
                    key: const ValueKey('frost-shell-task-panel-title'),
                    behavior: HitTestBehavior.opaque,
                    dragStartBehavior: DragStartBehavior.down,
                    onPanUpdate: (details) => onDrag(details.delta),
                    child: Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(frostPopoverContentInset, FrostGap.related, FrostGap.related, FrostGap.related),
                      child: Row(
                        children: [
                          Expanded(
                            child: FrostText(panel.title, role: FrostTextRole.headline, maxLines: 2, overflow: TextOverflow.ellipsis),
                          ),
                          const SizedBox(width: FrostGap.related),
                          FrostButton.icon(
                            icon: FrostIconSet.of(context).close,
                            label: FrostScope.labelsOf(context).close,
                            size: FrostControlSize.compact,
                            onPressed: onClose,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      primary: false,
                      padding: const EdgeInsets.fromLTRB(frostPopoverContentInset, 0, frostPopoverContentInset, frostPopoverContentInset),
                      child: Builder(builder: panel.builder),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// System Back closes the open panel and reaches nothing else, whichever
/// Navigator or Router the app nests the shell in. A Router asks its
/// back-button dispatcher's children before its delegate, which would pop the
/// innermost Navigator, so the panel takes priority there. Without a Router,
/// the app asks its root Navigator, and every route that encloses the shell
/// asks its scoped will-pop callbacks first; refusing there ends the pop
/// before any PopScope hears of it. The pop entry tells Android that the
/// framework handles Back while the panel is open.
class _TaskPanelBack extends PopEntry<Object?> {
  _TaskPanelBack({required this.handles, required this.onBack});
  final bool Function() handles;
  final VoidCallback onBack;

  @override
  final ValueNotifier<bool> canPopNotifier = ValueNotifier(true);

  @override
  void onPopInvokedWithResult(bool didPop, Object? result) {}

  ModalRoute<Object?>? _registered;
  final _claimed = <ModalRoute<Object?>>[];
  ChildBackButtonDispatcher? _dispatcher;

  Future<bool> _willPop() async {
    if (!handles()) return true;
    onBack();
    return false;
  }

  Future<bool> _routerBack() async {
    if (!handles()) return false;
    onBack();
    return true;
  }

  void claim(BuildContext context) {
    release();
    final parent = Router.maybeOf(context)?.backButtonDispatcher;
    if (parent != null) {
      _dispatcher = ChildBackButtonDispatcher(parent)
        ..addCallback(_routerBack)
        ..takePriority();
    }
    BuildContext? at = context;
    while (at != null && at.mounted) {
      final route = ModalRoute.of(at);
      if (route == null) break;
      // ignore: deprecated_member_use
      route.addScopedWillPopCallback(_willPop);
      _claimed.add(route);
      at = route.navigator?.context;
    }
    if (_claimed.isEmpty) return;
    // The entry stays with its route and only changes its answer: a route
    // walks its entries to notify them, so one cannot leave meanwhile.
    final outermost = _claimed.last;
    if (!identical(_registered, outermost)) {
      _unregister();
      _registered = outermost;
      outermost.registerPopEntry(this);
    }
    canPopNotifier.value = false;
  }

  void release() {
    canPopNotifier.value = true;
    _dispatcher?.removeCallback(_routerBack);
    _dispatcher = null;
    for (final route in _claimed) {
      // ignore: deprecated_member_use
      if (route.isActive && route.subtreeContext != null) route.removeScopedWillPopCallback(_willPop);
    }
    _claimed.clear();
  }

  void _unregister() {
    final route = _registered;
    _registered = null;
    if (route != null && route.isActive) route.unregisterPopEntry(this);
  }

  void dispose() {
    release();
    _unregister();
    canPopNotifier.dispose();
  }
}
