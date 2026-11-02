import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../foundation/_media_contrast.dart';

/// The row supplies its measured height; the gradient reaches readable opacity
/// before its first text pixel, including when accessibility text grows.
class FrostCoverScrim extends CustomPainter {
  const FrostCoverScrim({required this.coverHeight, required this.fraction});
  final double coverHeight, fraction;

  @override
  void paint(Canvas canvas, Size size) {
    const black = Color(0xFF000000), white = Color(0xFFFFFFFF);
    final readable = frostContrastScrimOpacity(surface: black, ink: white, worst: white, minimum: .5);
    final height = math.max(coverHeight * fraction, size.height + 1);
    final textStart = ((height - size.height) / height).clamp(0.0, 1.0);
    final rect = Rect.fromLTWH(0, size.height - height, size.width, height);
    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      stops: [0, textStart, 1],
      colors: [
        black.withValues(alpha: 0),
        black.withValues(alpha: readable),
        black.withValues(alpha: .62),
      ],
    );
    canvas.drawRect(rect, Paint()..shader = gradient.createShader(rect));
  }

  @override
  bool shouldRepaint(FrostCoverScrim oldDelegate) => coverHeight != oldDelegate.coverHeight || fraction != oldDelegate.fraction;
}

/// A small list thumbnail uses a taller fade and tighter caption metrics.
class FrostCoverRowScope extends InheritedWidget {
  const FrostCoverRowScope({required super.child, super.key});
  static bool of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<FrostCoverRowScope>() != null;
  @override
  bool updateShouldNotify(FrostCoverRowScope oldWidget) => false;
}
