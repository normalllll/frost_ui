import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../foundation/_focus_modality.dart';
import '../foundation/metrics.dart';

/// What a search option does to the dropdown once its callback has run.
enum FrostSearchOptionExit {
  /// Close the dropdown until the query changes or focus returns.
  dismiss,

  /// Keep it open for the new query, with nothing highlighted.
  reopen,

  /// Leave it as it is, highlight included (a section's action).
  stay,
}

/// One selectable region registered with the dropdown that shows it.
abstract interface class FrostSearchOptionTarget {
  BuildContext get context;
  String? get semanticLabel;

  /// Whether this option is a suggestion row with a leading icon or dot.
  bool get hasLeading;
  VoidCallback get onSelected;
  FrostSearchOptionExit get exit;

  /// The option's area, from its [FrostSearchOptionBox].
  FrostRenderSearchOption? get box;
  set box(FrostRenderSearchOption? value);

  /// Repaints the option after its highlight changed.
  void highlightChanged();
}

typedef FrostSearchOptionEntry = ({FrostSearchOptionTarget option, Rect rect});

/// The dropdown's option registry: highlight, reading order and keyboard
/// movement over whatever options the App's content holds. Its owner (the
/// search field) keeps editing focus; options never take it.
///
/// Options join while they are in the tree and leave when they are
/// deactivated, so a build that adds or removes rows is counted before the
/// frame lays out.
class FrostSearchOptions {
  FrostSearchOptions({required this.onSelect, required this.onHighlight}) {
    FrostInputModality.instance.attach();
    FrostInputModality.instance.addListener(_modalityChanged);
  }

  /// Runs an option's callback and closes, reopens or keeps the dropdown.
  final void Function(VoidCallback onSelected, FrostSearchOptionExit exit) onSelect;

  /// The field's announcement changed; the field rebuilds its hint.
  final VoidCallback onHighlight;

  /// Set by the [FrostSearchOptionsBuilder] that shows these options.
  VoidCallback? onMembershipChanged;

  /// The labels' position text, set by the owner on every build.
  String Function(int position, int total)? itemPosition;

  final _options = <FrostSearchOptionTarget>{};
  FrostSearchOptionTarget? _keyboard, _hover;
  String? _announced;
  bool _pointerMoved = false, _refreshing = false, _disposed = false;

  /// A resting pointer over a freshly shown option takes no highlight until
  /// it moves, as after a keep-open selection.
  bool hoverNeedsMove = false;
  TextDirection textDirection = TextDirection.ltr;

  /// The highlight that is drawn and that Enter selects: the pointer's over
  /// the keyboard's.
  FrostSearchOptionTarget? get active => _hover ?? _keyboard;

  /// Every suggestion row reserves the icon column once any row has a
  /// leading icon or dot, so their text starts on one edge.
  bool get reserveIconColumn => _options.any((option) => option.hasLeading);

  void join(FrostSearchOptionTarget option) {
    if (_options.add(option)) _changed();
  }

  void updated(FrostSearchOptionTarget option) => _changed();

  void leave(FrostSearchOptionTarget option) {
    if (!_options.contains(option)) return;
    final keyboard = identical(_keyboard, option), hover = identical(_hover, option);
    // The place the highlighted option holds now, among the options as they
    // are laid out now.
    final index = keyboard ? readingOrder().indexWhere((entry) => identical(entry.option, option)) : -1;
    _options.remove(option);
    if (keyboard) _keyboard = null;
    if (hover) _hover = null;
    _changed();
    if (!keyboard && !hover) return;
    // Leaving happens while the tree is building. Once the frame has laid
    // out, the keyboard highlight moves to the option now at that place.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (_disposed) return;
      if (index >= 0 && _keyboard == null) {
        final order = readingOrder();
        if (order.isNotEmpty) _setKeyboard(order[index.clamp(0, order.length - 1)].option, reveal: false);
      }
      active?.highlightChanged();
      onHighlight();
    });
  }

  void _changed() {
    onMembershipChanged?.call();
    refreshAnnouncement();
  }

  /// Rechecks the announcement once the frame has laid out, so the field's
  /// hint names what Enter would select after the content changed in place.
  void refreshAnnouncement() {
    if (_refreshing) return;
    _refreshing = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _refreshing = false;
      if (!_disposed && _describe() != _announced) onHighlight();
    });
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  bool isHighlighted(FrostSearchOptionTarget option) => identical(active, option);

  /// Clears the highlight and the pointer's movement, for a new query, a new
  /// focus entry or a keep-open selection.
  void reset() {
    _pointerMoved = false;
    clear();
  }

  void clear() {
    final previous = active;
    _keyboard = null;
    _hover = null;
    previous?.highlightChanged();
  }

  void select(FrostSearchOptionTarget option) => onSelect(option.onSelected, option.exit);

  void pointerEntered(FrostSearchOptionTarget option, PointerEvent event) {
    if (_pointerMoved || !hoverNeedsMove) _setHover(option, event);
  }

  void pointerMoved(FrostSearchOptionTarget option, PointerEvent event) {
    _pointerMoved = true;
    _setHover(option, event);
  }

  void pointerExited(FrostSearchOptionTarget option) {
    if (!identical(_hover, option)) return;
    _hover = null;
    option.highlightChanged();
    _keyboard?.highlightChanged();
    onHighlight();
  }

  void _setHover(FrostSearchOptionTarget option, PointerEvent event) {
    if (!FrostInputModality.instance.acceptsHover(event) || identical(_hover, option)) return;
    final previous = active;
    _hover = option;
    previous?.highlightChanged();
    option.highlightChanged();
    onHighlight();
  }

  void _modalityChanged() {
    if (!FrostInputModality.instance.touch || active == null) return;
    clear();
    onHighlight();
  }

  void _setKeyboard(FrostSearchOptionTarget? option, {bool reveal = true}) {
    final previous = active;
    _keyboard = option;
    _hover = null;
    previous?.highlightChanged();
    option?.highlightChanged();
    onHighlight();
    if (option == null || !reveal) return;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (_disposed || !identical(_keyboard, option) || !option.context.mounted) return;
      final context = option.context;
      Scrollable.ensureVisible(context, duration: FrostMotion.duration(context, FrostMotion.layoutFade), curve: FrostMotion.hoverCurve);
    });
  }

  /// Laid-out options in reading order: lines top to bottom, each line from
  /// the start edge. A line is a band of options whose heights overlap, so
  /// centred items of different heights share one line.
  List<FrostSearchOptionEntry> readingOrder() {
    final byTop = [
      for (final option in _options)
        if (option.box?.rect case final rect?) (option: option, rect: rect),
    ]..sort((a, b) => a.rect.top != b.rect.top ? a.rect.top.compareTo(b.rect.top) : a.rect.bottom.compareTo(b.rect.bottom));
    final rtl = textDirection == TextDirection.rtl;
    final lines = <List<FrostSearchOptionEntry>>[];
    var bottom = double.negativeInfinity;
    for (final entry in byTop) {
      if (lines.isEmpty || entry.rect.top >= bottom - _epsilon) {
        lines.add([entry]);
        bottom = entry.rect.bottom;
      } else {
        lines.last.add(entry);
        if (entry.rect.bottom > bottom) bottom = entry.rect.bottom;
      }
    }
    return [
      for (final line in lines)
        ...(line.indexed.toList()..sort((a, b) {
              final start = rtl ? b.$2.rect.right.compareTo(a.$2.rect.right) : a.$2.rect.left.compareTo(b.$2.rect.left);
              return start != 0 ? start : a.$1.compareTo(b.$1);
            }))
            .map((indexed) => indexed.$2),
    ];
  }

  /// Moves the keyboard highlight for an arrow key, from the keyboard's own
  /// highlight: a resting pointer is not one. Down and Up without it start at
  /// the first and last option; with it every arrow goes to the nearest option
  /// that way. Up from the top clears it. Left and Right are left to the
  /// editor when no option lies that way. Returns whether it took the key.
  bool move(LogicalKeyboardKey key) {
    final order = readingOrder();
    if (order.isEmpty) return false;
    final from = _keyboard;
    final current = from == null ? null : order.where((entry) => identical(entry.option, from)).firstOrNull;
    if (current == null) {
      if (key == LogicalKeyboardKey.arrowDown) {
        _setKeyboard(order.first.option);
        return true;
      }
      if (key == LogicalKeyboardKey.arrowUp) {
        _setKeyboard(order.last.option);
        return true;
      }
      return false;
    }
    final target = _nearest(order, current, key);
    if (target != null) {
      _setKeyboard(target);
      return true;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      _setKeyboard(null);
      return true;
    }
    return key == LogicalKeyboardKey.arrowDown;
  }

  FrostSearchOptionTarget? _nearest(List<FrostSearchOptionEntry> order, FrostSearchOptionEntry current, LogicalKeyboardKey key) {
    final from = current.rect;
    final vertical = key == LogicalKeyboardKey.arrowDown || key == LogicalKeyboardKey.arrowUp;
    final rtl = textDirection == TextDirection.rtl;
    double start(Rect rect) => rtl ? rect.right : rect.left;
    ({FrostSearchOptionTarget option, double primary, bool overlaps, double cross, int index})? best;
    for (var i = 0; i < order.length; i++) {
      final (:option, :rect) = order[i];
      if (identical(option, current.option)) continue;
      final primary = switch (key) {
        LogicalKeyboardKey.arrowDown => rect.top - from.bottom,
        LogicalKeyboardKey.arrowUp => from.top - rect.bottom,
        LogicalKeyboardKey.arrowRight => rect.left - from.right,
        LogicalKeyboardKey.arrowLeft => from.left - rect.right,
        _ => null,
      };
      if (primary == null) return null;
      if (primary < -_epsilon) continue;
      final overlaps = vertical
          ? rect.left < from.right - _epsilon && rect.right > from.left + _epsilon
          : rect.top < from.bottom - _epsilon && rect.bottom > from.top + _epsilon;
      // An overlapping option is lined up by its start edge, so a full-width
      // row goes to the first card of a grid below it.
      final cross = vertical
          ? (overlaps ? (start(rect) - start(from)).abs() : (rect.center.dx - from.center.dx).abs())
          : (rect.center.dy - from.center.dy).abs();
      final candidate = (option: option, primary: primary < 0 ? 0.0 : primary, overlaps: overlaps, cross: cross, index: i);
      if (best == null || _better(candidate, best)) best = candidate;
    }
    return best?.option;
  }

  static bool _better(
    ({FrostSearchOptionTarget option, double primary, bool overlaps, double cross, int index}) a,
    ({FrostSearchOptionTarget option, double primary, bool overlaps, double cross, int index}) b,
  ) {
    if ((a.primary - b.primary).abs() > _epsilon) return a.primary < b.primary;
    if (a.overlaps != b.overlaps) return a.overlaps;
    if ((a.cross - b.cross).abs() > _epsilon) return a.cross < b.cross;
    return a.index < b.index;
  }

  /// Selects the highlighted option; false when nothing is highlighted.
  bool activate() {
    final option = active;
    if (option == null) return false;
    select(option);
    return true;
  }

  /// The highlighted option's label and position in reading order, as the
  /// field announces it.
  String? announcement() => _announced = _describe();

  String? _describe() {
    final option = active, itemPosition = this.itemPosition;
    if (option == null || itemPosition == null) return null;
    final order = readingOrder();
    final index = order.indexWhere((entry) => identical(entry.option, option));
    if (index < 0) return null;
    final position = itemPosition(index + 1, order.length);
    return option.semanticLabel == null ? position : '${option.semanticLabel} $position';
  }

  void dispose() {
    _disposed = true;
    onMembershipChanged = null;
    FrostInputModality.instance.removeListener(_modalityChanged);
    FrostInputModality.instance.detach();
  }
}

const _epsilon = 0.5;

/// The registry and placement facts that options and sections below a search
/// dropdown read.
class FrostSearchOptionScope extends InheritedWidget {
  const FrostSearchOptionScope({required this.options, required this.inline, required this.reserveIconColumn, required super.child, super.key});
  final FrostSearchOptions options;

  /// The dropdown is in the page (inline or body placement) rather than in a
  /// floating panel.
  final bool inline;
  final bool reserveIconColumn;
  static FrostSearchOptionScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<FrostSearchOptionScope>();
    if (scope == null) {
      throw FlutterError('Search options, sections and status lines go in the content of FrostSearchInput.suggesting or FrostCaptionSearch.');
    }
    return scope;
  }

  @override
  bool updateShouldNotify(FrostSearchOptionScope oldWidget) =>
      options != oldWidget.options || inline != oldWidget.inline || reserveIconColumn != oldWidget.reserveIconColumn;
}

/// The root of a dropdown's content. A [FrostSearchGap] that ends up at the
/// very top of the content collapses to its leading height, so the first
/// section or status line starts on the panel's inset without the gap that
/// separates it from content above.
class FrostSearchContentRoot extends SingleChildRenderObjectWidget {
  const FrostSearchContentRoot({required super.child, super.key});
  @override
  RenderObject createRenderObject(BuildContext context) => _RenderContentRoot();
}

class _RenderContentRoot extends RenderShiftedBox {
  _RenderContentRoot() : super(null);
  final _gaps = <_RenderSearchGap>{};

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = constraints.smallest;
      return;
    }
    child.layout(constraints.loosen(), parentUsesSize: true);
    final data = child.parentData! as BoxParentData;
    data.offset = Offset.zero;
    // The largest change among gaps at the very top, if any.
    double? collapse;
    for (final gap in _gaps) {
      if (!gap.attached || !gap.hasSize) continue;
      if (MatrixUtils.transformPoint(gap.getTransformTo(this), Offset.zero).dy.abs() <= _epsilon) {
        collapse = collapse == null || gap.collapse > collapse ? gap.collapse : collapse;
      }
    }
    final shift = collapse ?? 0;
    data.offset = Offset(0, -shift);
    size = constraints.constrain(Size(child.size.width, child.size.height - shift));
  }
}

/// Vertical room before a dropdown section or status line, [leading] tall
/// instead when nothing precedes it in the content.
class FrostSearchGap extends LeafRenderObjectWidget {
  const FrostSearchGap({required this.height, required this.leading, super.key});
  final double height, leading;
  @override
  RenderObject createRenderObject(BuildContext context) => _RenderSearchGap(height, leading);
  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) => (renderObject as _RenderSearchGap).update(height, leading);
}

class _RenderSearchGap extends RenderBox {
  _RenderSearchGap(this._height, this._leading);
  double _height, _leading;
  _RenderContentRoot? _root;
  double get collapse => _height - _leading;

  void update(double height, double leading) {
    if (height == _height && leading == _leading) return;
    _height = height;
    _leading = leading;
    markNeedsLayout();
    _root?.markNeedsLayout();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    for (var node = parent; node != null; node = node.parent) {
      if (node is _RenderContentRoot) {
        _root = node.._gaps.add(this);
        break;
      }
    }
  }

  @override
  void detach() {
    _root?._gaps.remove(this);
    _root = null;
    super.detach();
  }

  @override
  void performLayout() {
    size = constraints.constrain(Size(constraints.hasBoundedWidth ? constraints.maxWidth : 0, _height));
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.constrain(Size(constraints.hasBoundedWidth ? constraints.maxWidth : 0, _height));

  @override
  double computeMinIntrinsicHeight(double width) => _height;
  @override
  double computeMaxIntrinsicHeight(double width) => _height;
}

/// Builds the [FrostSearchOptionScope] over a dropdown's content at layout
/// time, and builds it again in the same layout when the rows built in the
/// first pass change whether the icon column is reserved. The first frame of
/// a dropdown therefore already has its final row geometry.
class FrostSearchOptionsBuilder extends RenderObjectWidget {
  const FrostSearchOptionsBuilder({required this.options, required this.inline, required this.child, super.key});
  final FrostSearchOptions options;
  final bool inline;
  final Widget child;
  @override
  RenderObjectElement createElement() => _OptionsBuilderElement(this);
  @override
  RenderObject createRenderObject(BuildContext context) => _RenderOptionsBuilder();
}

class _OptionsBuilderElement extends RenderObjectElement {
  _OptionsBuilderElement(FrostSearchOptionsBuilder super.widget) : _widget = widget;
  Element? _child;
  bool? _built;
  bool _building = false;

  // The current widget, kept typed as update hands it over.
  FrostSearchOptionsBuilder _widget;
  @override
  _RenderOptionsBuilder get renderObject => super.renderObject as _RenderOptionsBuilder;
  bool get _stale => _built != _widget.options.reserveIconColumn;

  @override
  void visitChildren(ElementVisitor visitor) {
    if (_child case final child?) visitor(child);
  }

  @override
  void forgetChild(Element child) {
    _child = null;
    super.forgetChild(child);
  }

  @override
  void mount(Element? parent, Object? newSlot) {
    super.mount(parent, newSlot);
    renderObject.element = this;
    _widget.options.onMembershipChanged = _membershipChanged;
  }

  @override
  void update(FrostSearchOptionsBuilder newWidget) {
    super.update(newWidget);
    _widget = newWidget;
    _widget.options.onMembershipChanged = _membershipChanged;
    renderObject.markNeedsBuild();
  }

  @override
  void performRebuild() {
    renderObject.markNeedsBuild();
    super.performRebuild();
  }

  @override
  void unmount() {
    renderObject.element = null;
    if (_widget.options.onMembershipChanged == _membershipChanged) _widget.options.onMembershipChanged = null;
    super.unmount();
  }

  // Rows that change outside this element's own build (an App state below
  // it, or a LayoutBuilder in the content) correct the column on the next
  // frame; ancestors cannot be marked while a descendant lays out.
  void _membershipChanged() {
    if (_building || !_stale) return;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted && _stale) renderObject.markNeedsBuild();
    });
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  void _layout() {
    _building = true;
    try {
      owner!.buildScope(this, _build);
      if (_stale) owner!.buildScope(this, _build);
    } finally {
      _building = false;
    }
  }

  void _build() {
    final reserve = _built = _widget.options.reserveIconColumn;
    _child = updateChild(
      _child,
      FrostSearchOptionScope(options: _widget.options, inline: _widget.inline, reserveIconColumn: reserve, child: _widget.child),
      null,
    );
  }

  @override
  void insertRenderObjectChild(RenderObject child, Object? slot) => renderObject.child = child as RenderBox;
  @override
  void moveRenderObjectChild(RenderObject child, Object? oldSlot, Object? newSlot) {}
  @override
  void removeRenderObjectChild(RenderObject child, Object? slot) => renderObject.child = null;
}

class _RenderOptionsBuilder extends RenderProxyBox {
  _OptionsBuilderElement? element;
  bool _needsBuild = true;

  void markNeedsBuild() {
    _needsBuild = true;
    markNeedsLayout();
  }

  @override
  void performLayout() {
    final element = this.element;
    if (element != null && (_needsBuild || element._stale)) {
      _needsBuild = false;
      invokeLayoutCallback<BoxConstraints>((_) => element._layout());
    }
    super.performLayout();
  }
}

/// An option's area, measured against the dropdown's content root so that
/// scrolling does not move it. The last painted area stands in once the
/// option has left the tree, for placing the highlight it held.
class FrostSearchOptionBox extends SingleChildRenderObjectWidget {
  const FrostSearchOptionBox({required this.target, required super.child, super.key});
  final FrostSearchOptionTarget target;
  @override
  RenderObject createRenderObject(BuildContext context) => target.box = FrostRenderSearchOption();
  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) => target.box = renderObject as FrostRenderSearchOption;
}

class FrostRenderSearchOption extends RenderProxyBox {
  _RenderContentRoot? _root;
  Rect? _last;

  Rect? get rect {
    if (!attached || !hasSize) return _last;
    return _last = MatrixUtils.transformRect(getTransformTo(_root), Offset.zero & size);
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _root = null;
    for (var node = parent; node != null; node = node.parent) {
      if (node is _RenderContentRoot) {
        _root = node;
        break;
      }
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    _last = MatrixUtils.transformRect(getTransformTo(_root), Offset.zero & size);
    super.paint(context, offset);
  }
}
