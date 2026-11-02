import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Bounds shared by modal routes and anchored panels; owns no route or storage.
class FrostOverlayBounds extends ChangeNotifier {
  Rect? _rect;
  FrostOverlayBounds? _parent;
  Rect? get globalRect {
    final parent = _parent?.globalRect;
    return _rect == null
        ? parent
        : parent == null
        ? _rect
        : _rect!.intersect(parent);
  }

  void setParent(FrostOverlayBounds? parent) {
    if (_parent == parent) return;
    _parent?.removeListener(notifyListeners);
    _parent = parent;
    _parent?.addListener(notifyListeners);
  }

  void update(Rect value) {
    if (_rect == value) return;
    _rect = value;
    notifyListeners();
  }

  Rect inOverlay(RenderBox overlay) {
    final full = Offset.zero & overlay.size;
    final global = globalRect;
    if (global == null) return full;
    return Rect.fromPoints(overlay.globalToLocal(global.topLeft), overlay.globalToLocal(global.bottomRight)).intersect(full);
  }

  @override
  void dispose() {
    _parent?.removeListener(notifyListeners);
    super.dispose();
  }
}

class FrostOverlayRegionData extends InheritedNotifier<FrostOverlayBounds> {
  const FrostOverlayRegionData({required FrostOverlayBounds bounds, required super.child, super.key}) : super(notifier: bounds);
  static FrostOverlayBounds? maybeOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<FrostOverlayRegionData>()?.notifier;
}

class FrostOverlayRegionGeometry extends SingleChildRenderObjectWidget {
  const FrostOverlayRegionGeometry({required this.onChanged, required super.child, super.key});
  final ValueChanged<Rect> onChanged;
  @override
  RenderObject createRenderObject(BuildContext context) => _RegionRenderBox(onChanged);
  @override
  void updateRenderObject(BuildContext context, covariant RenderObject renderObject) => (renderObject as _RegionRenderBox).onChanged = onChanged;
}

class _RegionRenderBox extends RenderProxyBox {
  _RegionRenderBox(this.onChanged);
  ValueChanged<Rect> onChanged;
  Rect? _reported;
  bool _queued = false;
  @override
  void paint(PaintingContext context, Offset offset) {
    super.paint(context, offset);
    final rect = MatrixUtils.transformRect(getTransformTo(null), Offset.zero & size);
    if (_reported == rect || _queued) return;
    _queued = true;
    // Report after global geometry is established, never write ancestor state
    // from layout/paint. Overlay routes repaint against the same retained page.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _queued = false;
      if (!attached) return;
      _reported = MatrixUtils.transformRect(getTransformTo(null), Offset.zero & size);
      onChanged(_reported!);
    });
  }
}

/// Places both a modal barrier and its content inside the captured live region.
class FrostOverlayRegionViewport extends StatelessWidget {
  const FrostOverlayRegionViewport({required this.bounds, required this.overlay, required this.child, super.key});
  final FrostOverlayBounds bounds;
  final RenderBox Function() overlay;
  final Widget child;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: bounds,
    builder: (context, _) {
      final box = overlay();
      final rect = bounds.inOverlay(box);
      final media = MediaQuery.of(context);
      EdgeInsets local(EdgeInsets value) => EdgeInsets.fromLTRB(
        math.max(0, value.left - rect.left),
        math.max(0, value.top - rect.top),
        math.max(0, value.right - (box.size.width - rect.right)),
        math.max(0, value.bottom - (box.size.height - rect.bottom)),
      );
      return CustomSingleChildLayout(
        delegate: _RegionLayout(rect),
        child: ClipRect(
          child: MediaQuery(
            data: media.copyWith(size: rect.size, padding: local(media.padding), viewPadding: local(media.viewPadding), viewInsets: local(media.viewInsets)),
            child: FrostOverlayRegionData(bounds: bounds, child: child),
          ),
        ),
      );
    },
  );
}

class _RegionLayout extends SingleChildLayoutDelegate {
  const _RegionLayout(this.rect);
  final Rect rect;
  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) => BoxConstraints.tight(rect.size);
  @override
  Offset getPositionForChild(Size size, Size childSize) => rect.topLeft;
  @override
  bool shouldRelayout(_RegionLayout oldDelegate) => rect != oldDelegate.rect;
}
