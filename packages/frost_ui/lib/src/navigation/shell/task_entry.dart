part of 'shell.dart';

/// Where a [FrostShellTaskEntry] is rendered.
enum FrostShellTaskEntryPlacement {
  /// The bottom of the sidebar, below the destinations.
  sidebar,

  /// A draggable button over the content in bottom-bar layouts.
  floating,
}

/// The side a floating task entry rests on, in reading direction.
enum FrostFloatingEntryEdge { start, end }

/// Where the floating task entry rests: the edge it snapped to, and how far
/// down the band between the page header and the bottom bar it sits.
@immutable
class FrostFloatingEntryPosition {
  const FrostFloatingEntryPosition({this.edge = FrostFloatingEntryEdge.end, this.fraction = 1.0}) : assert(fraction >= 0 && fraction <= 1);

  final FrostFloatingEntryEdge edge;

  /// 0 is the top of the allowed band, 1 the bottom.
  final double fraction;

  @override
  bool operator ==(Object other) => other is FrostFloatingEntryPosition && other.edge == edge && other.fraction == fraction;

  @override
  int get hashCode => Object.hash(edge, fraction);

  @override
  String toString() => 'FrostFloatingEntryPosition($edge, $fraction)';
}

/// A persistent app entry (for example downloads) the shell keeps on screen:
/// at the bottom of the sidebar, or as a draggable button above the content
/// in bottom-bar layouts. The app builds the widget, usually a
/// [FrostShellTaskButton], and may anchor a popover or a key on it, or give
/// the entry a [panel] the button opens.
@immutable
class FrostShellTaskEntry {
  const FrostShellTaskEntry({
    required this.builder,
    this.visible = true,
    this.initialFloatingPosition = const FrostFloatingEntryPosition(),
    this.onFloatingPositionChanged,
    this.panel,
  });

  final Widget Function(BuildContext context, FrostShellTaskEntryPlacement placement) builder;

  /// Hides the entry, for example on immersive pages. A bottom-aligned sidebar
  /// keeps the entry's room so the destinations above it do not move.
  final bool visible;

  /// Where the floating entry starts. Read once; the shell then keeps the
  /// position for the run and reports changes through
  /// [onFloatingPositionChanged].
  final FrostFloatingEntryPosition initialFloatingPosition;

  /// Called after the user drags the floating entry and it snaps to an edge.
  final ValueChanged<FrostFloatingEntryPosition>? onFloatingPositionChanged;

  /// Content a [FrostShellTaskButton] without its own `onPressed` opens. In
  /// bottom-bar layouts the button expands into a draggable floating panel at
  /// its position, or a sheet where the panel does not fit; in the sidebar the
  /// content opens in a popover anchored to the entry.
  final FrostShellTaskPanel? panel;
}

// Tells a FrostShellTaskButton how the shell placed it.
class _TaskEntryScope extends InheritedWidget {
  const _TaskEntryScope({required this.placement, this.progress = 0, this.panel, this.onTogglePanel, this.focusNode, required super.child});
  final FrostShellTaskEntryPlacement placement;

  /// The sidebar's expand progress.
  final double progress;

  /// The entry's panel, which a button without its own action opens.
  final FrostShellTaskPanel? panel;

  /// Opens or closes the floating panel.
  final VoidCallback? onTogglePanel;

  /// The floating button's focus, which the panel returns to on close.
  final FocusNode? focusNode;

  static _TaskEntryScope? maybeOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<_TaskEntryScope>();

  @override
  bool updateShouldNotify(_TaskEntryScope oldWidget) =>
      placement != oldWidget.placement ||
      progress != oldWidget.progress ||
      panel != oldWidget.panel ||
      onTogglePanel != oldWidget.onTogglePanel ||
      focusNode != oldWidget.focusNode;
}

/// Ready-made task entry button for [FrostShellTaskEntry.builder]. In the
/// sidebar it is an unselected destination row; floating, a raised round
/// button. Both show the count and progress the way destinations do. Without
/// [onPressed] it opens the entry's [FrostShellTaskEntry.panel], and it is
/// disabled when the entry has none.
class FrostShellTaskButton extends StatelessWidget {
  const FrostShellTaskButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.badge = 0,
    this.badgeTone = FrostCountBadgeTone.accent,
    this.progress,
    super.key,
  }) : assert(progress == null || (progress >= 0 && progress <= 1));

  final FrostIconData icon;
  final String label;
  final VoidCallback? onPressed;

  /// See [FrostNavDestination.badge].
  final int badge;

  /// See [FrostNavDestination.badgeTone].
  final FrostCountBadgeTone badgeTone;

  /// See [FrostNavDestination.progress].
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final scope = _TaskEntryScope.maybeOf(context);
    final panel = onPressed == null ? scope?.panel : null;
    final Widget child;
    if (scope?.placement == FrostShellTaskEntryPlacement.floating) {
      child = _FloatingTaskButton(icon: icon, label: label, onPressed: onPressed ?? (panel == null ? null : scope?.onTogglePanel), focusNode: scope?.focusNode);
    } else if (panel != null) {
      // The popover's trigger focus wraps the row, so focus returns to it.
      child = FrostPopover(
        title: panel.title,
        builder: (context, focusNode, toggle) => Focus(
          focusNode: focusNode,
          child: FrostNavItem(label: label, icon: icon, selected: false, progress: scope?.progress ?? 0, onTap: toggle),
        ),
        contentBuilder: (context, close) => Builder(builder: panel.builder),
      );
    } else {
      child = FrostNavItem(label: label, icon: icon, selected: false, progress: scope?.progress ?? 0, onTap: onPressed);
    }
    return Semantics(
      container: true,
      child: FrostDestinationStatus(badge: badge, badgeTone: badgeTone, progress: progress, child: child),
    );
  }
}

/// The sidebar's task entry slot. A hidden entry keeps its State. A
/// bottom-aligned sidebar also keeps its room, so destinations never move when
/// it shows or hides; a top-aligned one gives the room back.
class _SidebarTaskSlot extends StatelessWidget {
  const _SidebarTaskSlot({required this.entry, required this.progress, required this.reservesRoom, required this.gapBelow});
  final FrostShellTaskEntry entry;
  final double progress;
  final bool reservesRoom;

  /// Whether the tabs overview follows, a destination gap below.
  final bool gapBelow;

  @override
  Widget build(BuildContext context) => Visibility(
    visible: entry.visible,
    maintainSize: reservesRoom,
    maintainAnimation: true,
    maintainState: true,
    child: Padding(
      padding: EdgeInsets.fromLTRB(_SidebarNavigation._innerPadding, 0, _SidebarNavigation._innerPadding, gapBelow ? 6 : 0),
      child: _TaskEntryScope(
        placement: FrostShellTaskEntryPlacement.sidebar,
        progress: progress,
        panel: entry.panel,
        child: Builder(builder: (context) => entry.builder(context, FrostShellTaskEntryPlacement.sidebar)),
      ),
    ),
  );
}

const _floatingEntrySize = 48.0;
const _floatingEntryIconSize = 24.0;

// Room kept between the floating entry and the edges, the header and the bar.
const _floatingEntryMargin = 16.0;
const _floatingEntryRingWidth = 2.0;

/// The raised round form of [FrostShellTaskButton].
class _FloatingTaskButton extends StatelessWidget {
  const _FloatingTaskButton({required this.icon, required this.label, required this.onPressed, this.focusNode});
  final FrostIconData icon;
  final String label;
  final VoidCallback? onPressed;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final tokens = FrostThemeTokens.of(context);
    final progress = FrostDestinationStatus.of(context)?.progress;
    final Widget button = Semantics(
      button: true,
      enabled: onPressed != null,
      label: FrostDestinationStatus.labelOf(context, label),
      onTap: onPressed,
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: _floatingEntrySize,
        child: FrostSurface(
          role: FrostSurfaceRole.overlay,
          borderRadius: BorderRadius.circular(_floatingEntrySize / 2),
          child: FrostClickSurface(
            onTap: onPressed,
            focusNode: focusNode,
            shape: const FrostClickShape.circle(),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (progress != null)
                  CustomPaint(
                    painter: _FloatingProgressPainter(progress: progress, color: tokens.accent, track: tokens.separator),
                  ),
                Center(
                  child: FrostDestinationStatus.decorateIcon(context, FrostIcon(icon, size: _floatingEntryIconSize, color: tokens.textPrimary)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return onPressed == null ? ExcludeFocus(child: Opacity(opacity: .38, child: button)) : button;
  }
}

class _FloatingProgressPainter extends CustomPainter {
  const _FloatingProgressPainter({required this.progress, required this.color, required this.track});
  final double progress;
  final Color color, track;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(_floatingEntryRingWidth / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _floatingEntryRingWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, 2 * math.pi, false, paint..color = track);
    if (progress > 0) canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * progress.clamp(0.0, 1.0), false, paint..color = color);
  }

  @override
  bool shouldRepaint(_FloatingProgressPainter oldDelegate) => progress != oldDelegate.progress || color != oldDelegate.color || track != oldDelegate.track;
}

/// The bottom bar's latest laid-out height, safe area included. The bar
/// reports it while it lays out, and keeps its last height while a pushed
/// route covers it.
class _BarExtent extends ChangeNotifier {
  double? _value;
  bool _queued = false, _disposed = false;
  double? get value => _value;

  void _report(double value) {
    if (value == _value) return;
    _value = value;
    if (_queued) return;
    _queued = true;
    // Layout cannot rebuild listeners; they hear of a change after the frame.
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

/// The draggable task entry over the content in bottom-bar layouts. It stays
/// between the page header and the bottom bar, and snaps to the nearer side.
class _FloatingTaskLayer extends StatefulWidget {
  const _FloatingTaskLayer({
    required this.entry,
    required this.position,
    required this.barExtent,
    required this.onPositionChanged,
    this.covered = false,
    super.key,
  });
  final FrostShellTaskEntry entry;
  final FrostFloatingEntryPosition position;
  final _BarExtent barExtent;
  final ValueChanged<FrostFloatingEntryPosition> onPositionChanged;

  /// Whether a popup route is open in the content Navigator.
  final bool covered;

  @override
  State<_FloatingTaskLayer> createState() => _FloatingTaskLayerState();
}

class _FloatingTaskLayerState extends State<_FloatingTaskLayer> with TickerProviderStateMixin, _FloatingTaskPanelHost {
  late final AnimationController _snap = AnimationController(vsync: this);

  /// The entry's top-left while a finger moves it.
  Offset? _drag;

  /// Where the snap started; null once it lands.
  Offset? _snapFrom;

  // What the band depends on, from the last build.
  EdgeInsets _padding = EdgeInsets.zero;
  double _header = 0;
  @override
  bool _ltr = true;

  // The layer and the entry as last laid out.
  @override
  Size _layerSize = Size.zero;
  @override
  double _keyboardInset = 0;
  @override
  Size _entrySize = const Size.square(_floatingEntrySize);

  /// No bar reported a height by the end of the first frame: the band uses the
  /// bar's minimum height instead.
  bool _barMissing = false;

  @override
  void initState() {
    super.initState();
    widget.barExtent.addListener(_rebuild);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.barExtent.value == null) setState(() => _barMissing = true);
    });
  }

  @override
  void didUpdateWidget(_FloatingTaskLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.barExtent != widget.barExtent) {
      oldWidget.barExtent.removeListener(_rebuild);
      widget.barExtent.addListener(_rebuild);
    }
    if (widget.entry.panel == null || !widget.entry.visible) _forceClosePanel(disposing: false);
  }

  @override
  void dispose() {
    widget.barExtent.removeListener(_rebuild);
    _snap.dispose();
    _disposePanel();
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  /// The top-left positions the entry may take at its laid-out size: below
  /// the page header and above the bottom bar, inside the side safe insets.
  @override
  Rect get _band {
    final barTop = _layerSize.height - (widget.barExtent.value ?? _mobileNavigationMinHeight + _padding.bottom);
    final left = _padding.left + _floatingEntryMargin;
    final top = _padding.top + _header + _floatingEntryMargin;
    final right = math.max(left, _layerSize.width - _padding.right - _floatingEntryMargin - _entrySize.width);
    final bottom = math.max(top, barTop - _floatingEntryMargin - _entrySize.height);
    return Rect.fromLTRB(left, top, right, bottom);
  }

  Offset _rest(Rect band, FrostFloatingEntryPosition position) =>
      Offset((position.edge == FrostFloatingEntryEdge.start) == _ltr ? band.left : band.right, band.top + position.fraction * band.height);

  @override
  Offset _current(Rect band) {
    if (_drag case final drag?) return drag;
    final rest = _rest(band, widget.position);
    if (_snapFrom case final from?) return Offset.lerp(from, rest, _snap.value)!;
    return rest;
  }

  /// Places the entry; called while the layer lays out.
  Offset _place(Size layer, Size entry) {
    _layerSize = layer;
    _entrySize = entry;
    return _current(_band);
  }

  void _start() {
    final current = _current(_band);
    _snap.stop();
    setState(() {
      _drag = current;
      _snapFrom = null;
    });
  }

  void _move(Offset delta) {
    final drag = _drag;
    if (drag == null) return;
    final band = _band;
    final next = drag + delta;
    setState(() => _drag = Offset(next.dx.clamp(band.left, band.right), next.dy.clamp(band.top, band.bottom)));
  }

  void _end() {
    final drag = _drag;
    if (drag == null) return;
    final band = _band;
    final left = drag.dx < (band.left + band.right) / 2;
    final position = FrostFloatingEntryPosition(
      edge: left == _ltr ? FrostFloatingEntryEdge.start : FrostFloatingEntryEdge.end,
      fraction: band.height <= 0 ? widget.position.fraction : ((drag.dy - band.top) / band.height).clamp(0.0, 1.0),
    );
    setState(() {
      _drag = null;
      _snapFrom = drag;
    });
    _snap.value = 0;
    FrostMotion.springTo(context, _snap, 1, FrostMotion.standard).whenCompleteOrCancel(() {
      if (mounted && _drag == null && !_snap.isAnimating) setState(() => _snapFrom = null);
    });
    widget.onPositionChanged(position);
  }

  @override
  Widget build(BuildContext context) {
    _padding = MediaQuery.paddingOf(context);
    _header = FrostSizeClass.of(context) != FrostSizeClass.compact ? FrostPageHeader.horizontalHeight : FrostPageHeader.verticalHeight;
    _ltr = Directionality.of(context) == TextDirection.ltr;
    // Sheets and dialogs cover the shell route (root Navigator) or sit on the
    // content Navigator; the entry steps aside for either and returns after.
    // An open panel stays up under a route its own content opened, and above
    // the keyboard of a field inside it.
    _route = ModalRoute.of(context);
    final current = _route?.isCurrent ?? true;
    // Focus still in the panel as its route is covered: the panel opened it.
    if (current) {
      _coverFromPanel = false;
    } else if (_panelOpen && _panelFocus.hasFocus) {
      _coverFromPanel = true;
    }
    _keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final keyboard = _keyboardInset > 0 && !(_panelOpen && _panelFocus.hasFocus);
    final hidden = !widget.entry.visible || keyboard || widget.covered || (!current && !(_panelOpen && _coverFromPanel));
    _layerHidden = hidden;
    // Hiding cancels a drag: nothing is committed and the entry stays at rest.
    if (hidden) _drag = null;
    // Until the bar reports its height the band is a guess; show nothing
    // rather than a jump.
    final ready = widget.barExtent.value != null || _barMissing;
    return IgnorePointer(
      ignoring: hidden || !ready,
      child: ExcludeSemantics(
        excluding: hidden || !ready,
        child: ExcludeFocus(
          excluding: hidden || !ready,
          child: Opacity(
            key: const ValueKey('frost-shell-floating-ready'),
            opacity: ready ? 1 : 0,
            child: AnimatedOpacity(
              opacity: hidden ? 0 : 1,
              duration: FrostMotion.duration(context, hidden ? FrostMotion.dismiss : FrostMotion.reveal),
              curve: hidden ? Curves.easeInCubic : Curves.easeOutCubic,
              // Only its children take hits: the page stays reachable around them.
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CustomSingleChildLayout(
                    key: const ValueKey('frost-shell-task-entry'),
                    delegate: _FloatingEntryLayout(this),
                    child: _entryWhilePanel(
                      GestureDetector(
                        // The entry follows the finger from where it went down.
                        dragStartBehavior: DragStartBehavior.down,
                        onPanStart: (_) => _start(),
                        onPanUpdate: (details) => _move(details.delta),
                        onPanEnd: (_) => _end(),
                        onPanCancel: () => setState(() => _drag = null),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minWidth: _floatingEntrySize, minHeight: _floatingEntrySize),
                          child: _TaskEntryScope(
                            placement: FrostShellTaskEntryPlacement.floating,
                            panel: widget.entry.panel,
                            onTogglePanel: _togglePanel,
                            focusNode: _entryFocus,
                            child: Builder(builder: (context) => widget.entry.builder(context, FrostShellTaskEntryPlacement.floating)),
                          ),
                        ),
                      ),
                    ),
                  ),
                  ..._panelLayers(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void _stopEntryMotion() {
    _snap.stop();
    _drag = null;
    _snapFrom = null;
  }
}

class _FloatingEntryLayout extends SingleChildLayoutDelegate {
  _FloatingEntryLayout(this.layer) : super(relayout: layer._snap);
  final _FloatingTaskLayerState layer;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) => constraints.loosen();

  @override
  Offset getPositionForChild(Size size, Size childSize) => layer._place(size, childSize);

  // Drag and position changes rebuild the layer with a new delegate.
  @override
  bool shouldRelayout(_FloatingEntryLayout oldDelegate) => true;
}
