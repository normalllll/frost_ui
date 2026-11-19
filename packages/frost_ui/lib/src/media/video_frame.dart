import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../controls/_slider_media_scope.dart';
import '../controls/buttons.dart';
import '../controls/shortcuts.dart';
import '../controls/slider.dart';
import '../feedback/activity_indicator.dart';
import '../feedback/loading_gate.dart';
import '../foundation/control_scope.dart';
import '../foundation/density.dart';
import '../foundation/scope.dart';
import '../foundation/sizes.dart';
import '../foundation/tokens.dart';
import '../navigation/toolbar.dart';
import '../overlays/menu_entry.dart';
import '../primitives/_on_media_chrome_scope.dart';
import '../primitives/_presence_material.dart';
import '../primitives/icon.dart';
import '../primitives/presence.dart';
import '_video_bar.dart';
import 'media_button.dart';
import 'video_state.dart';

// Playback clocks and keyboard seek use whole seconds; drag precision remains
// in microseconds and the application alone changes the actual player.
const _videoSeekStep = Duration(seconds: 5);
const _secondsPerMinute = 60;
const _secondsPerHour = _secondsPerMinute * _secondsPerMinute;
const _microsecondsPerSecond = Duration.microsecondsPerSecond;
const _clockSeparator = ':';
const _clockZero = '0';
// The preview floats this far above the slider's centre line, clear of the
// pressed thumb's radius.
const _previewClearance = 16.0;

/// Player-free media controls. Give the frame finite width and height; [video]
/// owns decoding, fitting and playback. Only releasing a seek calls [onSeek].
/// Playback time, its slider and arrow shortcuts stay LTR even in RTL content.
class FrostVideoFrame extends StatefulWidget {
  const FrostVideoFrame({
    required this.video,
    required this.state,
    required this.onPlayPause,
    required this.onSeek,
    this.onMuteToggle,
    this.onLoopToggle,
    this.onFullscreenToggle,
    this.controls = const [],
    this.topLeading,
    this.actions = const [],
    this.moreActions = const [],
    this.seekPreviewBuilder,
    this.trackDecorationBuilder,
    super.key,
  });
  final Widget video;

  /// App-owned Back / page-root actions. Drawn in the top strip, never as a
  /// floating circular control. Use FrostMediaButton for bare media ink.
  final Widget? topLeading;

  /// Secondary controls use the existing toolbar priorities and its single
  /// overflow menu. Narrow frames retain only More on the trailing side.
  final List<FrostToolbarItem> actions;
  final List<FrostMenuEntry> moreActions;

  /// App-owned controls, before audio/fullscreen. No playback or saved state is owned here.
  final List<Widget> controls;
  final FrostVideoState state;
  final VoidCallback onPlayPause;
  final ValueChanged<Duration> onSeek;

  /// Optional loop toggle. Its selected and toggled semantics follow [state].
  final VoidCallback? onLoopToggle;

  /// No callback, no control: the slot closes up.
  final VoidCallback? onMuteToggle;
  final VoidCallback? onFullscreenToggle;

  /// Builds a preview of the position a seek drag would land on. It is placed
  /// above the slider thumb, centred on it and kept inside the frame, and is
  /// built only while a drag is pending. Never shown for a live stream.
  final Widget Function(BuildContext context, Duration position)? seekPreviewBuilder;

  /// Builds a decoration (chapter ticks, an intensity curve) behind the seek
  /// track, under the thumb. It is laid out to the track's exact size and
  /// position. Never shown for a live stream.
  final Widget Function(BuildContext context, Size trackSize)? trackDecorationBuilder;

  @override
  State<FrostVideoFrame> createState() => _VideoFrameState();
}

class _VideoFrameState extends State<FrostVideoFrame> {
  final _focus = FocusNode(), _barFocus = FocusScopeNode(), _topFocus = FocusScopeNode();
  Timer? _idle;
  final _barPointers = <int>{};
  bool _visible = true, _dragging = false, _barHover = false;
  double? _preview;
  final _sliderKey = GlobalKey();
  // The slider's box in frame coordinates, measured outside layout so the
  // preview never reads a box that is still being laid out.
  Rect? _sliderBox;
  bool get _live => widget.state.live;
  bool get _enabled => FrostControlScope.enabledOf(context);
  double get _duration => math.max(0, widget.state.duration.inMicroseconds / _microsecondsPerSecond);
  double get _position => (widget.state.position.inMicroseconds / _microsecondsPerSecond).clamp(0.0, _duration);
  double get _buffered => (widget.state.buffered.inMicroseconds / _microsecondsPerSecond).clamp(0.0, _duration);
  bool get _keepVisible =>
      !widget.state.playing || widget.state.buffering || _dragging || _barHover || (_barFocus.hasFocus || _topFocus.hasFocus) || _barPointers.isNotEmpty;
  void _schedule() {
    _idle?.cancel();
    if (_keepVisible || !_visible) return;
    _idle = Timer(frostMediaChromeIdleDelay, () {
      if (mounted && !_keepVisible) setState(() => _visible = false);
    });
  }

  void _activity() {
    if (!mounted) return;
    if (!_visible) setState(() => _visible = true);
    _schedule();
  }

  void _toggleControls() {
    _focus.requestFocus();
    if (_keepVisible) {
      _activity();
      return;
    }
    setState(() => _visible = !_visible);
    _schedule();
  }

  void _invoke(VoidCallback? callback) {
    if (!_enabled || callback == null) return;
    _activity();
    callback();
  }

  void _seek(double seconds) {
    if (!_enabled || _live || _duration <= 0) return;
    final target = seconds.clamp(0.0, _duration);
    setState(() => _preview = null);
    _activity();
    widget.onSeek(Duration(microseconds: (target * _microsecondsPerSecond).round()));
  }

  Rect? _measureSlider() {
    final box = _sliderKey.currentContext?.findRenderObject(), origin = context.findRenderObject();
    if (box is! RenderBox || origin is! RenderBox || !box.attached || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero, ancestor: origin) & box.size;
  }

  void _interaction(bool active) {
    if (active) _sliderBox = _measureSlider();
    setState(() {
      _dragging = active;
      if (!active) _preview = null;
    });
    // A drag focuses the slider. Focus reached by keyboard holds the controls
    // up; this focus must not, and the frame's shortcuts still work from here.
    if (!active && _barFocus.hasFocus) _focus.requestFocus();
    _activity();
  }

  String _clock(double value) {
    final seconds = math.max(0, value.floor());
    final minutes = seconds ~/ _secondsPerMinute, tail = (seconds % _secondsPerMinute).toString().padLeft(2, _clockZero);
    if (seconds < _secondsPerHour) return '${minutes.toString().padLeft(2, _clockZero)}$_clockSeparator$tail';
    final hours = seconds ~/ _secondsPerHour, minute = (minutes % _secondsPerMinute).toString().padLeft(2, _clockZero);
    return '$hours$_clockSeparator$minute$_clockSeparator$tail';
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_enabled) {
      _barPointers.clear();
      _dragging = false;
      _preview = null;
    }
    _schedule();
  }

  @override
  void didUpdateWidget(FrostVideoFrame oldWidget) {
    super.didUpdateWidget(oldWidget);
    final cancelledDrag = _dragging && (_duration == 0 || _live);
    if (_duration == 0 || _live) {
      _dragging = false;
      _preview = null;
    }
    // Player clock updates must not restart the pointer's idle countdown.
    if (oldWidget.state.playing != widget.state.playing || oldWidget.state.buffering != widget.state.buffering || cancelledDrag) {
      if (_keepVisible) _visible = true;
      _schedule();
    }
  }

  @override
  void dispose() {
    _idle?.cancel();
    _focus.dispose();
    _barFocus.dispose();
    _topFocus.dispose();
    super.dispose();
  }

  Widget _button(FrostIconData icon, String label, VoidCallback? action, {FrostControlSize size = FrostControlSize.compact}) =>
      FrostMediaButton.icon(label: label, size: size, onPressed: _enabled && action != null ? () => _invoke(action) : null, icon: icon);
  @override
  Widget build(BuildContext context) {
    final labels = FrostScope.labelsOf(context), icons = FrostIconSet.of(context), tokens = FrostThemeTokens.of(context);
    final current = _preview ?? _position;
    final safe = MediaQuery.paddingOf(context);
    if (_preview != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _preview == null) return;
        final box = _measureSlider();
        if (box != null && box != _sliderBox) setState(() => _sliderBox = box);
      });
    }
    final play = _button(widget.state.playing ? icons.pause : icons.play, widget.state.playing ? labels.pause : labels.play, widget.onPlayPause);
    final slider = _live
        ? const SizedBox.shrink()
        : Directionality(
            key: _sliderKey,
            textDirection: TextDirection.ltr,
            child: FrostSliderMediaScope(
              trackDecoration: widget.trackDecorationBuilder,
              ink: tokens.onMediaInk,
              buffered: _duration == 0 ? 0 : _buffered / _duration,
              step: _videoSeekStep.inSeconds.toDouble(),
              onInteractionChanged: _interaction,
              child: FrostSlider(
                value: current,
                max: math.max(1, _duration),
                semanticLabel: labels.seek,
                valueLabel: _clock,
                onChanged: _enabled && _duration > 0 ? (value) => setState(() => _preview = value) : null,
                onChangeEnd: _seek,
              ),
            ),
          );
    Widget frame = Focus(
      focusNode: _focus,
      onKeyEvent: (_, event) {
        if (event is KeyDownEvent || event is KeyRepeatEvent) _activity();
        return KeyEventResult.ignored;
      },
      child: MouseRegion(
        onEnter: (_) => _activity(),
        onHover: (_) => _activity(),
        onExit: (_) => _schedule(),
        child: Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(behavior: HitTestBehavior.opaque, onTap: _toggleControls, child: widget.video),
            Center(
              child: FrostLoadingGate(
                loading: widget.state.buffering,
                builder: (context, buffering) => Stack(
                  alignment: Alignment.center,
                  children: [
                    FrostPresence(
                      visible: buffering,
                      child: IgnorePointer(
                        child: FrostActivityForeground(
                          color: tokens.onMediaInk,
                          child: FrostActivityIndicator(size: FrostControlSize.large, semanticLabel: labels.loading),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (widget.topLeading != null || widget.actions.isNotEmpty || widget.moreActions.isNotEmpty)
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: FrostPresenceMaterial(
                  child: FrostPresence(
                    visible: _visible,
                    child: FocusScope(
                      node: _topFocus,
                      onFocusChange: (_) => _activity(),
                      child: MouseRegion(
                        onEnter: (_) {
                          setState(() => _barHover = true);
                          _activity();
                        },
                        onExit: (_) {
                          setState(() => _barHover = false);
                          _schedule();
                        },
                        child: _VideoTopChrome(
                          gradient: widget.actions.isNotEmpty || widget.moreActions.isNotEmpty,
                          child: Padding(
                            padding:
                                (widget.actions.isEmpty && widget.moreActions.isEmpty
                                    ? const EdgeInsets.symmetric(horizontal: 3, vertical: 1)
                                    : const EdgeInsets.symmetric(horizontal: 8, vertical: 4)) +
                                EdgeInsets.only(left: safe.left, right: safe.right, top: safe.top),
                            child: FrostMediaControlsScope(
                              child: FrostOnMediaChromeScope(
                                child: LayoutBuilder(
                                  builder: (context, constraints) {
                                    final narrow = constraints.maxWidth < 600;
                                    final more = [if (narrow) ...frostToolbarOverflowEntries(context, widget.actions), ...widget.moreActions];
                                    return Row(
                                      children: [
                                        ?widget.topLeading,
                                        if ((!narrow && widget.actions.isNotEmpty) || more.isNotEmpty)
                                          Expanded(
                                            child: Align(
                                              alignment: AlignmentDirectional.centerEnd,
                                              child: SizedBox(
                                                width: narrow ? FrostDensity.of(context).targetHeight : constraints.maxWidth,
                                                child: FrostToolbar(
                                                  trailing: [
                                                    if (!narrow) ...widget.actions,
                                                    if (more.isNotEmpty)
                                                      FrostToolbarItem.menu(label: labels.more, icon: icons.more, showsLabel: false, entries: more),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: FrostPresenceMaterial(
                child: FrostPresence(
                  visible: _visible,
                  child: FocusScope(
                    node: _barFocus,
                    onFocusChange: (_) => _activity(),
                    child: Listener(
                      onPointerDown: (event) {
                        _barPointers.add(event.pointer);
                        _activity();
                      },
                      onPointerUp: (event) {
                        _barPointers.remove(event.pointer);
                        _activity();
                      },
                      onPointerCancel: (event) {
                        _barPointers.remove(event.pointer);
                        _activity();
                      },
                      child: MouseRegion(
                        onEnter: (_) {
                          setState(() => _barHover = true);
                          _activity();
                        },
                        onExit: (_) {
                          setState(() => _barHover = false);
                          _schedule();
                        },
                        child: FrostVideoBar(
                          play: play,
                          current: _live ? '' : _clock(current),
                          total: _live ? '' : _clock(_duration),
                          liveLabel: _live ? labels.live : null,
                          slider: slider,
                          custom: widget.controls,
                          trailing: [
                            if (widget.onLoopToggle != null)
                              FrostButton.iconOnMedia(
                                icon: icons.repeat,
                                label: labels.loop,
                                size: FrostControlSize.compact,
                                selected: widget.state.looping,
                                onPressed: _enabled ? () => _invoke(widget.onLoopToggle) : null,
                              ),
                            if (widget.onMuteToggle != null)
                              _button(
                                widget.state.muted ? icons.volumeOff : icons.volumeOn,
                                widget.state.muted ? labels.unmute : labels.mute,
                                widget.onMuteToggle,
                              ),
                            if (widget.onFullscreenToggle != null)
                              _button(
                                widget.state.fullscreen ? icons.exitFullscreen : icons.fullscreen,
                                widget.state.fullscreen ? labels.exitFullscreen : labels.fullscreen,
                                widget.onFullscreenToggle,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (_preview != null && _sliderBox != null && !_live && widget.seekPreviewBuilder != null)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomSingleChildLayout(
                    delegate: _SeekPreviewLayout(slider: _sliderBox!, fraction: (_preview! / math.max(1, _duration)).clamp(0.0, 1.0)),
                    child: widget.seekPreviewBuilder!(context, Duration(microseconds: (_preview! * _microsecondsPerSecond).round())),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
    // The slider yields these keys, so one key event produces one seek.
    final bindings = <FrostShortcut, VoidCallback>{
      const FrostShortcut(LogicalKeyboardKey.space): () => _invoke(widget.onPlayPause),
      const FrostShortcut(LogicalKeyboardKey.keyK): () => _invoke(widget.onPlayPause),
      if (!_live) ...{
        const FrostShortcut(LogicalKeyboardKey.arrowLeft): () => _seek((_preview ?? _position) - _videoSeekStep.inSeconds),
        const FrostShortcut(LogicalKeyboardKey.arrowRight): () => _seek((_preview ?? _position) + _videoSeekStep.inSeconds),
      },
      if (widget.onMuteToggle != null) const FrostShortcut(LogicalKeyboardKey.keyM): () => _invoke(widget.onMuteToggle),
      if (widget.onFullscreenToggle != null) const FrostShortcut(LogicalKeyboardKey.keyF): () => _invoke(widget.onFullscreenToggle),
    };
    for (final binding in bindings.entries) {
      frame = frame.frostShortcut(binding.key, binding.value);
    }
    return _live ? Semantics(container: true, value: labels.live, child: frame) : frame;
  }
}

// A lone Back action does not darken the entire picture. Its local media
// control owns legibility; populated toolbars retain the continuous scrim.
class _VideoTopChrome extends StatelessWidget {
  const _VideoTopChrome({required this.gradient, required this.child});
  final bool gradient;
  final Widget child;
  @override
  Widget build(BuildContext context) => gradient ? FrostVideoChrome(top: true, child: child) : child;
}

// The preview is centred on the thumb, which travels the slider's full width,
// and stays above it and inside the frame.
class _SeekPreviewLayout extends SingleChildLayoutDelegate {
  const _SeekPreviewLayout({required this.slider, required this.fraction});
  final Rect slider;
  final double fraction;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) => constraints.loosen();

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final thumbX = slider.left + slider.width * fraction;
    final x = (thumbX - childSize.width / 2).clamp(0.0, math.max(0.0, size.width - childSize.width)).toDouble();
    final y = (slider.center.dy - _previewClearance - childSize.height).clamp(0.0, math.max(0.0, size.height - childSize.height)).toDouble();
    return Offset(x, y);
  }

  @override
  bool shouldRelayout(_SeekPreviewLayout oldDelegate) => slider != oldDelegate.slider || fraction != oldDelegate.fraction;
}
