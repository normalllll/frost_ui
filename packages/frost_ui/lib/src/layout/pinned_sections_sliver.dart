part of 'pinned_chrome.dart';

/// The first sliver of a [NestedScrollView] in a [FrostPinnedChrome] body: a
/// [lead], such as a profile's identity, that scrolls away, and section [tabs]
/// below it that stick under the page header.
///
/// Stuck, the header and the tabs read as one bar: the header keeps the sheet's
/// top corners and the only separator is below the tabs. Each section is a
/// scroll view in the [NestedScrollView]'s body, with
/// `primary: true`, and a [SliverOverlapInjector] for
/// [NestedScrollView.sliverOverlapAbsorberHandleFor] as its first sliver. A
/// section keeps its own position when the selection changes, restored by a
/// [PageStorageKey] on its scroll view. Do not keep off-screen sections alive:
/// a [NestedScrollView] scrolls every attached section together.
class FrostSliverSectionsHeader extends StatelessWidget {
  const FrostSliverSectionsHeader({required this.lead, required this.tabs, super.key});

  /// Laid out at the content column's full width.
  final Widget lead;

  /// Usually a [FrostTabBar] with `scrollable: true`.
  final Widget tabs;

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.paddingOf(context).top;
    final continued = _PinnedBodyScope.continuedOf(context);
    final row = FrostContentColumn(maxWidth: double.infinity, child: tabs);
    // Stuck, this glass runs up behind the header, whose own glass steps aside:
    // two blurs would each stop at the seam and show it.
    Widget glass(double reach) => FrostPinnedChromeGlass._(opacity: 1, hiddenExtent: 0, corners: FrostPinnedChromeCorners.bottom, reach: reach, child: row);
    return SliverOverlapAbsorber(
      handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
      sliver: _SectionsHeaderSliver(
        inset: inset,
        continued: continued,
        children: [
          FrostContentColumn(maxWidth: double.infinity, child: lead),
          if (continued == null) glass(0) else ListenableBuilder(listenable: continued, builder: (context, _) => glass(continued.value ? inset : 0)),
        ],
      ),
    );
  }
}

class _SectionsHeaderSliver extends MultiChildRenderObjectWidget {
  const _SectionsHeaderSliver({required this.inset, required this.continued, required super.children});
  final double inset;
  final _BarContinued? continued;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderSectionsHeader(inset, continued);

  @override
  void updateRenderObject(BuildContext context, _RenderSectionsHeader renderObject) => renderObject
    ..inset = inset
    ..continued = continued;
}

class _SectionsHeaderData extends ContainerBoxParentData<RenderBox> {}

/// Sizes itself from its two boxes in one pass: the chrome's inset, then the
/// lead, then the tabs. Scrolling takes the lead away and the rest stays.
class _RenderSectionsHeader extends RenderSliver with ContainerRenderObjectMixin<RenderBox, _SectionsHeaderData>, RenderSliverHelpers {
  _RenderSectionsHeader(this._inset, this._continued);

  double _inset;
  set inset(double value) {
    if (_inset == value) return;
    _inset = value;
    markNeedsLayout();
  }

  _BarContinued? _continued;
  set continued(_BarContinued? value) {
    if (identical(_continued, value)) return;
    _continued = value;
    markNeedsLayout();
  }

  bool _stuck = false, _reportScheduled = false;
  double _shrink = 0;

  RenderBox get _lead => firstChild!;
  RenderBox get _tabs => lastChild!;

  @override
  void setupParentData(RenderObject child) {
    if (child.parentData is! _SectionsHeaderData) child.parentData = _SectionsHeaderData();
  }

  // The chrome is built before the body lays out, so the change waits a frame.
  void _report() {
    if (_reportScheduled) return;
    _reportScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _reportScheduled = false;
      if (attached) _continued?.set(_stuck);
    });
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  @override
  void detach() {
    final continued = _continued;
    if (_stuck && continued != null) {
      _stuck = false;
      SchedulerBinding.instance.addPostFrameCallback((_) => continued.set(false));
    }
    super.detach();
  }

  @override
  void performLayout() {
    assert(constraints.axisDirection == AxisDirection.down);
    final box = constraints.asBoxConstraints();
    _lead.layout(box, parentUsesSize: true);
    _tabs.layout(box, parentUsesSize: true);
    final lead = _lead.size.height, pinned = _inset + _tabs.size.height, whole = pinned + lead;
    _shrink = math.min(constraints.scrollOffset, lead);
    final shown = math.max(pinned, whole - constraints.scrollOffset);
    final room = math.max(0.0, constraints.remainingPaintExtent - constraints.overlap);
    final layoutExtent = clampDouble(whole - constraints.scrollOffset, 0, constraints.remainingPaintExtent);
    geometry = SliverGeometry(
      scrollExtent: whole,
      paintOrigin: constraints.overlap,
      paintExtent: math.min(shown, room),
      layoutExtent: clampDouble(layoutExtent, 0, room),
      maxPaintExtent: whole,
      maxScrollObstructionExtent: pinned,
      cacheExtent: layoutExtent > 0 ? -constraints.cacheOrigin + layoutExtent : layoutExtent,
      hasVisualOverflow: true,
    );
    final stuck = lead > 0 && constraints.scrollOffset >= lead;
    if (stuck != _stuck) {
      _stuck = stuck;
      _report();
    }
  }

  @override
  double childMainAxisPosition(covariant RenderBox child) => identical(child, _lead) ? _inset - _shrink : _inset - _shrink + _lead.size.height;

  @override
  double childCrossAxisPosition(covariant RenderBox child) => 0;

  @override
  void applyPaintTransform(covariant RenderBox child, Matrix4 transform) => applyPaintTransformForBoxChild(child, transform);

  @override
  bool hitTestChildren(SliverHitTestResult result, {required double mainAxisPosition, required double crossAxisPosition}) {
    final hits = BoxHitTestResult.wrap(result);
    for (final child in [_tabs, _lead]) {
      if (hitTestBoxChild(hits, child, mainAxisPosition: mainAxisPosition, crossAxisPosition: crossAxisPosition)) return true;
    }
    return false;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    for (final child in [_lead, _tabs]) {
      context.paintChild(child, offset + Offset(0, childMainAxisPosition(child)));
    }
  }
}

/// Whether a sections row is stuck right below the chrome. Reported a frame
/// late, by which time the chrome may be gone.
class _BarContinued extends ValueNotifier<bool> {
  _BarContinued() : super(false);
  bool _disposed = false;

  void set(bool stuck) {
    if (!_disposed) value = stuck;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
