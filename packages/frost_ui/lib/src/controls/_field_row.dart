import 'dart:math' as math;

import 'package:flutter/foundation.dart' show precisionErrorTolerance;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '_button_parts.dart';

/// One field line: [leading], the [editor] and the [trailing] controls. The
/// editor keeps [editorMinimum] of the width, and the trailing controls get
/// the rest; a [FrostFieldTrailing] there drops the controls that do not fit
/// instead of overflowing the frame at narrow widths and large text.
class FrostFieldRow extends MultiChildRenderObjectWidget {
  FrostFieldRow({
    required Widget editor,
    required Widget trailing,
    required this.editorMinimum,
    Widget? leading,
    this.top = false,
    this.trailingBleed = 0,
    super.key,
  })
    : hasLeading = leading != null,
      super(children: [?leading, editor, trailing]);
  final bool hasLeading;
  final double editorMinimum;

  /// Aligns the children to the top, for multiple lines; otherwise centred.
  final bool top;

  /// Room at the row's end taken from the field's inset. A trailing icon button
  /// uses it, as far as its width goes; anything else ends where the inset would.
  final double trailingBleed;

  @override
  RenderObject createRenderObject(BuildContext context) => RenderFrostFieldRow(hasLeading, editorMinimum, top, trailingBleed, Directionality.of(context));

  @override
  void updateRenderObject(BuildContext context, RenderFrostFieldRow renderObject) => renderObject
    ..hasLeading = hasLeading
    ..editorMinimum = editorMinimum
    ..top = top
    ..trailingBleed = trailingBleed
    ..textDirection = Directionality.of(context);
}

class _FieldRowParentData extends ContainerBoxParentData<RenderBox> {
  bool icon = false;
  bool hint = false;
}

/// Marks a direct child of [FrostFieldTrailing] as an icon button, which may
/// reach into the field's end inset when it comes last.
class FrostFieldIconSlot extends ParentDataWidget<_FieldRowParentData> {
  const FrostFieldIconSlot({required super.child, super.key});

  @override
  void applyParentData(RenderObject renderObject) {
    final data = renderObject.parentData! as _FieldRowParentData;
    if (data.icon) return;
    data.icon = true;
    renderObject.parent?.markNeedsLayout();
  }

  @override
  Type get debugTypicalAncestorWidgetClass => FrostFieldTrailing;
}

/// Marks a direct child of [FrostFieldTrailing] as a hint. It comes last in
/// priority, so it is the first to go, and shows before the other controls.
class FrostFieldHintSlot extends ParentDataWidget<_FieldRowParentData> {
  const FrostFieldHintSlot({required super.child, super.key});

  @override
  void applyParentData(RenderObject renderObject) {
    final data = renderObject.parentData! as _FieldRowParentData;
    if (data.hint) return;
    data.hint = true;
    renderObject.parent?.markNeedsLayout();
  }

  @override
  Type get debugTypicalAncestorWidgetClass => FrostFieldTrailing;
}

class RenderFrostFieldRow extends RenderBox
    with ContainerRenderObjectMixin<RenderBox, _FieldRowParentData>, RenderBoxContainerDefaultsMixin<RenderBox, _FieldRowParentData> {
  RenderFrostFieldRow(this._hasLeading, this._editorMinimum, this._top, this._trailingBleed, this._textDirection);

  double _trailingBleed;
  set trailingBleed(double value) {
    if (value == _trailingBleed) return;
    _trailingBleed = value;
    markNeedsLayout();
  }

  bool _hasLeading;
  set hasLeading(bool value) {
    if (value == _hasLeading) return;
    _hasLeading = value;
    markNeedsLayout();
  }

  double _editorMinimum;
  set editorMinimum(double value) {
    if (value == _editorMinimum) return;
    _editorMinimum = value;
    markNeedsLayout();
  }

  bool _top;
  set top(bool value) {
    if (value == _top) return;
    _top = value;
    markNeedsLayout();
  }

  TextDirection _textDirection;
  set textDirection(TextDirection value) {
    if (value == _textDirection) return;
    _textDirection = value;
    markNeedsLayout();
  }

  RenderBox? get _leading => _hasLeading ? firstChild : null;
  RenderBox get _editor => _hasLeading ? childAfter(firstChild!)! : firstChild!;
  RenderBox get _trailing => lastChild!;

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _FieldRowParentData) child.parentData = _FieldRowParentData();
  }

  double _sum(double Function(RenderBox child) extent) {
    var total = 0.0;
    for (var child = firstChild; child != null; child = childAfter(child)) {
      total += extent(child);
    }
    return total;
  }

  double _max(double Function(RenderBox child) extent) {
    var result = 0.0;
    for (var child = firstChild; child != null; child = childAfter(child)) {
      result = math.max(result, extent(child));
    }
    return result;
  }

  @override
  double computeMinIntrinsicWidth(double height) => (_leading?.getMinIntrinsicWidth(height) ?? 0) + _editorMinimum + _trailingBleed;
  @override
  double computeMaxIntrinsicWidth(double height) => _sum((child) => child.getMaxIntrinsicWidth(height)) + _trailingBleed;
  @override
  double computeMinIntrinsicHeight(double width) => _max((child) => child.getMinIntrinsicHeight(width));
  @override
  double computeMaxIntrinsicHeight(double width) => _max((child) => child.getMaxIntrinsicHeight(width));
  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) => defaultComputeDistanceToHighestActualBaseline(baseline);

  // The widths of leading, trailing and editor for [width], laid out or dry.
  (double, double, double) _widths(
    BoxConstraints constraints,
    Size Function(RenderBox child, BoxConstraints constraints) layout,
    bool Function(_RenderTrailingFit trailing, BoxConstraints constraints) endsOnIcon,
  ) {
    final width = constraints.maxWidth;
    final loose = BoxConstraints(maxHeight: constraints.maxHeight);
    final leading = _leading == null ? 0.0 : layout(_leading!, loose).width;
    final trailingConstraints = loose.copyWith(maxWidth: math.max(0.0, width - leading - _editorMinimum - _trailingBleed));
    final trailing = layout(_trailing, trailingConstraints).width;
    final box = _trailing;
    final bleed = box is _RenderTrailingFit && endsOnIcon(box, trailingConstraints) ? math.min(trailing, _trailingBleed) : 0.0;
    return (leading, trailing, math.max(0.0, width - leading - trailing - (_trailingBleed - bleed)));
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final (_, _, editor) = _widths(constraints, (child, constraints) => child.getDryLayout(constraints), (trailing, constraints) => trailing.dryEndsOnIcon(constraints));
    final editorSize = _editor.getDryLayout(BoxConstraints(minWidth: editor, maxWidth: editor, maxHeight: constraints.maxHeight));
    final height = math.max(
      editorSize.height,
      _max((child) => child == _editor ? 0 : child.getDryLayout(BoxConstraints(maxHeight: constraints.maxHeight)).height),
    );
    return constraints.constrain(Size(constraints.maxWidth, height));
  }

  @override
  void performLayout() {
    final (_, _, editor) = _widths(constraints, (child, constraints) {
      child.layout(constraints, parentUsesSize: true);
      return child.size;
    }, (trailing, _) => trailing.endsOnIcon);
    _editor.layout(BoxConstraints(minWidth: editor, maxWidth: editor, maxHeight: constraints.maxHeight), parentUsesSize: true);
    size = constraints.constrain(Size(constraints.maxWidth, _max((child) => child.size.height)));
    final rtl = _textDirection == TextDirection.rtl;
    var x = 0.0;
    for (var child = firstChild; child != null; child = childAfter(child)) {
      final y = _top ? 0.0 : (size.height - child.size.height) / 2;
      (child.parentData! as _FieldRowParentData).offset = Offset(rtl ? size.width - x - child.size.width : x, y);
      x += child.size.width;
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) => defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) => defaultHitTestChildren(result, position: position);
}

/// Trailing field controls in priority order. Those that do not fit the
/// width the field leaves them are dropped from the end: not painted, hit,
/// announced or focusable. A nested [FrostFieldTrailing] gets the remaining
/// width and drops its own last controls first.
class FrostFieldTrailing extends StatefulWidget {
  const FrostFieldTrailing({required this.children, super.key});
  final List<Widget> children;
  @override
  State<FrostFieldTrailing> createState() => _FrostFieldTrailingState();
}

class _FrostFieldTrailingState extends State<FrostFieldTrailing> {
  int? _shown;

  // Layout cannot rebuild; focus follows on the next frame. Hidden controls
  // already ignore pointers and semantics in that frame.
  void _fitted(int shown) {
    if (shown == (_shown ?? widget.children.length)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _shown = shown);
    });
  }

  @override
  Widget build(BuildContext context) => FrostFieldIconScope(
    child: _TrailingFit(
      onFitted: _fitted,
      children: [for (final (index, child) in widget.children.indexed) ExcludeFocus(excluding: index >= (_shown ?? widget.children.length), child: child)],
    ),
  );
}

class _TrailingFit extends MultiChildRenderObjectWidget {
  const _TrailingFit({required this.onFitted, required super.children});
  final ValueChanged<int> onFitted;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderTrailingFit(onFitted, Directionality.of(context));

  @override
  void updateRenderObject(BuildContext context, _RenderTrailingFit renderObject) => renderObject
    ..onFitted = onFitted
    ..textDirection = Directionality.of(context);
}

class _RenderTrailingFit extends RenderBox
    with ContainerRenderObjectMixin<RenderBox, _FieldRowParentData>, RenderBoxContainerDefaultsMixin<RenderBox, _FieldRowParentData> {
  _RenderTrailingFit(this.onFitted, this._textDirection);

  ValueChanged<int> onFitted;
  int _shown = 0;

  /// Whether the last control with any width was an icon button in the latest
  /// layout. The row reads it right after laying this out.
  bool endsOnIcon = false;

  /// [endsOnIcon] for a layout under [constraints] that is not performed.
  bool dryEndsOnIcon(BoxConstraints constraints) {
    final (shown, sizes) = _fit(constraints, (child, constraints) => child.getDryLayout(constraints));
    return _lastIsIcon(shown, sizes, (child, remaining) => child.dryEndsOnIcon(BoxConstraints(maxWidth: remaining, maxHeight: constraints.maxHeight)), constraints.maxWidth);
  }

  bool _lastIsIcon(int shown, List<Size> sizes, bool Function(_RenderTrailingFit child, double remaining) nested, double width) {
    var remaining = width, result = false, index = 0;
    for (final child in _children.take(shown)) {
      final data = child.parentData! as _FieldRowParentData;
      if (sizes[index].width > 0 && !data.hint) result = child is _RenderTrailingFit ? nested(child, remaining) : data.icon;
      remaining -= sizes[index].width;
      index++;
    }
    return result;
  }

  TextDirection _textDirection;
  set textDirection(TextDirection value) {
    if (value == _textDirection) return;
    _textDirection = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _FieldRowParentData) child.parentData = _FieldRowParentData();
  }

  Iterable<RenderBox> get _children sync* {
    for (var child = firstChild; child != null; child = childAfter(child)) {
      yield child;
    }
  }

  @override
  double computeMinIntrinsicWidth(double height) => 0;
  @override
  double computeMaxIntrinsicWidth(double height) => _children.fold(0.0, (sum, child) => sum + child.getMaxIntrinsicWidth(height));
  @override
  double computeMinIntrinsicHeight(double width) => _children.fold(0.0, (high, child) => math.max(high, child.getMinIntrinsicHeight(double.infinity)));
  @override
  double computeMaxIntrinsicHeight(double width) => _children.fold(0.0, (high, child) => math.max(high, child.getMaxIntrinsicHeight(double.infinity)));

  // Children in order while they fit; a nested trailing group shrinks to fit.
  (int, List<Size>) _fit(BoxConstraints constraints, Size Function(RenderBox child, BoxConstraints constraints) layout) {
    final sizes = <Size>[];
    var remaining = constraints.maxWidth, shown = 0, fits = true;
    for (final child in _children) {
      final nested = child is _RenderTrailingFit;
      final size = layout(child, BoxConstraints(maxWidth: nested && remaining.isFinite ? remaining : double.infinity, maxHeight: constraints.maxHeight));
      sizes.add(size);
      fits = fits && size.width <= remaining + precisionErrorTolerance;
      if (!fits) continue;
      remaining -= size.width;
      shown++;
    }
    return (shown, sizes);
  }

  Size _size(BoxConstraints constraints, int shown, List<Size> sizes) {
    var width = 0.0, height = 0.0;
    for (final size in sizes.take(shown)) {
      width += size.width;
      height = math.max(height, size.height);
    }
    return constraints.constrain(Size(width, height));
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final (shown, sizes) = _fit(constraints, (child, constraints) => child.getDryLayout(constraints));
    return _size(constraints, shown, sizes);
  }

  @override
  void performLayout() {
    final (shown, sizes) = _fit(constraints, (child, constraints) {
      child.layout(constraints, parentUsesSize: true);
      return child.size;
    });
    _shown = shown;
    endsOnIcon = _lastIsIcon(shown, sizes, (child, _) => child.endsOnIcon, constraints.maxWidth);
    size = _size(constraints, shown, sizes);
    var x = 0.0;
    void place(RenderBox child, double width) {
      final y = (size.height - child.size.height) / 2;
      (child.parentData! as _FieldRowParentData).offset = Offset(_textDirection == TextDirection.rtl ? size.width - x - width : x, y);
      x += width;
    }

    bool isHint(RenderBox child) => (child.parentData! as _FieldRowParentData).hint;
    for (final (index, child) in _children.indexed) {
      if (isHint(child)) place(child, index < shown ? child.size.width : 0.0);
    }
    for (final (index, child) in _children.indexed) {
      if (!isHint(child)) place(child, index < shown ? child.size.width : 0.0);
    }
    onFitted(shown);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    for (final child in _children.take(_shown)) {
      context.paintChild(child, (child.parentData! as _FieldRowParentData).offset + offset);
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    for (final child in _children.take(_shown).toList().reversed) {
      final offset = (child.parentData! as _FieldRowParentData).offset;
      if (result.addWithPaintOffset(
        offset: offset,
        position: position,
        hitTest: (result, position) => child.hitTest(result, position: position),
      )) {
        return true;
      }
    }
    return false;
  }

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) => _children.take(_shown).forEach(visitor);
}
