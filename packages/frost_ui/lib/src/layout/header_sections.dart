import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../foundation/spacing.dart';
import '_chrome_scroll_away.dart';
import '_header_row_span.dart';
import '_header_search_body.dart';

/// Section tabs that a page template treats as part of its page header, such
/// as a browse page's Latest / Popular / Random.
///
/// Only one row stays pinned when it can: if the header row, with every
/// action at its full form, has room for the tabs between its leading content
/// and its actions, the tabs sit in that row. Otherwise they take a pinned
/// row of their own below the header, and the header row slides away while
/// the content scrolls on and returns when it scrolls back. Focus in the
/// header row, its search field included, keeps it shown. The choice follows
/// the width the header actually has, not the platform or input.
class FrostHeaderSections {
  const FrostHeaderSections({required this.tabs, this.trailing});

  /// Usually a [FrostTabBar] with `scrollable: true`. Measured at its natural
  /// width; in a row of its own it takes the width left by [trailing].
  final Widget tabs;

  /// A control that belongs to the selected section, for example a time-range
  /// menu: right after the tabs in the header row, at the end of their own row.
  final Widget? trailing;
}

/// Library-only: a page header with [FrostHeaderSections], inside
/// [FrostPinnedChrome].
class FrostSectionedHeader extends StatefulWidget {
  const FrostSectionedHeader({required this.header, required this.sections, super.key});
  final Widget header;
  final FrostHeaderSections sections;
  @override
  State<FrostSectionedHeader> createState() => _SectionedHeaderState();
}

class _SectionedHeaderState extends State<FrostSectionedHeader> {
  final _span = FrostHeaderRowSpan();
  var _focused = false;

  @override
  Widget build(BuildContext context) {
    final search = FrostHeaderSearchBodyScope.maybeOf(context);
    // While the header search lists its suggestions over the body, the tab row
    // is under them: it leaves focus traversal as well as paint.
    Widget concealed(Widget child) => search == null
        ? child
        : ListenableBuilder(
            listenable: search,
            builder: (context, child) => ExcludeFocus(excluding: search.showing, child: child!),
            child: child,
          );
    return _SectionedHeaderLayout(
      search: search,
      span: _span,
      away: FrostChromeScrollAwayScope.maybeOf(context),
      focused: _focused,
      direction: Directionality.of(context),
      header: FrostHeaderRowSpanScope(
        span: _span,
        // Passive: only reports whether focus is anywhere in the header row.
        child: Focus(canRequestFocus: false, skipTraversal: true, onFocusChange: (focused) => setState(() => _focused = focused), child: widget.header),
      ),
      tabs: concealed(widget.sections.tabs),
      trailing: widget.sections.trailing == null ? null : concealed(widget.sections.trailing!),
    );
  }
}

enum _Slot { header, tabs, trailing }

class _SectionedHeaderLayout extends SlottedMultiChildRenderObjectWidget<_Slot, RenderBox> {
  const _SectionedHeaderLayout({
    required this.span,
    required this.away,
    required this.focused,
    required this.direction,
    required this.search,
    required this.header,
    required this.tabs,
    required this.trailing,
  });
  final FrostHeaderRowSpan span;
  final FrostChromeScrollAway? away;
  final bool focused;
  final TextDirection direction;
  final FrostHeaderSearchBody? search;
  final Widget header, tabs;
  final Widget? trailing;

  @override
  Iterable<_Slot> get slots => _Slot.values;

  @override
  Widget? childForSlot(_Slot slot) => switch (slot) {
    _Slot.header => header,
    _Slot.tabs => tabs,
    _Slot.trailing => trailing,
  };

  @override
  _RenderSectionedHeader createRenderObject(BuildContext context) =>
      _RenderSectionedHeader(span: span, away: away, focused: focused, direction: direction, search: search);

  @override
  void updateRenderObject(BuildContext context, _RenderSectionedHeader renderObject) => renderObject
    ..away = away
    ..focused = focused
    ..direction = direction
    ..search = search;
}

class _RenderSectionedHeader extends RenderBox with SlottedContainerRenderObjectMixin<_Slot, RenderBox> {
  _RenderSectionedHeader({required this._span, required this._away, required this._focused, required this._direction, required this._search});

  FrostHeaderSearchBody? _search;
  set search(FrostHeaderSearchBody? value) {
    if (identical(_search, value)) return;
    if (attached) _search?.removePainter(this);
    _search = value;
    if (attached) _search?.addPainter(this);
    markNeedsPaint();
  }

  final FrostHeaderRowSpan _span;

  FrostChromeScrollAway? _away;
  set away(FrostChromeScrollAway? value) {
    if (identical(_away, value)) return;
    if (attached) _away?.hidden.removeListener(_moved);
    _away = value;
    if (attached) _away?.hidden.addListener(_moved);
    markNeedsLayout();
  }

  bool _focused;
  set focused(bool value) {
    if (_focused == value) return;
    _focused = value;
    _report();
  }

  TextDirection _direction;
  set direction(TextDirection value) {
    if (_direction == value) return;
    _direction = value;
    markNeedsLayout();
  }

  RenderBox? get _header => childForSlot(_Slot.header);
  RenderBox? get _tabs => childForSlot(_Slot.tabs);
  RenderBox? get _trailing => childForSlot(_Slot.trailing);

  /// Whether the tabs sit in the header row.
  bool _merged = false;
  bool _laying = false, _relayoutScheduled = false;
  double _headerHeight = 0;
  final _clip = LayerHandle<ClipRectLayer>();

  /// Tabs between leading content / actions and the tabs; tabs to trailing.
  static const _clusterGap = FrostGap.section, _trailingGap = FrostGap.related;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _span.onChanged = _spanChanged;
    _away?.hidden.addListener(_moved);
    _search?.addPainter(this);
  }

  @override
  void detach() {
    if (_span.onChanged == _spanChanged) _span.onChanged = null;
    _away?.hidden.removeListener(_moved);
    _search?.removePainter(this);
    super.detach();
  }

  @override
  void dispose() {
    _clip.layer = null;
    super.dispose();
  }

  void _moved() {
    markNeedsPaint();
    markNeedsSemanticsUpdate();
  }

  /// A toolbar laid out on its own, or the header's search, changed the row.
  /// Placement is read at paint time; the merge decision waits for layout.
  void _spanChanged() {
    if (_laying || !attached) return;
    markNeedsPaint();
    if (!FrostHeaderRowSpan.duringLayout) {
      markNeedsLayout();
      return;
    }
    if (_relayoutScheduled) return;
    _relayoutScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _relayoutScheduled = false;
      if (attached) markNeedsLayout();
    });
  }

  void _report() => _away?.report(extent: _merged ? 0 : _headerHeight, held: _focused || _span.searchExpanded);

  /// How far the header row has slid up; only a row of its own slides.
  double get _shift => _merged ? 0 : (_away?.offset ?? 0).clamp(0.0, _headerHeight);

  double get _sectionsWidth {
    final trailing = _trailing;
    return _tabs!.size.width + (trailing == null ? 0 : _trailingGap + trailing.size.width);
  }

  bool _fits() {
    final span = _span;
    if (span.box == null || !span.box!.attached || !span.full) return false;
    final room = span.end - span.start - (span.contentBefore ? _clusterGap : 0) - (span.contentAfter ? _clusterGap : 0);
    return _sectionsWidth <= room + .5;
  }

  @override
  void performLayout() {
    _laying = true;
    final header = _header!, tabs = _tabs!, trailing = _trailing;
    final width = constraints.maxWidth;
    header.layout(BoxConstraints(minWidth: width, maxWidth: width, maxHeight: constraints.maxHeight), parentUsesSize: true);
    _headerHeight = header.size.height;
    trailing?.layout(BoxConstraints(maxWidth: width, maxHeight: constraints.maxHeight), parentUsesSize: true);
    // Natural width first: whether the header row's free stretch holds it.
    tabs.layout(BoxConstraints(maxHeight: constraints.maxHeight), parentUsesSize: true);
    _merged = _fits();
    final ltr = _direction == TextDirection.ltr;
    (header.parentData! as BoxParentData).offset = Offset.zero;
    if (_merged) {
      size = constraints.constrain(Size(width, _headerHeight));
    } else {
      final trailingWidth = trailing == null ? 0.0 : trailing.size.width + _trailingGap;
      tabs.layout(BoxConstraints(maxWidth: math.max(0, width - trailingWidth), maxHeight: constraints.maxHeight), parentUsesSize: true);
      final row = math.max(tabs.size.height, trailing?.size.height ?? 0);
      (tabs.parentData! as BoxParentData).offset = Offset(ltr ? 0 : width - tabs.size.width, _headerHeight + (row - tabs.size.height) / 2);
      if (trailing != null) {
        (trailing.parentData! as BoxParentData).offset = Offset(ltr ? width - trailing.size.width : 0, _headerHeight + (row - trailing.size.height) / 2);
      }
      size = constraints.constrain(Size(width, _headerHeight + row));
    }
    _report();
    _laying = false;
  }

  /// Positions of the tabs and trailing control in the header row, from the
  /// toolbar's current span. Null when the span is not in this header.
  (Offset, Offset?)? _rowOffsets() {
    final box = _span.box;
    if (box == null || !box.attached) return null;
    for (RenderObject? node = box; !identical(node, this); node = node.parent) {
      if (node == null) return null;
    }
    final origin = MatrixUtils.transformPoint(box.getTransformTo(this), Offset.zero);
    final tabs = _tabs!, trailing = _trailing;
    final center = origin.dy + _span.height / 2;
    final before = _span.contentBefore ? _clusterGap : 0.0;
    final width = _sectionsWidth;
    final start = _direction == TextDirection.ltr ? origin.dx + _span.start + before : origin.dx + _span.end - before - width;
    final tabsX = _direction == TextDirection.ltr ? start : start + width - tabs.size.width;
    final tabsOffset = Offset(tabsX, center - tabs.size.height / 2);
    if (trailing == null) return (tabsOffset, null);
    final trailingX = _direction == TextDirection.ltr ? start + width - trailing.size.width : start;
    return (tabsOffset, Offset(trailingX, center - trailing.size.height / 2));
  }

  Offset _offsetOf(RenderBox child) {
    final shift = Offset(0, -_shift);
    if (identical(child, _header)) return shift;
    if (_merged) {
      final row = _rowOffsets();
      if (row != null) return (identical(child, _tabs) ? row.$1 : row.$2) ?? Offset.zero;
    }
    return (child.parentData! as BoxParentData).offset + shift;
  }

  /// A tab row of its own sits under suggestions listed over the body.
  bool get _sectionsHidden => !_merged && (_search?.showing ?? false);

  Iterable<RenderBox> get _visibleChildren => [
    _header!,
    if (!_sectionsHidden) ...[_tabs!, ?_trailing],
  ];

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    final offset = _offsetOf(child);
    transform.translateByDouble(offset.dx, offset.dy, 0, 1);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    void paintChildren(PaintingContext context, Offset offset) {
      for (final child in _visibleChildren) {
        context.paintChild(child, offset + _offsetOf(child));
      }
    }

    final shift = _shift;
    if (shift <= 0) {
      _clip.layer = null;
      paintChildren(context, offset);
      return;
    }
    // The header row slides up under the bar's top edge, and the area it
    // leaves at the bottom belongs to the body. Press plates may bleed sideways.
    _clip.layer = context.pushClipRect(
      needsCompositing,
      offset,
      Rect.fromLTRB(-size.width, 0, size.width * 2, size.height - shift),
      paintChildren,
      oldLayer: _clip.layer,
    );
  }

  @override
  bool hitTestSelf(Offset position) => false;

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    if (position.dy < 0 || position.dy > size.height - _shift) return false;
    for (final child in _visibleChildren.toList().reversed) {
      final hit = result.addWithPaintOffset(
        offset: _offsetOf(child),
        position: position,
        hitTest: (result, position) => child.hitTest(result, position: position),
      );
      if (hit) return true;
    }
    return false;
  }

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) => _visibleChildren.forEach(visitor);

  @override
  Rect? describeApproximatePaintClip(RenderObject child) => _shift > 0 ? Rect.fromLTRB(-size.width, 0, size.width * 2, size.height - _shift) : null;
}
