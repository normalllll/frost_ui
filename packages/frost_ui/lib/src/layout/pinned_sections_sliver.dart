part of 'pinned_chrome.dart';

/// The first sliver of a [NestedScrollView] in a [FrostPinnedChrome] body: a
/// [lead], such as a profile's identity, that scrolls away, and section [tabs]
/// below it that stick under the page header.
///
/// The page is one continuous backdrop until the tabs near the header. One
/// glass then fades in behind the header and the tabs together, following the
/// scroll, with the only separator below the tabs. The lead fades as it passes
/// under the header's controls. Once it has gone the tabs tuck slightly under
/// the header, so the joined bar is shorter than its two rows.
///
/// Each section is a scroll view in the [NestedScrollView]'s body, with
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

  /// How far the stuck tabs go under the header.
  static const _tuckDistance = 12.0;

  @override
  Widget build(BuildContext context) {
    final chrome = _PinnedBodyScope.maybeOf(context);
    final band = chrome?.band;
    // Larger titles need the whole header row.
    final roomy = MediaQuery.textScalerOf(context).scale(1) <= 1.3;
    return SliverOverlapAbsorber(
      handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
      sliver: _SectionsHeaderSliver(
        mask: FrostThemeTokens.of(context).canvas,
        inset: MediaQuery.paddingOf(context).top,
        rowRoom: chrome == null ? 0 : chrome.rowRoom,
        tuck: band != null && roomy ? _tuckDistance : 0,
        band: band,
        children: [
          FrostContentColumn(maxWidth: double.infinity, child: lead),
          if (band == null)
            const FrostPinnedChromeGlass._(opacity: 1, hiddenExtent: 0, corners: FrostPinnedChromeCorners.bottom)
          else
            ListenableBuilder(
              listenable: band,
              builder: (context, _) => FrostPinnedChromeGlass._(opacity: band.reveal ?? 0, hiddenExtent: 0, animate: false),
            ),
          FrostContentColumn(maxWidth: double.infinity, child: tabs),
        ],
      ),
    );
  }
}

class _SectionsHeaderSliver extends MultiChildRenderObjectWidget {
  const _SectionsHeaderSliver({required this.mask, required this.inset, required this.rowRoom, required this.tuck, required this.band, required super.children});
  final Color mask;
  final double inset, rowRoom, tuck;
  final _SectionsBand? band;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderSectionsHeader(mask, inset, rowRoom, tuck, band);

  @override
  void updateRenderObject(BuildContext context, _RenderSectionsHeader renderObject) => renderObject
    ..mask = mask
    ..inset = inset
    ..rowRoom = rowRoom
    ..tuck = tuck
    ..band = band;
}

class _SectionsHeaderData extends ContainerBoxParentData<RenderBox> {}

/// Sizes itself from its boxes in one pass: the chrome's inset, then the lead,
/// then the tabs. Scrolling takes the lead away and the rest stays, less the
/// part of the tabs that tucks under the chrome. Under a chrome the glass runs
/// from the top of the view to the bottom of the tabs, wherever they are.
class _RenderSectionsHeader extends RenderSliver with ContainerRenderObjectMixin<RenderBox, _SectionsHeaderData>, RenderSliverHelpers {
  _RenderSectionsHeader(this._mask, this._inset, this._rowRoom, this._tuck, this._band);

  /// The band above the chrome's bottom in which the lead fades away.
  static const _fadeDistance = 32.0;

  Color _mask;
  set mask(Color value) {
    if (_mask == value) return;
    _mask = value;
    markNeedsPaint();
  }

  double _inset;
  set inset(double value) {
    if (_inset == value) return;
    _inset = value;
    markNeedsLayout();
  }

  /// Room the tabs leave below the body's top for a header row that is not
  /// there at rest, so they stick under it when it comes.
  double _rowRoom;
  set rowRoom(double value) {
    if (_rowRoom == value) return;
    _rowRoom = value;
    markNeedsLayout();
  }

  double _tuck;
  set tuck(double value) {
    if (_tuck == value) return;
    _tuck = value;
    markNeedsLayout();
  }

  _SectionsBand? _band;
  set band(_SectionsBand? value) {
    if (identical(_band, value)) return;
    _band = value;
    markNeedsLayout();
  }

  bool _reportScheduled = false;
  double? _reveal;
  double _shrink = 0;
  final _fade = LayerHandle<ShaderMaskLayer>();

  RenderBox get _lead => firstChild!;
  RenderBox get _glass => childAfter(firstChild!)!;
  RenderBox get _tabs => lastChild!;

  double get _tabsTop => _inset - _shrink + _lead.size.height;

  @override
  bool get alwaysNeedsCompositing => true;

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
      if (attached) _band?.report(_reveal);
    });
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  @override
  void detach() {
    final band = _band;
    if (band != null) {
      _reveal = null;
      SchedulerBinding.instance.addPostFrameCallback((_) => band.report(null));
    }
    super.detach();
  }

  @override
  void dispose() {
    _fade.layer = null;
    super.dispose();
  }

  @override
  void performLayout() {
    assert(constraints.axisDirection == AxisDirection.down);
    final box = constraints.asBoxConstraints();
    _lead.layout(box, parentUsesSize: true);
    _tabs.layout(box, parentUsesSize: true);
    final lead = _lead.size.height, tabs = _tabs.size.height, bar = _inset + _rowRoom, stuck = math.min(bar - math.min(_tuck, bar), _inset + lead);
    final travel = _inset + lead - stuck, pinned = stuck + tabs, whole = _inset + lead + tabs, offset = constraints.scrollOffset;
    _shrink = math.min(offset, travel);
    final reach = math.min(_FpPinnedChromeState._revealDistance, travel);
    final reveal = reach == 0 ? 1.0 : clampDouble((offset - (travel - reach)) / reach, 0, 1);
    _glass.layout(BoxConstraints.tightFor(width: constraints.crossAxisExtent, height: _band == null ? tabs : _tabsTop + tabs));
    final shown = math.max(pinned, whole - offset);
    final room = math.max(0.0, constraints.remainingPaintExtent - constraints.overlap);
    final layoutExtent = clampDouble(whole - offset, 0, constraints.remainingPaintExtent);
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
    if (reveal != _reveal) {
      _reveal = reveal;
      _report();
    }
  }

  @override
  double childMainAxisPosition(covariant RenderBox child) {
    if (identical(child, _lead)) return _inset - _shrink;
    return identical(child, _glass) && _band != null ? 0 : _tabsTop;
  }

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

  void _paintLead(PaintingContext context, Offset offset) => context.paintChild(_lead, offset + Offset(0, childMainAxisPosition(_lead)));

  @override
  void paint(PaintingContext context, Offset offset) {
    if (_shrink > 0 && _band != null && _inset > 0) {
      // In view coordinates, so the fade stays put while the lead moves.
      final start = math.max(0.0, _inset - _fadeDistance);
      final fade = _fade.layer ??= ShaderMaskLayer();
      fade
        ..shader = ui.Gradient.linear(Offset(0, start), Offset(0, _inset), [_mask.withValues(alpha: 0), _mask.withValues(alpha: 1)])
        ..maskRect = offset & Size(constraints.crossAxisExtent, _inset - _shrink + _lead.size.height)
        ..blendMode = BlendMode.dstIn;
      context.pushLayer(fade, _paintLead, offset);
    } else {
      _fade.layer = null;
      _paintLead(context, offset);
    }
    for (final child in [_glass, _tabs]) {
      context.paintChild(child, offset + Offset(0, childMainAxisPosition(child)));
    }
  }
}

/// What a sections sliver tells the chrome above it. Reported a frame late, by
/// which time the chrome may be gone.
class _SectionsBand extends ChangeNotifier {
  bool _disposed = false;

  /// How much of the shared glass shows; null without a sections sliver.
  double? reveal;

  void report(double? reveal) {
    if (_disposed || reveal == this.reveal) return;
    this.reveal = reveal;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
