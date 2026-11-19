import 'package:flutter/foundation.dart';

/// The application owns playback. Out-of-range positions and nonpositive
/// durations are normalized by FrostVideoFrame without changing this value.
@immutable
class FrostVideoState {
  const FrostVideoState({
    required this.playing,
    required this.position,
    required this.duration,
    this.buffered = Duration.zero,
    this.muted = false,
    this.looping = false,
    this.fullscreen = false,
    this.buffering = false,
    this.live = false,
  });
  final bool playing, muted, fullscreen, buffering, looping;

  /// A stream without length or seeking: the frame shows a live indicator in
  /// place of the seek slider and clock, and ignores seek shortcuts.
  final bool live;
  final Duration position, duration, buffered;
}
