import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Content from which a press-and-drag with the mouse moves the window, for a
/// window whose content covers its title row, such as a small always-on-top
/// player. The move is the system's own, as from a native caption, so it
/// snaps and crosses displays by the platform's rules.
///
/// A plain click still reaches the content: the move starts only once the
/// pointer has moved and every other gesture on the press has given up. A
/// press on a control inside the area never moves the window: a control
/// shows its own mouse cursor (a button's hand, an editable field's I-beam),
/// and a gesture of its own that takes mouse drags, such as a scrubbing strip,
/// keeps the press in any direction. Touch never moves the window.
///
/// The area works under a [FrostWindowHost]; elsewhere it is only its child.
/// On a platform without a native window move the press reports
/// `FrostWindowUnsupportedFailure` through [FlutterError.reportError] once.
class FrostWindowMoveArea extends StatefulWidget {
  const FrostWindowMoveArea({required this.child, super.key});
  final Widget child;

  @override
  State<FrostWindowMoveArea> createState() => _FrostWindowMoveAreaState();
}

/// The window move [FrostWindowHost] offers its content. Not exported.
class FrostWindowMoveScope extends InheritedWidget {
  const FrostWindowMoveScope({required this.startMove, required super.child, super.key});
  final Future<void> Function() startMove;

  static Future<void> Function()? maybeOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<FrostWindowMoveScope>()?.startMove;

  @override
  bool updateShouldNotify(FrostWindowMoveScope oldWidget) => startMove != oldWidget.startMove;
}

class _FrostWindowMoveAreaState extends State<FrostWindowMoveArea> {
  late final _recognizer = _WindowMoveRecognizer(onMove: _move, debugOwner: this);
  bool _reported = false;

  void _move() {
    final start = FrostWindowMoveScope.maybeOf(context);
    if (start == null) return;
    start().catchError((Object error, StackTrace stack) {
      if (_reported) return;
      _reported = true;
      FlutterError.reportError(
        FlutterErrorDetails(exception: error, stack: stack, library: 'frost_ui', context: ErrorDescription('while moving the window from FrostWindowMoveArea')),
      );
    });
  }

  @override
  void dispose() {
    _recognizer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (FrostWindowMoveScope.maybeOf(context) == null) return widget.child;
    return _MoveAreaListener(onAreaPress: _recognizer.addPointer, child: widget.child);
  }
}

/// Passes on the presses that land on the area itself rather than on a
/// control in it. A control is told by the cursor it shows, read from what
/// the press hit inside this subtree; read-only text is part of the area.
class _MoveAreaListener extends SingleChildRenderObjectWidget {
  const _MoveAreaListener({required this.onAreaPress, required super.child});
  final ValueChanged<PointerDownEvent> onAreaPress;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderMoveAreaListener(onAreaPress);

  @override
  void updateRenderObject(BuildContext context, _RenderMoveAreaListener renderObject) => renderObject.onAreaPress = onAreaPress;
}

class _RenderMoveAreaListener extends RenderProxyBox {
  _RenderMoveAreaListener(this.onAreaPress);
  ValueChanged<PointerDownEvent> onAreaPress;
  bool _onControl = false;

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final before = result.path.length;
    final hit = super.hitTestChildren(result, position: position);
    _onControl = hit && _controlIn(result.path.skip(before));
    return hit;
  }

  static bool _controlIn(Iterable<HitTestEntry> entries) {
    var editable = false;
    for (final entry in entries) {
      final target = entry.target;
      if (target is RenderEditable && !target.readOnly) editable = true;
      if (target is RenderMouseRegion && target.cursor != MouseCursor.defer && (target.cursor != SystemMouseCursors.text || editable)) return true;
    }
    return false;
  }

  @override
  bool hitTestSelf(Offset position) => false;

  @override
  void handleEvent(PointerEvent event, HitTestEntry entry) {
    if (event is PointerDownEvent && !_onControl) onAreaPress(event);
  }
}

/// Starts the window move for a primary mouse press once the pointer has
/// travelled past the pan slop and the press is its own: it never claims the
/// arena, so it wins only when every other gesture on the press has given up.
class _WindowMoveRecognizer extends OneSequenceGestureRecognizer {
  _WindowMoveRecognizer({required this.onMove, super.debugOwner}) : super(supportedDevices: {PointerDeviceKind.mouse});
  final VoidCallback onMove;
  Offset? _origin;
  bool _won = false, _travelled = false, _started = false;

  @override
  bool isPointerAllowed(PointerDownEvent event) => event.buttons == kPrimaryMouseButton && super.isPointerAllowed(event);

  @override
  void addAllowedPointer(PointerDownEvent event) {
    if (_origin != null) return;
    _origin = event.position;
    super.addAllowedPointer(event);
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event is PointerMoveEvent && (event.position - _origin!).distance > computePanSlop(event.kind, gestureSettings)) {
      _travelled = true;
      _startWhenReady();
    } else if (event is PointerUpEvent || event is PointerCancelEvent) {
      stopTrackingPointer(event.pointer);
    }
  }

  @override
  void acceptGesture(int pointer) {
    _won = true;
    _startWhenReady();
  }

  @override
  void rejectGesture(int pointer) => stopTrackingPointer(pointer);

  void _startWhenReady() {
    if (!_won || !_travelled || _started) return;
    _started = true;
    onMove();
  }

  @override
  void didStopTrackingLastPointer(int pointer) {
    _origin = null;
    _won = _travelled = _started = false;
  }

  @override
  String get debugDescription => 'window move';
}
