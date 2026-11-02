import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../motion/_layout_identity.dart';
import '../motion/layout_crossfade.dart';

/// Chooses the first candidate whose natural width fits, or the last fallback.
/// Candidates need finite natural widths (for example shrink-wrapped rows).
/// All candidates stay mounted; inactive candidates cannot receive input, focus
/// or semantics and their tickers are paused. Each candidate has a single mounted subtree,
/// avoiding a second live copy of its controllers or focus nodes.
class FrostFit extends StatefulWidget {
  const FrostFit({required this.candidates, super.key}) : assert(candidates.length > 0);
  final List<WidgetBuilder> candidates;
  @override
  State<FrostFit> createState() => _FitState();
}

class _FitState extends State<FrostFit> {
  final _identity = FrostLayoutIdentity();
  final _focusScopes = <FocusNode>[];
  int _shown = 0;

  FocusNode _focusScope(int index) {
    while (_focusScopes.length <= index) {
      final current = _focusScopes.length == _shown;
      _focusScopes.add(FocusNode(canRequestFocus: false, skipTraversal: true, descendantsAreFocusable: current, descendantsAreTraversable: current));
    }
    return _focusScopes[index];
  }

  // Layout has already painted and hit-tested the right candidate. Focus leaves
  // the others as this frame ends, before any pending autofocus applies; their
  // tickers stop on the next frame.
  void _selected(int index) {
    if (index == _shown) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || index == _shown) return;
      for (final (candidate, scope) in _focusScopes.indexed) {
        scope
          ..descendantsAreFocusable = candidate == index
          ..descendantsAreTraversable = candidate == index;
      }
      setState(() => _shown = index);
    });
  }

  @override
  void dispose() {
    _identity.dispose();
    for (final scope in _focusScopes) {
      scope.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FrostLayoutCrossfade(
    layoutIdentity: _identity,
    child: _FitLayout(
      identity: _identity,
      direction: Directionality.of(context),
      onSelected: _selected,
      children: [
        for (final (index, builder) in widget.candidates.indexed)
          Focus.withExternalFocusNode(
            focusNode: _focusScope(index),
            includeSemantics: false,
            child: TickerMode(
              enabled: index == _shown,
              child: Builder(builder: builder),
            ),
          ),
      ],
    ),
  );
}

class _FitData extends ContainerBoxParentData<RenderBox> {}

class _FitLayout extends MultiChildRenderObjectWidget {
  const _FitLayout({required this.identity, required this.direction, required this.onSelected, required super.children});
  final FrostLayoutIdentity identity;
  final TextDirection direction;
  final ValueChanged<int> onSelected;
  @override
  RenderObject createRenderObject(BuildContext context) => _RenderFit(this);
  @override
  void updateRenderObject(BuildContext context, _RenderFit renderObject) {
    renderObject.config = this;
    renderObject.markNeedsLayout();
  }
}

class _RenderFit extends RenderBox with ContainerRenderObjectMixin<RenderBox, _FitData>, RenderBoxContainerDefaultsMixin<RenderBox, _FitData> {
  _RenderFit(this.config);
  _FitLayout config;
  RenderBox? _visible;
  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _FitData) child.parentData = _FitData();
  }

  RenderBox _fitting(double width) {
    final items = getChildrenAsList();
    return items.firstWhere((child) => child.getMaxIntrinsicWidth(double.infinity) <= width, orElse: () => items.last);
  }

  @override
  void performLayout() {
    final items = getChildrenAsList();
    var selected = items.length - 1;
    var found = false;
    for (var index = 0; index < items.length; index++) {
      final child = items[index];
      child.layout(BoxConstraints(maxHeight: constraints.maxHeight), parentUsesSize: true);
      if (!found && child.size.width <= constraints.maxWidth) {
        selected = index;
        found = true;
      }
    }
    config.identity.update(selected, viewport: constraints);
    if (!identical(_visible, items[selected])) markNeedsSemanticsUpdate();
    _visible = items[selected]..layout(constraints, parentUsesSize: true);
    config.onSelected(selected);
    size = constraints.constrain(_visible!.size);
    (_visible!.parentData! as _FitData).offset = Offset(config.direction == TextDirection.ltr ? 0 : size.width - _visible!.size.width, 0);
  }

  @override
  double computeMinIntrinsicWidth(double height) => lastChild!.getMinIntrinsicWidth(height);
  @override
  double computeMaxIntrinsicWidth(double height) => firstChild!.getMaxIntrinsicWidth(height);
  @override
  double computeMinIntrinsicHeight(double width) => _fitting(width).getMinIntrinsicHeight(width);
  @override
  double computeMaxIntrinsicHeight(double width) => _fitting(width).getMaxIntrinsicHeight(width);
  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.constrain(_fitting(constraints.maxWidth).getDryLayout(constraints));

  @override
  void paint(PaintingContext context, Offset offset) {
    if (_visible case final child?) context.paintChild(child, offset + (child.parentData! as _FitData).offset);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final child = _visible;
    if (child == null) return false;
    return result.addWithPaintOffset(
      offset: (child.parentData! as _FitData).offset,
      position: position,
      hitTest: (result, position) => child.hitTest(result, position: position),
    );
  }

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    if (_visible case final child?) visitor(child);
  }
}
