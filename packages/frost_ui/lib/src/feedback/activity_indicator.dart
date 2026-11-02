import 'dart:math' as math;
import 'package:flutter/widgets.dart';

import '../foundation/sizes.dart';
import '../foundation/tokens.dart';

/// Internal foreground supplied by buttons; not exported by frost_ui.dart.
class FrostActivityForeground extends InheritedWidget {
  const FrostActivityForeground({required this.color, required super.child, super.key});
  final Color color;
  static Color? maybeOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<FrostActivityForeground>()?.color;
  @override
  bool updateShouldNotify(FrostActivityForeground oldWidget) => color != oldWidget.color;
}

/// Three dots pulsing in sequence; the caller owns the loading announcement.
/// Frost never shows a rotating indicator.
class FrostActivityIndicator extends StatefulWidget {
  const FrostActivityIndicator({this.size = FrostControlSize.regular, required this.semanticLabel, super.key});
  final FrostControlSize size;
  final String? semanticLabel;
  @override
  State<FrostActivityIndicator> createState() => _FrostActivityIndicatorState();
}

class _FrostActivityIndicatorState extends State<FrostActivityIndicator> with SingleTickerProviderStateMixin {
  // Indicator boxes are independent of control/icon geometry.
  static const _compactBox = 16.0, _regularBox = 20.0, _largeBox = 28.0;
  static const _cycle = Duration(milliseconds: 900);
  late final _clock = AnimationController(vsync: this, duration: _cycle, animationBehavior: AnimationBehavior.preserve);
  bool? _reduced;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = MediaQuery.disableAnimationsOf(context);
    if (_reduced != reduced) {
      _reduced = reduced;
      _clock.value = 0;
      if (reduced) {
        _clock.stop();
      } else {
        _clock.repeat();
      }
    }
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final (box, dot, gap) = switch (widget.size) {
      FrostControlSize.small => (12.0, 2.5, 2.0),
      FrostControlSize.compact => (_compactBox, 3.0, 2.5),
      FrostControlSize.regular => (_regularBox, 4.0, 3.0),
      FrostControlSize.large => (_largeBox, 5.5, 4.0),
    };
    final drawing = SizedBox.square(
      dimension: box,
      child: CustomPaint(
        painter: _ActivityPainter(
          _clock,
          FrostActivityForeground.maybeOf(context) ?? FrostThemeTokens.of(context).keyGraphicOn(FrostThemeTokens.of(context).surface),
          dot,
          gap,
          _reduced!,
        ),
      ),
    );
    return widget.semanticLabel == null ? ExcludeSemantics(child: drawing) : Semantics(label: widget.semanticLabel, liveRegion: true, child: drawing);
  }
}

class _ActivityPainter extends CustomPainter {
  _ActivityPainter(this.clock, this.color, this.dot, this.gap, this.reduced) : super(repaint: clock);
  final Animation<double> clock;
  final Color color;
  final double dot, gap;
  final bool reduced;
  static const _phaseStep = .16, _minimumOpacity = .35, _minimumScale = .8;
  @override
  void paint(Canvas canvas, Size size) {
    final left = (size.width - (3 * dot + 2 * gap)) / 2;
    final paint = Paint();
    for (var index = 0; index < 3; index++) {
      // 0 at rest, 1 at the peak of this dot's pulse.
      final pulse = reduced ? 1.0 : (1 - math.cos(((clock.value - index * _phaseStep) % 1) * math.pi * 2)) / 2;
      final opacity = _minimumOpacity + (1 - _minimumOpacity) * pulse;
      final scale = _minimumScale + (1 - _minimumScale) * pulse;
      paint.color = color.withValues(alpha: color.a * opacity);
      canvas.drawCircle(Offset(left + dot / 2 + index * (dot + gap), size.height / 2), dot / 2 * scale, paint);
    }
  }

  @override
  bool shouldRepaint(_ActivityPainter oldDelegate) =>
      color != oldDelegate.color || dot != oldDelegate.dot || gap != oldDelegate.gap || reduced != oldDelegate.reduced || clock != oldDelegate.clock;
}
