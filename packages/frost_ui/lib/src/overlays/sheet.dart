import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart' show DragStartBehavior, VelocityTracker;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

import '../foundation/metrics.dart';
import '../foundation/radius.dart';
import '../foundation/spacing.dart';
import '../foundation/tokens.dart';
import '../foundation/typography.dart';
import '../motion/_spring_simulation.dart';
import '../motion/spring.dart';
import '../primitives/surface.dart';
import '_modal_frame.dart';
import '_modal_route.dart';
import 'adaptive_panel.dart';
import 'dialogs.dart';

// Sheet handle geometry, compact detents and release thresholds.
const _handleWidth = 36.0;
const _handleHeight = 5.0;
const _handleTop = 6.0;
const _largeTopGap = 8.0;
const _mediumFraction = .5;
const _dismissFraction = .25;
const _flingVelocity = 200.0;
// A release only counts as a fling after the sheet itself has travelled this
// far, so a list thrown against its top does not carry the sheet away with it.
const _flingMinimumPull = 24.0;
// Fitted sheets stretch against a fixed bottom edge, without adding a detent.
const _fittedPullResistance = .2;
const _fittedMaximumStretch = 24.0;

enum FrostSheetPresentation { adaptive, bottom }

enum FrostSheetDetent { medium, large, fitted }

/// A fitted sheet adopts its content's natural layout height, capped at large.
/// With scrollable: false, a lazy viewport that cannot report a natural height
/// fills the available height, so fitted uses large and keeps the list lazy.
Future<T?> showFrostSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  String? title,
  FrostSheetPresentation presentation = FrostSheetPresentation.adaptive,
  List<FrostSheetDetent> detents = const [FrostSheetDetent.large],
  bool showsCloseButton = true,
  bool barrierDismissible = true,
  bool scrollable = true,
}) {
  assert(detents.isNotEmpty);
  assert(!detents.contains(FrostSheetDetent.fitted) || detents.toSet().length == 1);
  final sorted = detents.toSet().toList()..sort((a, b) => a.index.compareTo(b.index));
  if (presentation == FrostSheetPresentation.adaptive && !frostPanelUsesSheet(context)) {
    return showFrostDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (context) => FrostModalSurface(
        width: frostDialogWidth,
        child: _SheetFocus(
          builder: (contentFocus) => FrostModalFrame(
            header: title != null || showsCloseButton ? FrostModalHeader(title: title, role: FrostTextRole.headline, showsCloseButton: showsCloseButton) : null,
            scrollable: scrollable,
            content: FocusScope(
              node: contentFocus,
              child: Builder(builder: builder),
            ),
          ),
        ),
      ),
    );
  }
  return pushFrostModal<T>(
    context: context,
    bottomSheet: true,
    barrierDismissible: barrierDismissible,
    builder: (context) => _CompactSheet(builder: builder, title: title, detents: sorted, showsCloseButton: showsCloseButton, scrollable: scrollable),
  );
}

class _SheetFocus extends StatefulWidget {
  const _SheetFocus({required this.builder});
  final Widget Function(FocusScopeNode contentFocus) builder;
  @override
  State<_SheetFocus> createState() => _SheetFocusState();
}

class _SheetFocusState extends State<_SheetFocus> {
  final _focus = FocusScopeNode();
  final _contentFocus = FocusScopeNode();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // The sheet holds focus so Escape reaches it; a caller's autofocus wins.
      if (mounted && !_focus.hasFocus) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    _contentFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FocusScope(node: _focus, child: widget.builder(_contentFocus));
}

class _CompactSheet extends StatefulWidget {
  const _CompactSheet({required this.builder, required this.title, required this.detents, required this.showsCloseButton, required this.scrollable});
  final WidgetBuilder builder;
  final String? title;
  final List<FrostSheetDetent> detents;
  final bool showsCloseButton, scrollable;
  @override
  State<_CompactSheet> createState() => _CompactSheetState();
}

class _CompactSheetState extends State<_CompactSheet> with TickerProviderStateMixin {
  late final _height = AnimationController.unbounded(vsync: this);
  late final _keyboard = AnimationController.unbounded(vsync: this);
  late final _scroll = _SheetScrollController(this);
  CurvedAnimation? _entry;
  List<double> _heights = [];
  int _selected = 0;
  int _dragOrigin = 0;
  double _dragStart = 0;
  bool _dragging = false;
  final _fittedKey = GlobalKey();
  double _fittedPull = 0;
  VelocityTracker? _velocity;
  int? _dragPointer;

  void _trackPointer(PointerEvent event) {
    if (event is PointerDownEvent) {
      if (_dragging && event.pointer != _dragPointer) return;
      _dragPointer = event.pointer;
      _velocity = VelocityTracker.withKind(event.kind);
    }
    if (event.pointer == _dragPointer) _velocity?.addPosition(event.timeStamp, event.position);
  }

  double _releaseVelocity(double fallback) => _velocity?.getVelocityEstimate()?.pixelsPerSecond.dy ?? fallback;

  bool get _fitted => widget.detents.singleOrNull == FrostSheetDetent.fitted;
  double get _restingHeight => (_fittedKey.currentContext?.findRenderObject() as _RenderFittedSheetExtent?)?.restingHeight ?? _heights.first;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final media = MediaQuery.of(context);
    final available = math.max(0.0, media.size.height - media.viewInsets.bottom);
    final heights = [
      for (final detent in widget.detents)
        detent == FrostSheetDetent.medium ? available * _mediumFraction : math.max(0.0, available - media.padding.top - _largeTopGap),
    ];
    if (_heights.isEmpty) {
      if (!_fitted) _height.value = heights.first;
      _keyboard.value = media.viewInsets.bottom;
    } else if (_heights[_selected] != heights[_selected]) {
      _dragging = false;
      if (!_fitted) FrostMotion.springTo(context, _height, heights[_selected], FrostMotion.standard);
      FrostMotion.springTo(context, _keyboard, media.viewInsets.bottom, FrostMotion.standard);
    }
    _heights = heights;
    _entry ??= CurvedAnimation(
      parent: ModalRoute.of(context)!.animation!,
      curve: FrostSpringCurve(FrostMotion.standard, FrostMotion.standardDuration),
      reverseCurve: Curves.easeInCubic,
    );
  }

  void _startDrag() {
    if (_dragging) return;
    _dragging = true;
    _dragOrigin = _selected;
    _fittedPull = 0;
    _height.stop();
    _dragStart = _height.value;
  }

  void _dragBy(double delta) {
    _startDrag();
    if (_fitted) {
      _fittedPull += delta;
      final stretch = MediaQuery.disableAnimationsOf(context) ? 0.0 : math.min(-_fittedPull * _fittedPullResistance, _fittedMaximumStretch);
      _height.value = math.max(0, _restingHeight + (_fittedPull < 0 ? stretch : -_fittedPull));
      return;
    }
    _height.value = (_height.value - delta).clamp(0.0, _heights.last);
  }

  bool _scrollDrag(ScrollMetrics metrics, double delta) {
    if (!_dragging && (delta <= 0 || metrics.extentBefore > 0)) return false;
    _dragBy(delta);
    return true;
  }

  void _finishDrag(double velocity) {
    if (!_dragging) return;
    _dragging = false;
    if (!mounted) return;
    // Something opened above mid-drag: the release is not a request to leave.
    if (ModalRoute.of(context)?.isCurrent != true) {
      _settle(0);
      return;
    }
    final minimum = _fitted ? _restingHeight : _heights.first;
    // Only travel in the release's own direction makes it a fling.
    final pull = velocity > 0 ? _dragStart - _height.value : _height.value - _dragStart;
    final fling = pull >= _flingMinimumPull ? velocity : 0.0;
    final downwardFling = fling >= _flingVelocity && (!_fitted || _height.value <= minimum);
    if (_dragOrigin == 0 && (downwardFling || _height.value < minimum * (1 - _dismissFraction))) {
      // A PopScope or barrierDismissible can refuse; the sheet then springs back.
      final route = ModalRoute.of(context)!;
      unawaited(
        frostDismissModal(context).then((_) {
          // A refusal is reported as handled; the route staying active is what
          // says it was not popped.
          if (mounted && route.isActive) _settle(0);
        }),
      );
      return;
    }
    _settle(fling);
  }

  void _settle(double velocity) {
    if (_fitted) {
      if (MediaQuery.disableAnimationsOf(context)) {
        _height.value = _restingHeight;
      } else {
        // A capped stretch settles from its current extent; it does not carry
        // upward fling energy past the maximum stretch on release.
        final releaseVelocity = _height.value > _restingHeight ? 0.0 : -velocity;
        _height.animateWith(frostSpringSimulation(FrostMotion.standard, _height.value, _restingHeight, releaseVelocity));
      }
      return;
    }
    final lower = math.max(0, _dragOrigin - 1);
    final upper = math.min(_heights.length - 1, _dragOrigin + 1);
    if (velocity.abs() >= _flingVelocity) {
      _selected = velocity > 0 ? lower : upper;
    } else {
      _selected = lower;
      for (var index = lower + 1; index <= upper; index++) {
        if ((_height.value - _heights[index]).abs() < (_height.value - _heights[_selected]).abs()) _selected = index;
      }
    }
    if (MediaQuery.disableAnimationsOf(context)) {
      _height.value = _heights[_selected];
    } else {
      _height.animateWith(frostSpringSimulation(FrostMotion.standard, _height.value, _heights[_selected], -velocity));
    }
  }

  @override
  void dispose() {
    _height.dispose();
    _keyboard.dispose();
    _entry?.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final header = GestureDetector(
      behavior: HitTestBehavior.opaque,
      dragStartBehavior: DragStartBehavior.down,
      onVerticalDragStart: (_) => _startDrag(),
      onVerticalDragUpdate: (details) => _dragBy(details.delta.dy),
      onVerticalDragEnd: (details) => _finishDrag(_releaseVelocity(details.primaryVelocity ?? 0)),
      onVerticalDragCancel: () => _finishDrag(0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: _handleTop),
            child: Center(
              child: Container(
                width: _handleWidth,
                height: _handleHeight,
                decoration: BoxDecoration(color: FrostThemeTokens.of(context).fillStrong, borderRadius: BorderRadius.circular(_handleHeight / 2)),
              ),
            ),
          ),
          if (widget.title != null || widget.showsCloseButton) ...[
            const SizedBox(height: FrostGap.related),
            FrostModalHeader(title: widget.title, role: FrostTextRole.headline, showsCloseButton: widget.showsCloseButton),
          ],
        ],
      ),
    );
    final panel = Listener(
      // A resizing sheet moves its local coordinate space during the drag.
      // Release velocity must use stable logical screen coordinates instead.
      onPointerDown: _trackPointer,
      onPointerMove: _trackPointer,
      onPointerUp: _trackPointer,
      onPointerCancel: (event) {
        if (event.pointer == _dragPointer) {
          _dragPointer = null;
          _velocity = null;
        }
      },
      child: _SheetFocus(
        builder: (contentFocus) => FrostModalFrame(
          header: header,
          headerGap: widget.title != null || widget.showsCloseButton ? FrostGap.group : FrostGap.related,
          topInset: 0,
          bottomInset: frostModalInset + MediaQuery.paddingOf(context).bottom,
          scrollController: _scroll,
          scrollable: widget.scrollable,
          content: FocusScope(
            node: contentFocus,
            child: Builder(builder: widget.builder),
          ),
        ),
      ),
    );
    return AnimatedBuilder(
      animation: _fitted ? _keyboard : Listenable.merge([_height, _keyboard]),
      child: panel,
      builder: (context, panel) => Stack(
        children: [
          Positioned(
            bottom: _keyboard.value,
            left: 0,
            right: 0,
            child: SlideTransition(
              position: MediaQuery.disableAnimationsOf(context)
                  ? const AlwaysStoppedAnimation(Offset.zero)
                  : _entry!.drive(Tween(begin: const Offset(0, 1), end: Offset.zero)),
              child: _fitted
                  ? FrostSurface(
                      role: FrostSurfaceRole.sheet,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(FrostRadius.xl)),
                      child: _FittedSheetExtent(
                        key: _fittedKey,
                        animation: _height,
                        maximum: _heights.last,
                        reduced: MediaQuery.disableAnimationsOf(context),
                        dragging: () => _dragging,
                        child: panel!,
                      ),
                    )
                  : SizedBox(
                      height: math.max(0, _height.value),
                      child: FrostSurface(
                        role: FrostSurfaceRole.sheet,
                        borderRadius: BorderRadius.vertical(top: Radius.circular(FrostRadius.xl)),
                        // Below the first detent the content keeps that height and
                        // is clipped, rather than being squeezed into overflow.
                        child: ClipRect(
                          child: OverflowBox(
                            alignment: Alignment.topCenter,
                            minHeight: math.max(math.max(0.0, _height.value), _heights.first),
                            maxHeight: math.max(math.max(0.0, _height.value), _heights.first),
                            child: panel!,
                          ),
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Measures under the large cap before the first paint. Later natural-size
/// changes animate entirely in the render layer, without post-layout setState.
class _FittedSheetExtent extends SingleChildRenderObjectWidget {
  const _FittedSheetExtent({required this.animation, required this.maximum, required this.reduced, required this.dragging, required super.child, super.key});
  final AnimationController animation;
  final double maximum;
  final bool reduced;
  final bool Function() dragging;

  @override
  _RenderFittedSheetExtent createRenderObject(BuildContext context) => _RenderFittedSheetExtent(animation, maximum, reduced, dragging);

  @override
  void updateRenderObject(BuildContext context, _RenderFittedSheetExtent renderObject) => renderObject.update(maximum, reduced, dragging);
}

class _RenderFittedSheetExtent extends RenderProxyBox {
  _RenderFittedSheetExtent(this._animation, this._maximum, this._reduced, this._dragging);
  final AnimationController _animation;
  double _maximum;
  bool _reduced;
  bool Function() _dragging;
  double? _target;
  bool _settingExtent = false;
  int? _layoutFrame;
  double get restingHeight => _target ?? _maximum;

  void update(double maximum, bool reduced, bool Function() dragging) {
    _maximum = maximum;
    _reduced = reduced;
    _dragging = dragging;
    markNeedsLayout();
  }

  void _tick() {
    if (_settingExtent) return;
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.transientCallbacks) {
      markNeedsLayout();
    } else {
      // Several native mouse packets can arrive before the next frame. Keep
      // the last completed geometry valid for hit testing between packets.
      _layoutFrame ??= SchedulerBinding.instance.scheduleFrameCallback((_) {
        _layoutFrame = null;
        if (attached) markNeedsLayout();
      });
    }
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _animation.addListener(_tick);
  }

  @override
  void detach() {
    if (_layoutFrame case final frame?) SchedulerBinding.instance.cancelFrameCallbackWithId(frame);
    _layoutFrame = null;
    _animation.removeListener(_tick);
    super.detach();
  }

  @override
  void performLayout() {
    final naturalConstraints = BoxConstraints(minWidth: constraints.maxWidth, maxWidth: constraints.maxWidth, maxHeight: _maximum);
    child!.layout(naturalConstraints, parentUsesSize: true);
    final naturalHeight = child!.size.height;
    if (_target != naturalHeight) {
      final initial = _target == null;
      _target = naturalHeight;
      if (initial || _reduced) {
        _settingExtent = true;
        _animation.value = naturalHeight;
        _settingExtent = false;
      } else if (!_dragging()) {
        _animation.animateWith(frostSpringSimulation(FrostMotion.standard, _animation.value, naturalHeight, _animation.velocity));
      }
    }
    final height = math.max(0.0, _animation.value);
    // Content always keeps loose height constraints: tightening it would create
    // a relayout boundary and hide later content-size changes from this parent.
    // Dismissal pulls clip the natural content instead of overflowing Flex.
    size = constraints.constrain(Size(constraints.maxWidth, height));
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child!.size.height > size.height) {
      context.pushClipRect(needsCompositing, offset, Offset.zero & size, super.paint);
    } else {
      super.paint(context, offset);
    }
  }
}

/// Attached to the sheet's own scroll content and primary lists. Scroll
/// configuration stays the app's: the behavior and physics a list inherits run
/// unchanged, and only the offset the sheet takes never reaches them.
class _SheetScrollController extends ScrollController {
  _SheetScrollController(this.sheet);
  final _CompactSheetState sheet;

  // A list nested in scrolling content inherits this controller as well. Its
  // readers, the dividers and scrollbars, mean the view that attached first.
  @override
  Iterable<ScrollPosition> get positions => super.positions.take(1);
  @override
  ScrollPosition get position => super.positions.first;

  @override
  ScrollPosition createScrollPosition(ScrollPhysics physics, ScrollContext context, ScrollPosition? oldPosition) => _SheetScrollPosition(
    sheet: sheet,
    physics: physics,
    context: context,
    oldPosition: oldPosition,
    initialPixels: initialScrollOffset,
    keepScrollOffset: keepScrollOffset,
    debugLabel: debugLabel,
  );
}

class _SheetScrollPosition extends ScrollPositionWithSingleContext {
  _SheetScrollPosition({
    required this.sheet,
    required super.physics,
    required super.context,
    super.oldPosition,
    super.initialPixels,
    super.keepScrollOffset,
    super.debugLabel,
  });
  final _CompactSheetState sheet;
  bool _pulling = false;

  // A reversed list starts at the bottom: there a finger moving up is scrolling.
  bool get _pullsSheet => axis == Axis.vertical && !axisDirectionIsReversed(axisDirection);

  @override
  void applyNewDimensions() {
    super.applyNewDimensions();
    if (identical(sheet._scroll.positions.firstOrNull, this)) {
      // The sheet's own view, too short to scroll, can still pull the sheet.
      if (_pullsSheet && physics.allowUserScrolling) context.setCanDrag(true);
    } else if (maxScrollExtent <= minScrollExtent) {
      // A list nested inside it, with nothing to scroll, leaves the drag to the
      // outer view. A list's default physics would otherwise always claim it.
      context.setCanDrag(false);
    }
  }

  @override
  void absorb(ScrollPosition other) {
    super.absorb(other);
    if (other is _SheetScrollPosition) {
      _pulling = other._pulling;
      other._pulling = false;
    }
  }

  @override
  void applyUserOffset(double delta) {
    if (_pullsSheet && sheet._scrollDrag(this, delta)) {
      _pulling = true;
      return;
    }
    if (physics.shouldAcceptUserOffset(this)) super.applyUserOffset(delta);
  }

  @override
  void goBallistic(double velocity) {
    if (_pulling) {
      _pulling = false;
      // Scroll velocity runs against the finger; the sheet measures the finger.
      sheet._finishDrag(sheet._releaseVelocity(-velocity));
      velocity = 0;
    }
    super.goBallistic(velocity);
  }

  @override
  void dispose() {
    // The list went away mid-drag, so no release will come through it. This
    // runs while the tree is being finalized; the sheet settles after that.
    if (_pulling) {
      _pulling = false;
      WidgetsBinding.instance.addPostFrameCallback((_) => sheet._finishDrag(0));
      WidgetsBinding.instance.ensureVisualUpdate();
    }
    super.dispose();
  }
}
