part of 'picker.dart';

class _AutoPicker<T> extends _PickerImpl<T> {
  const _AutoPicker(super.picker);
  @override
  State<_PickerImpl<T>> createState() => _AutoPickerState<T>();
}

/// Palettes for colour options and menus in rows, past four options or with
/// subtitles; otherwise segments while their measured layout fits, else a menu.
/// The state outlives the switch between segments and menu.
class _AutoPickerState<T> extends State<_PickerImpl<T>> with _PickerGroupFocus<T>, _PickerSegmentThumb<T>, _PickerField<T> {
  final _identity = FrostLayoutIdentity();
  final _layout = _PickerLayoutHandle();
  FocusNode? _menuFocus;
  @override
  FocusNode? get _focusTarget => _layout.style == FrostPickerStyle.menu ? _menuFocus : _groupFocus;

  @override
  void dispose() {
    _identity.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final options = widget.picker.options;
    var style = FrostPickerStyle.auto;
    if (FrostPickerRowScope.of(context) || options.isEmpty) {
      style = FrostPickerStyle.menu;
    } else if (options.every((option) => option.color != null)) {
      style = FrostPickerStyle.palette;
    } else if (options.length > 4 || options.any((option) => option.subtitle != null)) {
      style = FrostPickerStyle.menu;
    }
    if (style != FrostPickerStyle.auto) _layout.style = style;
    return FrostControlScope(
      size: widget.picker.size,
      child: style == FrostPickerStyle.auto
          ? FrostLayoutCrossfade(
              layoutIdentity: _identity,
              child: _PickerAutoLayout(
                identity: _identity,
                handle: _layout,
                direction: Directionality.of(context),
                children: [
                  ExcludeFocus(
                    child: ExcludeSemantics(
                      child: TickerMode(
                        enabled: false,
                        child: _AutoPickerBody<T>(owner: this, style: FrostPickerStyle.segmented, measurement: true),
                      ),
                    ),
                  ),
                  LayoutBuilder(
                    builder: (context, constraints) => _AutoPickerBody<T>(owner: this, style: (constraints as _PickerConstraints).style),
                  ),
                ],
              ),
            )
          : _AutoPickerBody<T>(owner: this, style: style),
    );
  }
}

/// The resolved style's body: segments, a palette or a menu trigger.
class _AutoPickerBody<T> extends StatelessWidget {
  const _AutoPickerBody({required this.owner, required this.style, this.measurement = false});
  final _AutoPickerState<T> owner;
  final FrostPickerStyle style;
  final bool measurement;
  @override
  Widget build(BuildContext context) => switch (style) {
    FrostPickerStyle.segmented => _PickerGroupField<T>(
      owner: owner,
      measurement: measurement,
      child: _PickerSegments<T>(owner: owner, measurement: measurement),
    ),
    FrostPickerStyle.palette => _PickerGroupField<T>(
      owner: owner,
      child: _PickerPalette<T>(owner: owner),
    ),
    _ => _PickerMenu<T>(picker: owner.widget.picker, enabled: owner._enabled, onFocus: (focus) => owner._menuFocus = focus),
  };
}

class _PickerLayoutHandle {
  FrostPickerStyle style = FrostPickerStyle.menu;
}

class _PickerConstraints extends BoxConstraints {
  _PickerConstraints(BoxConstraints original, this.style)
    : super(minWidth: original.minWidth, maxWidth: original.maxWidth, minHeight: original.minHeight, maxHeight: original.maxHeight);
  final FrostPickerStyle style;
  @override
  bool operator ==(Object other) => other is _PickerConstraints && super == other && style == other.style;
  @override
  int get hashCode => Object.hash(super.hashCode, style);
}

class _PickerParentData extends ContainerBoxParentData<RenderBox> {}

class _PickerAutoLayout extends MultiChildRenderObjectWidget {
  const _PickerAutoLayout({required this.identity, required this.handle, required this.direction, required super.children});
  final FrostLayoutIdentity identity;
  final _PickerLayoutHandle handle;
  final TextDirection direction;
  @override
  RenderObject createRenderObject(BuildContext context) => _RenderPickerAuto(this);
  @override
  void updateRenderObject(BuildContext context, _RenderPickerAuto renderObject) {
    renderObject.config = this;
    renderObject.markNeedsLayout();
  }
}

class _RenderPickerAuto extends RenderBox
    with ContainerRenderObjectMixin<RenderBox, _PickerParentData>, RenderBoxContainerDefaultsMixin<RenderBox, _PickerParentData> {
  _RenderPickerAuto(this.config);
  _PickerAutoLayout config;
  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _PickerParentData) child.parentData = _PickerParentData();
  }

  @override
  void performLayout() {
    // The measuring copy answers with its natural width, then stays within the
    // room there is, so it holds no text past the edge of the window.
    final natural = firstChild!.getMaxIntrinsicWidth(constraints.maxHeight);
    firstChild!.layout(BoxConstraints(maxWidth: math.min(natural, constraints.maxWidth), maxHeight: constraints.maxHeight));
    final style = natural <= constraints.maxWidth ? FrostPickerStyle.segmented : FrostPickerStyle.menu;
    config.handle.style = style;
    config.identity.update(style, viewport: constraints);
    lastChild!.layout(_PickerConstraints(constraints, style), parentUsesSize: true);
    size = constraints.constrain(lastChild!.size);
    (lastChild!.parentData! as _PickerParentData).offset = Offset(config.direction == TextDirection.ltr ? 0 : size.width - lastChild!.size.width, 0);
  }

  @override
  double computeMaxIntrinsicWidth(double height) => firstChild!.getMaxIntrinsicWidth(height);
  @override
  double computeMinIntrinsicWidth(double height) => 0;
  @override
  double computeMaxIntrinsicHeight(double width) => firstChild!.getMaxIntrinsicHeight(width);
  @override
  double computeMinIntrinsicHeight(double width) => computeMaxIntrinsicHeight(width);
  @override
  void paint(PaintingContext context, Offset offset) => context.paintChild(lastChild!, offset + (lastChild!.parentData! as _PickerParentData).offset);
  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final data = lastChild!.parentData! as _PickerParentData;
    return result.addWithPaintOffset(
      offset: data.offset,
      position: position,
      hitTest: (result, transformed) => lastChild!.hitTest(result, position: transformed),
    );
  }

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) => visitor(lastChild!);
}
