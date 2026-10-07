import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Caption button glyphs, drawn rather than loaded so the plugin ships no
/// icon assets. Shapes follow the Windows caption buttons.
enum FrostCaptionGlyphKind { minimize, maximize, restore, close, retry }

class FrostCaptionGlyph extends StatelessWidget {
  const FrostCaptionGlyph(this.kind, {required this.color, this.size = 10, super.key});

  final FrostCaptionGlyphKind kind;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => CustomPaint(size: Size.square(size), painter: _GlyphPainter(kind, color, MediaQuery.devicePixelRatioOf(context)));
}

class _GlyphPainter extends CustomPainter {
  const _GlyphPainter(this.kind, this.color, this.devicePixelRatio);

  final FrostCaptionGlyphKind kind;
  final Color color;
  final double devicePixelRatio;

  @override
  void paint(Canvas canvas, Size size) {
    // One physical pixel wide strokes at 100%, matching the system glyphs.
    final stroke = math.max(1.0, devicePixelRatio.floorToDouble()) / devicePixelRatio;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..isAntiAlias = kind == FrostCaptionGlyphKind.close || kind == FrostCaptionGlyphKind.retry;
    final w = size.width;
    final h = size.height;
    // Align strokes to the pixel grid.
    final half = stroke / 2;
    switch (kind) {
      case FrostCaptionGlyphKind.minimize:
        canvas.drawLine(Offset(0, h / 2 + half), Offset(w, h / 2 + half), paint);
      case FrostCaptionGlyphKind.maximize:
        canvas.drawRect(Rect.fromLTRB(half, half, w - half, h - half), paint);
      case FrostCaptionGlyphKind.restore:
        final inset = w * .2;
        canvas.drawRect(Rect.fromLTRB(half, inset + half, w - inset - half, h - half), paint);
        canvas.drawPath(
          Path()
            ..moveTo(inset + half, inset + half)
            ..lineTo(inset + half, half)
            ..lineTo(w - half, half)
            ..lineTo(w - half, h - inset - half)
            ..lineTo(w - inset - half, h - inset - half),
          paint,
        );
      case FrostCaptionGlyphKind.close:
        canvas.drawLine(Offset.zero, Offset(w, h), paint);
        canvas.drawLine(Offset(w, 0), Offset(0, h), paint);
      case FrostCaptionGlyphKind.retry:
        final rect = Rect.fromLTWH(half, half, w - stroke, h - stroke);
        canvas.drawArc(rect, -math.pi / 2, math.pi * 1.6, false, paint);
        final tip = Offset(w / 2, half);
        canvas.drawPath(
          Path()
            ..moveTo(tip.dx - w * .3, tip.dy - h * .05)
            ..lineTo(tip.dx, tip.dy)
            ..lineTo(tip.dx - w * .2, tip.dy + h * .25),
          paint,
        );
    }
  }

  @override
  bool shouldRepaint(_GlyphPainter oldDelegate) => kind != oldDelegate.kind || color != oldDelegate.color || devicePixelRatio != oldDelegate.devicePixelRatio;
}
