import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' show Theme;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '_focus_modality.dart';
import 'density.dart';
import 'sizes.dart';

final _targets = <RenderFrostTouchTarget>{};

/// Whether the pointer being hit-tested is a finger, as far as is known: the
/// latest pointer was one, or none has come yet on a device built for touch.
bool frostExpectsFinger({required bool touchDevice}) => FrostInputModality.instance.touch || touchDevice && FrostInputModality.instance.noPointerYet;

/// Registers a pointer-sized control for a touch-sized hit region, which changes
/// neither its layout nor its visuals. [enabled] is false for a control that can
/// not be activated, or whose own target already follows touch sizes.
class FrostTouchTarget extends StatelessWidget {
  const FrostTouchTarget({required this.enabled, required this.child, super.key});
  final bool enabled;
  final Widget child;

  @override
  Widget build(BuildContext context) => _TouchTargetBox(enabled: enabled, route: ModalRoute.of<Object?>(context), child: child);
}

class _TouchTargetBox extends SingleChildRenderObjectWidget {
  const _TouchTargetBox({required this.enabled, required this.route, required super.child});
  final bool enabled;
  final ModalRoute<Object?>? route;

  @override
  RenderObject createRenderObject(BuildContext context) => RenderFrostTouchTarget(enabled)..route = route;

  @override
  void updateRenderObject(BuildContext context, RenderFrostTouchTarget renderObject) => renderObject
    ..enabled = enabled
    ..route = route;
}

class RenderFrostTouchTarget extends RenderProxyBox {
  RenderFrostTouchTarget(this._enabled);
  bool _enabled;
  set enabled(bool value) {
    if (_enabled == value) return;
    _enabled = value;
    _sync();
  }

  ModalRoute<Object?>? route;

  /// A control on a route that something covers, or one still leaving, takes
  /// no touches meant for what is on top.
  bool get _onCurrentRoute => route?.isCurrent ?? true;

  void _sync() => attached && _enabled ? _targets.add(this) : _targets.remove(this);

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _sync();
  }

  @override
  void detach() {
    _targets.remove(this);
    super.detach();
  }
}

/// Above every route: while the latest pointer is a finger, a touch just outside
/// a registered control counts as a touch on its nearest edge, as long as nothing
/// else wanted that point. Whatever listens at the original point and is not
/// around the control keeps the touch, and so does whatever covers the control.
/// The first touch after a mouse hits the visual size: hit testing runs before
/// the pointer's kind is recorded. On a device whose baseline input is touch,
/// the very first pointer counts as a finger.
class FrostTouchTargetRoot extends SingleChildRenderObjectWidget {
  const FrostTouchTargetRoot({required super.child, super.key});

  static bool _touchDevice(BuildContext context) => !(Theme.of(context).extension<FrostDensity>()?.usesPointer ?? true);

  @override
  RenderObject createRenderObject(BuildContext context) => RenderFrostTouchTargetRoot().._touchDevice = _touchDevice(context);

  @override
  void updateRenderObject(BuildContext context, RenderFrostTouchTargetRoot renderObject) => renderObject._touchDevice = _touchDevice(context);
}

class RenderFrostTouchTargetRoot extends RenderProxyBox {
  bool _touchDevice = false;

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) =>
      super.hitTest(result, position: frostExpectsFinger(touchDevice: _touchDevice) ? _redirect(position) : position);

  Offset _redirect(Offset position) {
    final minimum = FrostControlSize.minimumHitHeight(touch: true);
    final candidates = <({RenderFrostTouchTarget target, Offset edge, double away})>[];
    for (final target in _targets) {
      // Another view has its own owner and shares no coordinates with this one.
      if (!identical(target.owner, owner) || !target.hasSize || !target._onCurrentRoute) continue;
      if (target.size.width >= minimum && target.size.height >= minimum) continue;
      final bounds = MatrixUtils.transformRect(target.getTransformTo(this), Offset.zero & target.size);
      if (bounds.contains(position)) return position;
      final horizontal = bounds.width < minimum ? (minimum - bounds.width) / 2 : 0.0, vertical = bounds.height < minimum ? (minimum - bounds.height) / 2 : 0.0;
      if (!Rect.fromLTRB(bounds.left - horizontal, bounds.top - vertical, bounds.right + horizontal, bounds.bottom + vertical).contains(position)) continue;
      final edge = Offset(position.dx.clamp(bounds.left, bounds.right - .01), position.dy.clamp(bounds.top, bounds.bottom - .01));
      candidates.add((target: target, edge: edge, away: (edge - position).distanceSquared));
    }
    if (candidates.isEmpty) return position;
    candidates.sort((a, b) => a.away.compareTo(b.away));
    final direct = BoxHitTestResult();
    super.hitTest(direct, position: position);
    for (final candidate in candidates) {
      final probe = BoxHitTestResult();
      super.hitTest(probe, position: candidate.edge);
      final path = {for (final entry in probe.path) entry.target};
      if (path.contains(candidate.target) && _listeners(direct, candidate.target).every(path.contains)) return candidate.edge;
    }
    return position;
  }

  /// What wants a touch at the original point. A route's own modal barrier sits
  /// behind its page and catches every point the page leaves empty; unless it
  /// dismisses the route, a touch on it does nothing and it wants nothing. The
  /// path runs leaf first, and a barrier is the one thing that blocks semantics.
  List<HitTestTarget> _listeners(BoxHitTestResult direct, RenderFrostTouchTarget target) {
    final listeners = <HitTestTarget>[];
    for (final entry in direct.path) {
      if (entry.target is RenderPointerListener) listeners.add(entry.target);
      if (entry.target is RenderBlockSemantics && !(target.route?.barrierDismissible ?? false)) listeners.clear();
    }
    return listeners;
  }
}
