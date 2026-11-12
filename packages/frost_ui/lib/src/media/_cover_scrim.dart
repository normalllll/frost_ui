import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// The row supplies its measured height; the gradient reaches readable opacity
/// before its first text pixel, including when accessibility text grows.
class FrostCoverScrim extends CustomPainter {
  const FrostCoverScrim({required this.coverHeight, required this.fraction, required this.scrim, required this.readable});
  final double coverHeight, fraction, readable;
  final Color scrim;

  @override
  void paint(Canvas canvas, Size size) {
    final height = math.max(coverHeight * fraction, size.height + 1);
    final textStart = ((height - size.height) / height).clamp(0.0, 1.0);
    final rect = Rect.fromLTWH(0, size.height - height, size.width, height);
    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      stops: [0, textStart, 1],
      colors: [
        scrim.withValues(alpha: 0),
        scrim.withValues(alpha: readable),
        scrim.withValues(alpha: .62),
      ],
    );
    canvas.drawRect(rect, Paint()..shader = gradient.createShader(rect));
  }

  @override
  bool shouldRepaint(FrostCoverScrim oldDelegate) => coverHeight != oldDelegate.coverHeight || fraction != oldDelegate.fraction || scrim != oldDelegate.scrim || readable != oldDelegate.readable;
}

/// A small list thumbnail uses a taller fade and tighter caption metrics.
class FrostCoverRowScope extends InheritedWidget {
  const FrostCoverRowScope({required super.child, super.key});
  static bool of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<FrostCoverRowScope>() != null;
  @override
  bool updateShouldNotify(FrostCoverRowScope oldWidget) => false;
}
