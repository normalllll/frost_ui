import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:frost_ui/src/foundation/metrics.dart';

/// Reflows a single live subtree, then fades its outgoing pixels away.
///
/// Only a discrete layout identity captures a frame. Resizing within the same
/// layout never starts an animation. The snapshot has no state, focus, Heroes or
/// resource subscriptions; all input continues to the newly laid out child.
class FrostLayoutCrossfade extends StatefulWidget {
  const FrostLayoutCrossfade({
    required this.layoutIdentity,
    required this.child,
    this.duration = FrostMotion.layoutFade,
    this.settleDuration = const Duration(milliseconds: 100),
    super.key,
  });
  final Object layoutIdentity;
  final Widget child;
  final Duration duration;
  final Duration settleDuration;
  @override
  State<FrostLayoutCrossfade> createState() => _FrostLayoutCrossfadeState();
}

class _FrostLayoutCrossfadeState extends State<FrostLayoutCrossfade> with SingleTickerProviderStateMixin {
  final GlobalKey _boundary = GlobalKey();
  late final AnimationController _fade = AnimationController(vsync: this, duration: widget.duration)
    ..addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) setState(_release);
    });
  ui.Image? _outgoing;
  Timer? _settle;
  Size? _size;
  @override
  void didUpdateWidget(FrostLayoutCrossfade oldWidget) {
    super.didUpdateWidget(oldWidget);
    _fade.duration = widget.duration;
    if (oldWidget.layoutIdentity == widget.layoutIdentity) return;
    _settle?.cancel();
    _fade.stop();
    if (MediaQuery.disableAnimationsOf(context)) {
      _release();
      return;
    }
    final boundary = _boundary.currentContext?.findRenderObject();
    ui.Image? frame;
    if (boundary is _SnapshotRenderBoundary && boundary.hasSize && !boundary.size.isEmpty) {
      // One logical pixel per sample bounds memory independently of the display
      // density. It lives only through resize settling plus the 180 ms fade.
      // Capture the last painted layer even if input/resize has already marked
      // the live render tree dirty. Repainting it now would capture the new
      // geometry instead of the outgoing frame.
      frame = boundary.captureLastFrame();
    }
    _release();
    _outgoing = frame;
    if (frame != null) {
      _fade.value = 0;
      _scheduleFade();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _settle?.cancel();
      _fade.stop();
      _release();
    }
  }

  void _scheduleFade() {
    _settle?.cancel();
    // Finish resizing first; per-pixel changes only postpone this one fade.
    _settle = Timer(widget.settleDuration, () {
      if (mounted && _outgoing != null) _fade.forward();
    });
  }

  void _release() {
    _outgoing?.dispose();
    _outgoing = null;
  }

  @override
  void dispose() {
    _settle?.cancel();
    _fade.dispose();
    _release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _SnapshotBoundary(
    key: _boundary,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        if (_size != size && _outgoing != null) _scheduleFade();
        _size = size;
        return Stack(
          fit: StackFit.passthrough,
          children: [
            RepaintBoundary(child: widget.child),
            if (_outgoing case final image?)
              Positioned.fill(
                child: IgnorePointer(
                  child: ExcludeSemantics(
                    child: FadeTransition(
                      opacity: ReverseAnimation(_fade),
                      child: RawImage(image: image, fit: BoxFit.fill),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    ),
  );
}

class _SnapshotBoundary extends RepaintBoundary {
  const _SnapshotBoundary({required super.child, super.key});
  @override
  RenderRepaintBoundary createRenderObject(BuildContext context) => _SnapshotRenderBoundary();
}

class _SnapshotRenderBoundary extends RenderRepaintBoundary {
  ui.Image? captureLastFrame() => switch (layer) {
    final OffsetLayer painted => painted.toImageSync(Offset.zero & size),
    _ => null,
  };
}

/// [AnimatedSize] that resizes at once with reduced motion.
class FrostMotionSize extends StatelessWidget {
  const FrostMotionSize({required this.duration, required this.child, this.alignment = Alignment.center, this.curve = Curves.linear, super.key});

  final Duration duration;
  final Widget child;
  final AlignmentGeometry alignment;
  final Curve curve;

  @override
  Widget build(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context) ? child : AnimatedSize(duration: duration, alignment: alignment, curve: curve, child: child);
}
