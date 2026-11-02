import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' show DefaultTabController, TabController;
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../foundation/metrics.dart';
import '../media/_pager_media_scope.dart';
import '_chrome_active_body.dart';

/// Library-only: one body per section of a [TabController], built when it is
/// first shown and kept while this widget lives, each with its own scroll
/// position.
///
/// Touch and stylus swipe between neighbouring sections with the tab
/// indicator following the finger (the controller's offset, as TabBarView
/// writes it); mouse, trackpad and wheels do not page, so they switch by the
/// tabs. An inner horizontal scroller takes a drag first, and zoomed media in
/// the current section stops paging. Selecting a tab further away first
/// brings the current section next to it, so sections on the way are not
/// built. Reduced motion jumps.
///
/// Only the section pages settle on is active: the pinned chrome follows its
/// scrolling, and it alone takes focus and the ambient
/// [PrimaryScrollController]. Sections off screen pause their tickers.
class FrostSectionPages extends StatefulWidget {
  const FrostSectionPages({required this.itemBuilder, this.controller, super.key});
  final TabController? controller;
  final IndexedWidgetBuilder itemBuilder;
  @override
  State<FrostSectionPages> createState() => _SectionPagesState();
}

class _SectionPagesState extends State<FrostSectionPages> with SingleTickerProviderStateMixin {
  TabController? _controller;
  PageController? _pages;
  late final _motion = AnimationController.unbounded(vsync: this)..addListener(_tick);

  /// The section the pages settle on.
  int _section = 0;

  /// Sections on screen: two while a swipe or a slide is under way.
  var _shown = (0, 0);

  /// Slot to section while a slide to a far tab has the current section
  /// swapped next to it; null otherwise.
  List<int>? _order;

  /// Page moves made here rather than by a finger.
  int _driving = 0, _request = 0;
  final _zoomedMedia = <Object, int>{};

  /// The vertical scroll view each section last reported, so its metrics can
  /// reach the chrome again when the section becomes active.
  final _scrollers = <int, BuildContext>{};

  /// Controllers that sections off screen hold in place of the ambient
  /// primary one: a scroll view that stopped inheriting a primary controller
  /// would rebuild its scrollable and lose its position.
  final _standIns = <int, ScrollController>{};

  TabController get _tabs => _controller!;
  int _sectionAt(int slot) => _order?[slot] ?? slot;
  int _slotOf(int section) => _order?.indexOf(section) ?? section;
  bool get _ready => _pages!.hasClients && _pages!.position.hasContentDimensions;
  bool get _inLayout => SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _bind();
  }

  @override
  void didUpdateWidget(FrostSectionPages oldWidget) {
    super.didUpdateWidget(oldWidget);
    _bind();
  }

  void _bind() {
    final controller = widget.controller ?? DefaultTabController.of(context);
    if (controller == _controller) return;
    _controller?.removeListener(_selectionChanged);
    _controller = controller..addListener(_selectionChanged);
    // Another controller is another set of sections.
    _request++;
    _motion.stop();
    _order = null;
    _scrollers.clear();
    _zoomedMedia.clear();
    final standIns = [..._standIns.values];
    _standIns.clear();
    _section = controller.index;
    _shown = (_section, _section);
    final old = _pages;
    _pages = PageController(initialPage: _section);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      old?.dispose();
      for (final controller in standIns) {
        controller.dispose();
      }
    });
  }

  void _selectionChanged() {
    final index = _tabs.index;
    // A tab or the app chose a section; a swipe has already settled here.
    if (index != _section) _go(index, animate: _tabs.indexIsChanging);
  }

  void _jumpTo(double page) {
    final position = _pages!.position;
    _driving++;
    position.jumpTo(page * position.viewportDimension);
    _driving--;
  }

  void _tick() {
    if (_ready) _jumpTo(_motion.value);
  }

  void _go(int target, {required bool animate}) {
    final request = ++_request;
    _motion.stop();
    if (!_ready) {
      _setSection(target);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || request != _request || !_ready) return;
        _restoreOrder();
        _jumpTo(target.toDouble());
      });
      return;
    }
    // Whatever was moving lands first, so the slide starts from a settled page.
    final from = _order == null ? _pages!.page!.round() : _section;
    _restoreOrder();
    _jumpTo(from.toDouble());
    _setSection(target);
    if (target == from) return;
    if (!animate || MediaQuery.disableAnimationsOf(context)) {
      _jumpTo(target.toDouble());
      return;
    }
    var start = from;
    if ((target - from).abs() > 1) {
      // Swap the current section next to the target so the slide passes no
      // other section; the swap is undone once it lands.
      start = target > from ? target - 1 : target + 1;
      setState(
        () => _order = [for (var slot = 0; slot < _tabs.length; slot++) slot]
          ..[start] = from
          ..[from] = start,
      );
      _jumpTo(start.toDouble());
    }
    _motion.value = start.toDouble();
    unawaited(_slide(target, request));
  }

  Future<void> _slide(int target, int request) async {
    try {
      await FrostMotion.springTo(context, _motion, target.toDouble(), FrostMotion.gentle).orCancel;
    } on TickerCanceled {
      // A newer move or a finger took over and owns the pages now.
      return;
    }
    if (mounted && request == _request) _restoreOrder();
  }

  void _restoreOrder() {
    if (_order != null) setState(() => _order = null);
  }

  void _setSection(int section) {
    if (section == _section) return;
    setState(() => _section = section);
    // The chrome follows the section on screen: hand it that section's
    // scroll metrics, as if its list had just been laid out.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || section != _section) return;
      final scroller = _scrollers[section];
      if (scroller == null || !scroller.mounted) return;
      final position = Scrollable.maybeOf(scroller)?.position;
      if (position != null && position.hasContentDimensions) {
        ScrollMetricsNotification(metrics: position.copyWith(), context: scroller).dispatch(scroller);
      }
    });
  }

  bool _scrolled(ScrollNotification notification) {
    if (notification.depth != 0) return false;
    if (_inLayout) {
      // A resize keeps the page; settle on it once the frame is laid out.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_ready || _driving > 0) return;
        _updateShown();
        final page = _pages!.page!;
        if (page == page.roundToDouble() && !_motion.isAnimating) _settle(page);
      });
      return false;
    }
    _updateShown();
    if (_driving > 0 || !_ready) return false;
    final page = _pages!.page!;
    if (notification is ScrollStartNotification && notification.dragDetails != null) {
      // A finger takes over from a slide under way.
      _request++;
      _motion.stop();
    } else if (_motion.isAnimating) {
      // The position settling between two frames of a slide is no finger: the
      // tab controller already knows where the slide is going.
      return false;
    } else if (notification is ScrollUpdateNotification && !_tabs.indexIsChanging) {
      if ((page - _tabs.index).abs() > 1) {
        _setSection(page.round());
        _tabs.index = _section;
      }
      _tabs.offset = (page - _tabs.index).clamp(-1.0, 1.0);
    } else if (notification is ScrollEndNotification) {
      _settle(page);
    }
    return false;
  }

  void _settle(double page) {
    _setSection(_sectionAt(page.round()));
    _tabs.index = _section;
    if (!_tabs.indexIsChanging) _tabs.offset = (page - _tabs.index).clamp(-1.0, 1.0);
  }

  void _updateShown() {
    if (!_ready) return;
    final last = _tabs.length - 1, page = _pages!.page!;
    final shown = (_sectionAt(page.floor().clamp(0, last)), _sectionAt(page.ceil().clamp(0, last)));
    if (shown != _shown) setState(() => _shown = shown);
  }

  void _zoom(Object source, int section, bool zoomed) {
    if (!mounted) return;
    final before = _zoomedMedia.containsValue(_section);
    if (zoomed) {
      _zoomedMedia[source] = section;
    } else {
      _zoomedMedia.remove(source);
    }
    if (before != _zoomedMedia.containsValue(_section)) setState(() {});
  }

  bool _report(int section, ScrollMetrics metrics, BuildContext? context, int depth) {
    if (depth == 0 && metrics.axis == Axis.vertical && context != null) _scrollers[section] = context;
    return false;
  }

  /// Wheels and trackpads that scroll sideways do not page between sections;
  /// a scroller inside the section that takes the event registered first.
  void _pointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent && event.scrollDelta.dx != 0) GestureBinding.instance.pointerSignalResolver.register(event, (_) {});
  }

  @override
  void dispose() {
    _request++;
    _controller?.removeListener(_selectionChanged);
    _motion.dispose();
    _pages?.dispose();
    for (final controller in _standIns.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Widget _page(BuildContext context, int section, PrimaryScrollController? primary) {
    final active = section == _section;
    final body = NotificationListener<ScrollMetricsNotification>(
      onNotification: (notification) => _report(section, notification.metrics, notification.context, notification.depth),
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) => _report(section, notification.metrics, notification.context, notification.depth),
        child: Listener(
          onPointerSignal: _pointerSignal,
          child: FrostPagerMediaScope(index: section, onZoomChanged: _zoom, child: widget.itemBuilder(context, section)),
        ),
      ),
    );
    return _KeptSection(
      key: ValueKey(section),
      child: FrostChromeActiveBody(
        active: active,
        child: TickerMode(
          enabled: active || section == _shown.$1 || section == _shown.$2,
          child: ExcludeFocus(
            excluding: !active,
            child: switch (primary?.controller) {
              null => PrimaryScrollController.none(child: body),
              final controller => PrimaryScrollController(
                controller: active ? controller : _standIns.putIfAbsent(section, ScrollController.new),
                automaticallyInheritForPlatforms: primary!.automaticallyInheritForPlatforms,
                scrollDirection: primary.scrollDirection,
                child: body,
              ),
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = context.dependOnInheritedWidgetOfExactType<PrimaryScrollController>();
    return NotificationListener<ScrollNotification>(
      onNotification: _scrolled,
      child: PageView.custom(
        key: ObjectKey(_pages),
        controller: _pages,
        // Mouse and trackpad switch sections by the tabs, not by dragging.
        scrollBehavior: ScrollConfiguration.of(context).copyWith(
          dragDevices: const {PointerDeviceKind.touch, PointerDeviceKind.stylus, PointerDeviceKind.invertedStylus, PointerDeviceKind.unknown},
          pointerAxisModifiers: const {},
          scrollbars: false,
          overscroll: false,
        ),
        physics: _order != null || _zoomedMedia.containsValue(_section) ? const NeverScrollableScrollPhysics() : const ClampingScrollPhysics(),
        childrenDelegate: SliverChildBuilderDelegate(
          (context, slot) => _page(context, _sectionAt(slot), primary),
          childCount: _tabs.length,
          findChildIndexCallback: (key) => key is ValueKey<int> ? _slotOf(key.value) : null,
        ),
      ),
    );
  }
}

class _KeptSection extends StatefulWidget {
  const _KeptSection({required this.child, super.key});
  final Widget child;
  @override
  State<_KeptSection> createState() => _KeptSectionState();
}

class _KeptSectionState extends State<_KeptSection> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
