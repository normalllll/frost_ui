import 'package:flutter/widgets.dart';

/// Interpolates [a] to [b] with premultiplied alpha, the way the two colours
/// composite. Over any backdrop each frame then lies between the two
/// endpoints. [Color.lerp] mixes straight channels instead, so a translucent
/// white wash turning into an opaque dark fill passes through a bright grey at
/// half opacity. A null end is that colour fully transparent.
Color? frostLerpColorPremultiplied(Color? a, Color? b, double t) {
  if (a == null && b == null) return null;
  final to = b ?? a!.withValues(alpha: 0);
  final from = (a ?? to.withValues(alpha: 0)).withValues(colorSpace: to.colorSpace);
  // Colour never overshoots, whatever the curve does with size or position.
  final s = t.clamp(0.0, 1.0);
  if (s == 0) return a;
  if (s == 1) return b;
  final alpha = from.a + (to.a - from.a) * s;
  if (alpha <= 0) return to.withValues(alpha: 0);
  double channel(double x, double y) => ((x * from.a + (y * to.a - x * from.a) * s) / alpha).clamp(0.0, 1.0);
  return Color.from(alpha: alpha, red: channel(from.r, to.r), green: channel(from.g, to.g), blue: channel(from.b, to.b), colorSpace: to.colorSpace);
}

/// A [ColorTween] that interpolates with [frostLerpColorPremultiplied].
class FrostPremultipliedColorTween extends ColorTween {
  FrostPremultipliedColorTween({super.begin, super.end});
  @override
  Color? lerp(double t) => frostLerpColorPremultiplied(begin, end, t);
}

/// A [DecorationTween] whose fill and outline colours interpolate with
/// [frostLerpColorPremultiplied]; shape, gradient and shadows lerp as usual.
class FrostPremultipliedDecorationTween extends DecorationTween {
  FrostPremultipliedDecorationTween({super.begin, super.end});
  @override
  Decoration lerp(double t) {
    final value = super.lerp(t);
    return switch ((begin, end, value)) {
      (final ShapeDecoration a, final ShapeDecoration b, final ShapeDecoration v) => ShapeDecoration(
        color: v.gradient == null ? frostLerpColorPremultiplied(a.color, b.color, t) : null,
        gradient: v.gradient,
        image: v.image,
        shadows: v.shadows,
        shape: switch ((a.shape, b.shape, v.shape)) {
          (final OutlinedBorder a, final OutlinedBorder b, final OutlinedBorder v) when v.side.style != BorderStyle.none => v.copyWith(
            side: v.side.copyWith(color: frostLerpColorPremultiplied(_sideColor(a.side), _sideColor(b.side), t)),
          ),
          _ => v.shape,
        },
      ),
      (final BoxDecoration a, final BoxDecoration b, final BoxDecoration v) when v.gradient == null => v.copyWith(
        color: frostLerpColorPremultiplied(a.color, b.color, t),
      ),
      _ => value,
    };
  }
}

// An absent stroke is transparent, whatever colour it nominally carries.
Color? _sideColor(BorderSide side) => side.style == BorderStyle.none || side.width == 0 ? null : side.color;
