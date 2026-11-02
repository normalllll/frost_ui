import 'package:flutter/widgets.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/media.dart';

import 'baseline.dart';

void _noop() {}
void _seek(Duration position) {}

const _video = ColoredBox(color: Color(0xFF223344));
// Paused media keeps its controls visible; playing media hides them after the idle delay.
const _paused = FrostVideoState(playing: false, position: Duration(seconds: 65), duration: Duration(seconds: 3605), buffered: Duration(seconds: 1800));
const _topLeading = FrostText('Back', tone: FrostTextTone.primary);

// A frame needs a finite width and height of its own.
Widget _frame({
  FrostVideoState state = _paused,
  VoidCallback? onMuteToggle,
  VoidCallback? onLoopToggle,
  VoidCallback? onFullscreenToggle,
  List<Widget> controls = const [],
  Widget? topLeading,
  List<FrostToolbarItem> actions = const [],
  List<FrostMenuEntry> moreActions = const [],
}) => SizedBox(
  width: 640,
  height: 360,
  child: FrostVideoFrame(
    video: _video,
    state: state,
    onPlayPause: _noop,
    onSeek: _seek,
    onMuteToggle: onMuteToggle,
    onLoopToggle: onLoopToggle,
    onFullscreenToggle: onFullscreenToggle,
    controls: controls,
    topLeading: topLeading,
    actions: actions,
    moreActions: moreActions,
  ),
);

FrostVideoState _with({
  bool playing = false,
  Duration position = const Duration(seconds: 65),
  Duration duration = const Duration(seconds: 3605),
  Duration buffered = Duration.zero,
  bool muted = false,
  bool looping = false,
  bool fullscreen = false,
  bool buffering = false,
}) => FrostVideoState(
  playing: playing,
  position: position,
  duration: duration,
  buffered: buffered,
  muted: muted,
  looping: looping,
  fullscreen: fullscreen,
  buffering: buffering,
);

void main() {
  baselineGroup('FrostVideoFrame', [
    BaselineCase('FrostVideoFrame/required', (_) => _frame(), envs: [...BaselineEnv.themes, BaselineEnv.narrow, BaselineEnv.touch, BaselineEnv.largeText]),
    // state variations: one flag at a time
    BaselineCase('FrostVideoFrame/state.playing', (_) => _frame(state: _with(playing: true))),
    BaselineCase('FrostVideoFrame/state.buffered', (_) => _frame(state: _with(buffered: const Duration(seconds: 1800)))),
    BaselineCase('FrostVideoFrame/state.buffering', (_) => _frame(state: _with(playing: true, buffering: true))),
    BaselineCase(
      'FrostVideoFrame/state.duration=zero',
      (_) => _frame(
        state: _with(position: Duration.zero, duration: Duration.zero),
      ),
    ),
    BaselineCase(
      'FrostVideoFrame/state.position=pastDuration',
      (_) => _frame(
        state: _with(position: const Duration(seconds: 90), duration: const Duration(seconds: 60)),
      ),
    ),
    BaselineCase(
      'FrostVideoFrame/state.duration=short',
      (_) => _frame(
        state: _with(position: const Duration(seconds: 12), duration: const Duration(seconds: 45)),
      ),
    ),
    BaselineCase('FrostVideoFrame/onMuteToggle', (_) => _frame(onMuteToggle: _noop), envs: BaselineEnv.themes),
    BaselineCase('FrostVideoFrame/onMuteToggle+state.muted', (_) => _frame(onMuteToggle: _noop, state: _with(muted: true))),
    BaselineCase('FrostVideoFrame/onLoopToggle', (_) => _frame(onLoopToggle: _noop)),
    BaselineCase('FrostVideoFrame/onLoopToggle+state.looping', (_) => _frame(onLoopToggle: _noop, state: _with(looping: true))),
    BaselineCase('FrostVideoFrame/onFullscreenToggle', (_) => _frame(onFullscreenToggle: _noop)),
    BaselineCase('FrostVideoFrame/onFullscreenToggle+state.fullscreen', (_) => _frame(onFullscreenToggle: _noop, state: _with(fullscreen: true))),
    BaselineCase(
      'FrostVideoFrame/onMuteToggle+onLoopToggle+onFullscreenToggle',
      (_) => _frame(onMuteToggle: _noop, onLoopToggle: _noop, onFullscreenToggle: _noop),
      envs: [BaselineEnv.standard, BaselineEnv.narrow, BaselineEnv.touch],
    ),
    BaselineCase(
      'FrostVideoFrame/controls',
      (_) => _frame(
        controls: const [FrostMediaButton(label: 'Speed', onPressed: _noop)],
      ),
    ),
    BaselineCase('FrostVideoFrame/topLeading', (_) => _frame(topLeading: _topLeading)),
    BaselineCase(
      'FrostVideoFrame/actions',
      (_) => _frame(
        actions: [FrostToolbarItem.action(label: 'Share', icon: baselineIcon, onPressed: _noop)],
      ),
      envs: [BaselineEnv.standard, BaselineEnv.narrow],
    ),
    BaselineCase(
      'FrostVideoFrame/moreActions',
      (_) => _frame(moreActions: [FrostMenuAction('Download', onSelected: _noop)]),
      envs: [BaselineEnv.standard, BaselineEnv.narrow],
    ),
    BaselineCase('FrostVideoFrame/required#hover', (_) => _frame(), act: baselineHover),
    BaselineCase(
      'FrostVideoFrame/onMuteToggle+onFullscreenToggle#focus',
      (_) => _frame(onMuteToggle: _noop, onFullscreenToggle: _noop),
      act: baselineFocus,
    ),
  ]);
}
