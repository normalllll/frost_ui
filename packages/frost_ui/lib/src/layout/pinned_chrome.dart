import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

import '../foundation/metrics.dart';
import '../foundation/tokens.dart';
import '../motion/_material_reveal.dart';
import '../primitives/_page_outline.dart';
import '../primitives/surface.dart';
import '_chrome_scroll_away.dart';
import '_header_search_body.dart';
import 'chrome_active_body.dart';

part 'pinned_chrome_glass.dart';

/// A bar pinned over the top of a scrolling body. The body scrolls beneath
/// the bar, and the bar's glass material appears once content is actually
/// underneath it, so a page at rest keeps one continuous backdrop.
///
/// The body receives the bar's height as its top [MediaQuery] padding, which
/// insets the scrollbar; scroll views add [FrostChromeSpacer] as their first
/// sliver so the first item starts below the bar.
///
/// System top and horizontal safe areas surround chrome, without changing its
/// own height. Chrome descendants receive consumed MediaQuery padding. Nested
/// pinned bars do not mistake the body's reserved bar height for a system inset.
///
/// Scrolling over the bar scrolls the list beneath it: wheel and drag input
/// that no control in the bar takes goes to the vertical scroll view under
/// the pointer.
///
/// Chrome with two pinned rows, such as a page header above section tabs that
/// did not fit in its row, can let its top row slide away while the body
/// scrolls on and return when it scrolls back. The body keeps the full
/// reserved height, so its scroll position, spacer and refresh header do not
/// move; content shows through where the row was.
///
/// On narrow windows a suggesting search field in the chrome's page header
/// lists its suggestions over the body: the body stays laid out underneath,
/// hidden, and comes back as it was when the suggestions close.
class FrostPinnedChrome extends StatefulWidget {
  const FrostPinnedChrome({required this.chrome, required this.body, this.extent, super.key});

  /// Fixed height of the bar, including any top safe area it covers. When
  /// null the bar is measured during layout before the body is laid out.
  final double? extent;

  final Widget chrome;
  final Widget body;

  @override
  State<FrostPinnedChrome> createState() => _FpPinnedChromeState();
}

class _FpPinnedChromeState extends State<FrostPinnedChrome> with SingleTickerProviderStateMixin {
  /// How much of the glass is showing: it follows the first [_revealDistance]
  /// of scrolling, so the bar stops wherever the finger stops instead of
  /// snapping in at a threshold.
  double _coverage = 0;

  /// The chrome's top row that slides away by scroll direction, if it has one.
  late final _hidden = AnimationController(vsync: this);
  late final _away = FrostChromeScrollAway(_hidden)..addListener(_awayChanged);
  final _search = FrostHeaderSearchBody();
  late final _awayMotion = Listenable.merge([_hidden, _away, _search]);
  bool _hideTarget = false;

  /// Scrolling in one direction this far makes the top row follow, so a
  /// jitter or a slow drag does not make it flicker.
  static const _awayTravel = 16.0;
  double _travelled = 0;

  final _bodyKey = GlobalKey();

  /// Vertical scroll views in the body, gathered from their metrics
  /// notifications; input over the bar goes to the one under the pointer.
  final _scrollables = <ScrollableState>{};
  Drag? _drag;
  ScrollMetrics? _pendingMetrics;
  bool _coverageUpdateScheduled = false;

  static const _revealDistance = 24.0;

  bool _handleMetrics(ScrollMetricsNotification notification) {
    _track(notification.context);
    if (!FrostChromeActiveBody.isActive(notification.context)) return false;
    _refreshCoverage(notification.metrics);
    // A list that appears or changes near its top (another section's list,
    // say) cannot fill the place of the row, so the row returns.
    final metrics = notification.metrics;
    if (metrics.axis == Axis.vertical && metrics.extentBefore < _away.extent) _setHidden(false);
    return false;
  }

  void _awayChanged() {
    if (_away.extent <= 0) {
      // Nothing slides away any more (the rows merged): restore at once.
      _hideTarget = false;
      _travelled = 0;
      _hidden.value = 0;
    } else if (_away.held) {
      _setHidden(false);
    }
  }

  void _followDirection(ScrollNotification notification) {
    final metrics = notification.metrics;
    final away = _away.extent;
    if (away <= 0 || metrics.axis != Axis.vertical || notification is! ScrollUpdateNotification) return;
    final delta = notification.scrollDelta ?? 0;
    if (metrics.extentBefore <= 0 || _away.held) {
      _travelled = 0;
      _setHidden(false);
      return;
    }
    // A change of direction starts the count again.
    _travelled = (_travelled.sign == delta.sign ? _travelled : 0) + delta;
    if (_travelled <= -_awayTravel) {
      _setHidden(false);
    } else if (_travelled >= _awayTravel && metrics.extentBefore >= away) {
      // Only once content can fill the row's place; nearer the top the row
      // would leave an empty band above the first item.
      _setHidden(true);
    }
  }

  void _setHidden(bool hidden) {
    if (_hideTarget == hidden) return;
    _hideTarget = hidden;
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      // A metrics change inside layout: move the row once the frame ends.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _hideTarget == hidden) FrostMotion.springTo(context, _hidden, hidden ? 1 : 0, FrostMotion.standard);
      });
      return;
    }
    FrostMotion.springTo(context, _hidden, hidden ? 1 : 0, FrostMotion.standard);
  }

  void _track(BuildContext? context) {
    final scrollable = context?.findAncestorStateOfType<ScrollableState>();
    if (scrollable != null && scrollable.position.axis == Axis.vertical) _scrollables.add(scrollable);
  }

  /// The deepest visible vertical scroll view in the body at [global].
  ScrollPosition? _scrollTargetAt(Offset global) {
    final body = _bodyKey.currentContext?.findRenderObject();
    if (body is! RenderBox || !body.hasSize) return null;
    final result = BoxHitTestResult();
    if (!body.hitTest(result, position: body.globalToLocal(global))) return null;
    final depth = <HitTestTarget, int>{};
    for (final (index, entry) in result.path.indexed) {
      depth.putIfAbsent(entry.target, () => index);
    }
    _scrollables.removeWhere((scrollable) => !scrollable.mounted);
    ScrollableState? target;
    var targetDepth = result.path.length;
    for (final scrollable in _scrollables) {
      final index = depth[scrollable.context.findRenderObject()];
      if (index != null && index < targetDepth && scrollable.position.axis == Axis.vertical) {
        target = scrollable;
        targetDepth = index;
      }
    }
    return target?.position;
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    final position = _scrollTargetAt(event.position);
    if (position == null || !position.hasPixels) return;
    final delta = axisDirectionIsReversed(position.axisDirection) ? -event.scrollDelta.dy : event.scrollDelta.dy;
    final target = (position.pixels + delta).clamp(position.minScrollExtent, position.maxScrollExtent);
    if (delta == 0 || target == position.pixels) return;
    // A control in the bar that scrolls registered first and keeps the event.
    GestureBinding.instance.pointerSignalResolver.register(event, (_) => position.pointerScroll(delta));
  }

  void _handleDragStart(DragStartDetails details) {
    final position = _scrollTargetAt(details.globalPosition);
    if (position == null) return;
    _drag = position.drag(details, () => _drag = null);
  }

  @override
  void dispose() {
    _drag?.cancel();
    _away.dispose();
    _hidden.dispose();
    _search.dispose();
    super.dispose();
  }

  bool _handleScroll(ScrollNotification notification) {
    _track(notification.context);
    // A section kept off screen scrolls (or settles) without moving the bar.
    if (!FrostChromeActiveBody.isActive(notification.context)) return false;
    _refreshCoverage(notification.metrics);
    _followDirection(notification);
    return false;
  }

  void _refreshCoverage(ScrollMetrics metrics) {
    if (metrics.axis != Axis.vertical) return;
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      // Restoring a scrolled pane or changing its content can start/end a
      // ballistic activity inside applyContentDimensions. Do not interrupt that
      // layout with setState: only the paint-only glass coverage needs updating.
      _pendingMetrics = metrics;
      if (!_coverageUpdateScheduled) {
        _coverageUpdateScheduled = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _coverageUpdateScheduled = false;
          final pending = _pendingMetrics;
          _pendingMetrics = null;
          if (mounted && pending != null) _applyCoverage(pending);
        });
      }
      return;
    }
    // A newer input/metrics event supersedes any queued layout notification.
    _pendingMetrics = null;
    _applyCoverage(metrics);
  }

  /// Another body came on screen. It may be at rest, so no scrolling reports
  /// its position: the glass and the sliding row take it from there.
  bool _handleBodyActivated(FrostChromeBodyActivated notification) {
    _pendingMetrics = null;
    _travelled = 0;
    _applyCoverage(null);
    _scrollables.removeWhere((scrollable) => !scrollable.mounted);
    final near = _scrollables.where((scrollable) => FrostChromeActiveBody.isActive(scrollable.context) && scrollable.position.hasContentDimensions);
    if (near.isEmpty || near.any((scrollable) => scrollable.position.extentBefore < _away.extent)) _setHidden(false);
    return true;
  }

  void _applyCoverage(ScrollMetrics? metrics) {
    _scrollables.removeWhere((scrollable) => !scrollable.mounted);
    // Independently scrolling panes share one band. A pane returning to zero
    // must not hide glass while another pane still has content under the bar.
    var coverage = metrics == null ? 0.0 : (metrics.extentBefore / _revealDistance).clamp(0.0, 1.0);
    for (final scrollable in _scrollables) {
      final position = scrollable.position;
      if (position.hasContentDimensions && FrostChromeActiveBody.isActive(scrollable.context)) {
        final amount = (position.extentBefore / _revealDistance).clamp(0.0, 1.0);
        if (amount > coverage) coverage = amount;
      }
    }
    if (coverage != _coverage) setState(() => _coverage = coverage);
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    // Body top padding describes chrome, not the system status bar. Only the
    // outer pinned bar consumes the system top; side insets remain local.
    final systemTop = _PinnedBodyScope.isInside(context) ? 0.0 : media.padding.top;
    final safeInsets = EdgeInsets.only(top: systemTop, left: media.padding.left, right: media.padding.right);
    final chrome = Padding(
      padding: safeInsets,
      child: MediaQuery.removePadding(
        context: context,
        removeTop: true,
        removeLeft: true,
        removeRight: true,
        child: FrostChromeScrollAwayScope(
          link: _away,
          child: widget.extent != null ? SizedBox.expand(child: widget.chrome) : widget.chrome,
        ),
      ),
    );

    final bars = CustomMultiChildLayout(
      delegate: _PinnedLayoutDelegate(widget.extent),
      children: [
        LayoutId(
          id: _PinnedSlot.body,
          child: LayoutBuilder(
            builder: (context, constraints) {
              // The delegate lays out chrome first and encodes its measured
              // height in minHeight, so this body builds correctly in this frame.
              final extent = constraints.minHeight;
              return SizedBox.expand(
                child: MediaQuery(
                  key: _bodyKey,
                  data: media.copyWith(
                    padding: media.padding.copyWith(top: extent),
                    viewPadding: media.viewPadding.copyWith(top: extent),
                  ),
                  child: _PinnedBodyScope(
                    child: NotificationListener<ScrollMetricsNotification>(
                      onNotification: _handleMetrics,
                      child: NotificationListener<ScrollNotification>(
                        onNotification: _handleScroll,
                        child: NotificationListener<FrostChromeBodyActivated>(
                          onNotification: _handleBodyActivated,
                          child: FrostHeaderSearchConcealed(
                            link: _search,
                            child: ListenableBuilder(
                              listenable: _search,
                              builder: (context, body) => ExcludeFocus(excluding: _search.showing, child: body!),
                              child: widget.body,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        LayoutId(
          id: _PinnedSlot.chrome,
          child: Listener(
            onPointerSignal: _handlePointerSignal,
            child: RawGestureDetector(
              gestures: {
                VerticalDragGestureRecognizer: GestureRecognizerFactoryWithHandlers<VerticalDragGestureRecognizer>(
                  () => VerticalDragGestureRecognizer(supportedDevices: ScrollConfiguration.of(context).dragDevices),
                  (recognizer) => recognizer
                    ..supportedDevices = ScrollConfiguration.of(context).dragDevices
                    ..onStart = _handleDragStart
                    ..onUpdate = ((details) => _drag?.update(details))
                    ..onEnd = ((details) => _drag?.end(details))
                    ..onCancel = (() => _drag?.cancel()),
                ),
              },
              child: AnimatedBuilder(
                animation: _awayMotion,
                builder: (context, chrome) => _ChromeHitArea(
                  exposed: _away.offset,
                  child: FrostPinnedChromeGlass._(
                    // The header sits on the suggestions page, not over scrolled content.
                    opacity: _search.showing ? 0 : _coverage,
                    // The value already follows the scroll position frame by frame.
                    animate: false,
                    // The glass ends where the visible rows end once the top
                    // row has slid away; content shows below it.
                    hiddenExtent: _away.offset,
                    child: chrome,
                  ),
                ),
                child: chrome,
              ),
            ),
          ),
        ),
      ],
    );
    return FrostHeaderSearchBodyScope(
      link: _search,
      child: FrostHeaderSearchPage(link: _search, child: bars),
    );
  }
}

// The shown chrome is solid to taps, blank parts included, so a tap on it
// never reaches the content scrolled beneath. The band at its bottom that a
// slid-away row left open shows the body, and taps there reach the body.
class _ChromeHitArea extends SingleChildRenderObjectWidget {
  const _ChromeHitArea({required this.exposed, required super.child});
  final double exposed;
  @override
  RenderObject createRenderObject(BuildContext context) => _RenderChromeHitArea(exposed);
  @override
  void updateRenderObject(BuildContext context, _RenderChromeHitArea renderObject) => renderObject.exposed = exposed;
}

class _RenderChromeHitArea extends RenderProxyBox {
  _RenderChromeHitArea(this.exposed);
  double exposed;

  // Children still take their own taps first; blank chrome takes the rest.
  @override
  bool hitTestSelf(Offset position) => position.dy < size.height - exposed;
}

// The body keeps the public MediaQuery/spacer contract, but its top padding
// must never be consumed as another system safe area by a nested pinned bar.
class _PinnedBodyScope extends InheritedWidget {
  const _PinnedBodyScope({required super.child});
  static bool isInside(BuildContext context) => context.dependOnInheritedWidgetOfExactType<_PinnedBodyScope>() != null;
  @override
  bool updateShouldNotify(_PinnedBodyScope oldWidget) => false;
}

enum _PinnedSlot { body, chrome }

class _PinnedLayoutDelegate extends MultiChildLayoutDelegate {
  _PinnedLayoutDelegate(this.extent);
  final double? extent;

  @override
  void performLayout(Size size) {
    final fixed = extent?.clamp(0.0, size.height);
    final chromeSize = layoutChild(
      _PinnedSlot.chrome,
      BoxConstraints(minWidth: size.width, maxWidth: size.width, minHeight: fixed ?? 0, maxHeight: fixed ?? size.height),
    );
    positionChild(_PinnedSlot.chrome, Offset.zero);
    layoutChild(_PinnedSlot.body, BoxConstraints(minWidth: size.width, maxWidth: size.width, minHeight: chromeSize.height, maxHeight: size.height));
    positionChild(_PinnedSlot.body, Offset.zero);
  }

  @override
  bool shouldRelayout(_PinnedLayoutDelegate oldDelegate) => extent != oldDelegate.extent;
}

/// First sliver of a scroll view under [FrostPinnedChrome].
class FrostChromeSpacer extends StatelessWidget {
  const FrostChromeSpacer({super.key});

  @override
  Widget build(BuildContext context) => SliverToBoxAdapter(child: SizedBox(height: MediaQuery.paddingOf(context).top));
}
