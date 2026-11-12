import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../foundation/_media_contrast.dart';
import '../foundation/tokens.dart';
import '../motion/_material_reveal.dart';
import '../primitives/_on_media_chrome_scope.dart';
import '../primitives/_presence_material.dart';
import '../primitives/presence.dart';
import '_video_bar.dart';

/// Viewer controls over full-screen media, such as an image viewer's close,
/// position and more row at the top, its zoom and download row at the bottom,
/// and previous / next at the edges. Pass it as [FrostMediaViewport.overlay]
/// so it stays fixed while the media zooms and fades with pull-down dismissal.
///
/// The [top] and [bottom] rows sit on the video player's protection gradient,
/// fading to clear at the row's own edge, so white ink stays readable over a
/// white image. The [start] and [end] controls, centered on their edges, get a
/// soft protection of the same black behind them and no panel. All of them use
/// on-media ink: [FrostMediaButton] and [FrostButton.iconOnMedia] draw bare
/// glyphs here, and text without its own colour, such as a "3 / 40" position,
/// takes the same ink and glyph shadow. Rows span the width and keep clear of
/// the system safe area; their content is the caller's.
///
/// The controls show and hide by the video player's rule: they appear on
/// pointer movement or a key press, unless the key goes to a text field or to a
/// route on top of this one, hide after 2.5 seconds without input, and
/// stay while the pointer is over them, a pointer is down on them or focus is
/// inside them. A tap on the media between them toggles them. With
/// [autoHide] false they stay until that tap, like a paused video's controls.
/// Hidden controls take no input, focus or semantics.
class FrostMediaChrome extends StatefulWidget {
  const FrostMediaChrome({this.top, this.bottom, this.start, this.end, this.autoHide = true, this.onVisibleChanged, super.key});
  final Widget? top, bottom;

  /// Controls at the leading and trailing edges, usually previous and next.
  final Widget? start, end;
  final bool autoHide;

  /// Reports each change of visibility, never during build or layout.
  final ValueChanged<bool>? onVisibleChanged;

  @override
  State<FrostMediaChrome> createState() => _FrostMediaChromeState();
}

class _FrostMediaChromeState extends State<FrostMediaChrome> {
  Timer? _idle;
  bool _visible = true;
  final _hovered = <Object>{};
  final _pressed = <int>{};
  final _focused = <Object>{};

  // A tap on the media waits out a double tap, which zooms instead.
  Timer? _tap;
  Offset? _downAt;
  Duration? _downTime;
  int _mediaPointers = 0;
  ModalRoute<Object?>? _route;

  bool get _keepVisible => !widget.autoHide || _hovered.isNotEmpty || _pressed.isNotEmpty || _focused.isNotEmpty;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_key);
    _schedule();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _route = ModalRoute.of(context);
  }

  @override
  void didUpdateWidget(FrostMediaChrome oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.autoHide != widget.autoHide) _schedule();
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_key);
    _idle?.cancel();
    _tap?.cancel();
    super.dispose();
  }

  bool _key(KeyEvent event) {
    if (event is! KeyDownEvent || !(_route?.isCurrent ?? true)) return false;
    final typing = FocusManager.instance.primaryFocus?.context?.findAncestorStateOfType<EditableTextState>() != null;
    if (!typing) _activity();
    return false;
  }

  void _setVisible(bool visible) {
    if (!mounted || _visible == visible) return;
    setState(() => _visible = visible);
    widget.onVisibleChanged?.call(visible);
  }

  void _schedule() {
    _idle?.cancel();
    if (_keepVisible || !_visible) return;
    _idle = Timer(frostMediaChromeIdleDelay, () {
      if (!_keepVisible) _setVisible(false);
    });
  }

  void _activity() {
    _setVisible(true);
    _schedule();
  }

  void _toggle() {
    _tap = null;
    if (_visible && _keepVisible && widget.autoHide) {
      _activity();
      return;
    }
    _setVisible(!_visible);
    _schedule();
  }

  // Pointers on the media, between the controls. The viewport behind gets
  // them too; only a short, still, single tap toggles the controls.
  void _mediaDown(PointerDownEvent event) {
    _mediaPointers++;
    final second = _tap != null;
    _tap?.cancel();
    _tap = null;
    _downAt = _mediaPointers == 1 && !second ? event.position : null;
    _downTime = event.timeStamp;
  }

  void _mediaUp(PointerUpEvent event) {
    _mediaPointers = math.max(0, _mediaPointers - 1);
    final at = _downAt, time = _downTime;
    _downAt = null;
    if (at == null || time == null || _mediaPointers > 0) return;
    if ((event.position - at).distance > kTouchSlop || event.timeStamp - time > kLongPressTimeout) return;
    _tap = Timer(kDoubleTapTimeout, _toggle);
  }

  void _mediaCancel(PointerCancelEvent event) {
    _mediaPointers = math.max(0, _mediaPointers - 1);
    _downAt = null;
  }

  // One region per control group: hover, press and focus keep it shown.
  Widget _region(Object id, Widget child) => Listener(
    onPointerDown: (event) {
      _pressed.add(event.pointer);
      _activity();
    },
    onPointerUp: (event) {
      _pressed.remove(event.pointer);
      _schedule();
    },
    onPointerCancel: (event) {
      _pressed.remove(event.pointer);
      _schedule();
    },
    child: MouseRegion(
      onEnter: (_) {
        _hovered.add(id);
        _activity();
      },
      onExit: (_) {
        _hovered.remove(id);
        _schedule();
      },
      child: Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onFocusChange: (focused) {
          focused ? _focused.add(id) : _focused.remove(id);
          _activity();
        },
        child: FrostMediaControlsScope(
          child: FrostOnMediaChromeScope(
            child: DefaultTextStyle.merge(
              style: TextStyle(color: FrostThemeTokens.of(context).onMediaInk, shadows: frostMediaInkShadows),
              child: child,
            ),
          ),
        ),
      ),
    ),
  );

  Widget _present(Widget child) => FrostPresenceMaterial(
    child: FrostPresence(visible: _visible, child: child),
  );

  @override
  Widget build(BuildContext context) {
    final safe = MediaQuery.paddingOf(context);
    final horizontal = EdgeInsetsDirectional.only(start: 8, end: 8).resolve(Directionality.of(context)) + EdgeInsets.only(left: safe.left, right: safe.right);
    Widget edge(Object id, Widget control, AlignmentDirectional alignment) => Align(
      alignment: alignment,
      child: Padding(
        padding: horizontal,
        child: _present(_region(id, _EdgeProtection(child: control))),
      ),
    );

    // Translucent: input between the controls also reaches the media behind.
    // The region stays opaque, so a hit on a control ends there and the
    // media's double-tap recognizer never holds a button tap.
    return MouseRegion(
      hitTestBehavior: HitTestBehavior.translucent,
      onEnter: (_) => _activity(),
      onHover: (_) => _activity(),
      onExit: (_) => _schedule(),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Listener(behavior: HitTestBehavior.translucent, onPointerDown: _mediaDown, onPointerUp: _mediaUp, onPointerCancel: _mediaCancel),
          if (widget.start case final start?) edge(#start, start, AlignmentDirectional.centerStart),
          if (widget.end case final end?) edge(#end, end, AlignmentDirectional.centerEnd),
          if (widget.top case final top?)
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: _present(
                _region(
                  #top,
                  FrostVideoChrome(
                    top: true,
                    child: Padding(
                      padding: horizontal + EdgeInsets.only(top: safe.top + 4, bottom: 4),
                      child: top,
                    ),
                  ),
                ),
              ),
            ),
          if (widget.bottom case final bottom?)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _present(
                _region(
                  #bottom,
                  FrostVideoChrome(
                    child: Padding(
                      padding: horizontal + EdgeInsets.only(top: 12, bottom: safe.bottom + 4),
                      child: bottom,
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

/// The video scrim's black, centered behind one edge control and fading to
/// clear within a control's width around it, so a light image keeps the
/// glyph readable without a visible disc.
class _EdgeProtection extends StatelessWidget {
  const _EdgeProtection({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final tokens = FrostThemeTokens.of(context);
    final reveal = FrostMaterialRevealScope.maybeOf(context);
    final progress = reveal != null && !reveal.claimed ? reveal.progress : 1.0;
    final readable = frostVideoControlScrimOpacity(tokens);
    return CustomPaint(
      painter: _EdgeProtectionPainter(tokens.onMediaScrim.withValues(alpha: readable * progress)),
      child: reveal?.consume(context, child) ?? child,
    );
  }
}

class _EdgeProtectionPainter extends CustomPainter {
  const _EdgeProtectionPainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.longestSide / 2 + 24;
    final rect = Rect.fromCircle(center: center, radius: radius);
    // Full strength under the glyph, then an eased fade so the rim has no edge.
    final core = size.shortestSide / 4 / radius;
    final gradient = RadialGradient(
      colors: [
        for (final strength in const [1.0, 1.0, .62, .3, .1, 0.0]) color.withValues(alpha: color.a * strength),
      ],
      stops: [0, core, core + (1 - core) * .3, core + (1 - core) * .55, core + (1 - core) * .8, 1],
    );
    canvas.drawCircle(center, radius, Paint()..shader = gradient.createShader(rect));
  }

  @override
  bool shouldRepaint(_EdgeProtectionPainter oldDelegate) => color != oldDelegate.color;
}
