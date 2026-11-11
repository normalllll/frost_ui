import 'package:flutter/material.dart';

/// Library-only: how the shell's Back is drawn on the platform. Where Back
/// sits is shared; its glyph and hover shape follow the platform's own.
enum FrostBackLook {
  /// A chevron, with a capsule fill on hover (macOS, iPadOS).
  apple,

  /// A chevron, with a larger-radius fill (GNOME).
  gnome,

  /// An arrow, with the shared small-radius fill (Windows, KDE).
  windows,

  /// An arrow, with a round state layer (Android).
  material;

  /// [kde] is true where the window host reports KDE's decoration style.
  static FrostBackLook of(BuildContext context, {bool kde = false}) => switch (Theme.of(context).platform) {
    TargetPlatform.macOS || TargetPlatform.iOS => apple,
    TargetPlatform.linux => kde ? windows : gnome,
    TargetPlatform.android || TargetPlatform.fuchsia => material,
    TargetPlatform.windows => windows,
  };

  /// Whether the glyph is a chevron rather than an arrow.
  bool get chevron => this == apple || this == gnome;
}
