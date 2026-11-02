import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Library-only: a LayoutBuilder whose child exists before its first layout, so
/// it can answer intrinsic and dry-layout queries from its real content. The
/// first build uses the window as its constraints; layout rebuilds with the real
/// ones in the same frame, as LayoutBuilder does. Use it where a different guess
/// changes values but not the height of the content.
class FrostEagerLayoutBuilder extends RenderObjectWidget {
  const FrostEagerLayoutBuilder({required this.builder, super.key});
  final Widget Function(BuildContext context, BoxConstraints constraints) builder;

  @override
  RenderObjectElement createElement() => _EagerElement(this);
  @override
  RenderObject createRenderObject(BuildContext context) => _RenderEager();
}

class _EagerElement extends RenderObjectElement {
  _EagerElement(FrostEagerLayoutBuilder super.widget) : _builder = widget.builder;
  Widget Function(BuildContext context, BoxConstraints constraints) _builder;

  @override
  _RenderEager get renderObject => super.renderObject as _RenderEager;

  Element? _child;
  late BoxConstraints _constraints;

  @override
  BuildScope get buildScope => _scope;
  late final BuildScope _scope = BuildScope(scheduleRebuild: _scheduleRebuild);

  // Dirty descendants are rebuilt in this box's layout, which must be scheduled
  // outside the phases where the render tree has to stay clean.
  bool _deferred = false;
  void _scheduleRebuild() {
    if (_deferred) return;
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase != SchedulerPhase.idle && phase != SchedulerPhase.postFrameCallbacks) {
      renderObject.scheduleLayoutCallback();
      return;
    }
    _deferred = true;
    SchedulerBinding.instance.scheduleFrameCallback((_) {
      _deferred = false;
      if (mounted) renderObject.scheduleLayoutCallback();
    });
  }

  Widget _content() {
    final builder = _builder, constraints = _constraints;
    return Builder(builder: (context) => builder(context, constraints));
  }

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
    renderObject.onLayout = _layout;
    // Read without a dependency: real constraints replace this before the first paint.
    final window = getElementForInheritedWidgetOfExactType<MediaQuery>()?.widget as MediaQuery?;
    _constraints = BoxConstraints.loose(window?.data.size ?? Size.infinite);
    _child = updateChild(null, _content(), null);
  }

  @override
  void update(FrostEagerLayoutBuilder newWidget) {
    super.update(newWidget);
    _builder = newWidget.builder;
    _child = updateChild(_child, _content(), null);
  }

  @override
  void unmount() {
    renderObject.onLayout = null;
    super.unmount();
  }

  void _layout(BoxConstraints constraints) {
    final changed = constraints != _constraints;
    owner!.buildScope(
      this,
      changed
          ? () {
              _constraints = constraints;
              _child = updateChild(_child, _content(), null);
            }
          : null,
    );
  }

  @override
  void insertRenderObjectChild(RenderBox child, Object? slot) => renderObject.child = child;
  @override
  void moveRenderObjectChild(RenderBox child, Object? oldSlot, Object? newSlot) {}
  @override
  void removeRenderObjectChild(RenderBox child, Object? slot) => renderObject.child = null;
}

class _RenderEager extends RenderProxyBox with RenderObjectWithLayoutCallbackMixin {
  void Function(BoxConstraints constraints)? onLayout;

  @override
  void layoutCallback() => onLayout?.call(constraints);

  @override
  void performLayout() {
    runLayoutCallback();
    super.performLayout();
  }
}
