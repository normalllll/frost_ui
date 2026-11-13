import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:material_ui/material_ui.dart' show Theme, ThemeExtension;

import '_missing_theme.dart';
import 'sizes.dart';

/// Density chooses spacing; the device's baseline input chooses the pointer or
/// touch control column, so a late mouse or touch never moves a control. Text
/// sizes follow typography and the app's reading settings.
///
/// Carried in the theme built by `FrostTheme.build`; read it with [of].
@immutable
class FrostDensity extends ThemeExtension<FrostDensity> {
  const FrostDensity._({
    required this.name,
    required this.pageInset,
    required this.rowPadding,
    required this.railWidth,
    this.platform = TargetPlatform.windows,
  });

  /// Comfortable spacing; control visuals still follow the platform column.
  static const comfortable = FrostDensity._(name: 'comfortable', pageInset: 16, rowPadding: 16, railWidth: 80);

  /// Pointer-sized spacing for desktop windows.
  static const compact = FrostDensity._(name: 'compact', pageInset: 12, rowPadding: 12, railWidth: 56);

  static const values = [comfortable, compact];

  final String name;
  final TargetPlatform platform;
  bool get _pointer => platform == TargetPlatform.windows || platform == TargetPlatform.macOS || platform == TargetPlatform.linux;

  /// The device's baseline input. The operating system is the only signal
  /// Flutter gives before the first event; what the user is doing now is
  /// `FrostInputCapability`.
  bool get usesPointer => _pointer;
  double heightFor(FrostControlSize size) => size.visualHeight(touch: !_pointer);
  FrostDensity forPlatform(TargetPlatform value) =>
      value == platform ? this : FrostDensity._(name: name, pageInset: pageInset, rowPadding: rowPadding, railWidth: railWidth, platform: value);

  /// Height of compact targets: navigation and menu rows, small buttons.
  double get targetHeight => math.max(heightFor(FrostControlSize.compact), FrostControlSize.minimumHitHeight(touch: !_pointer));

  /// Height of icon buttons and full-size buttons.
  double get controlHeight => heightFor(FrostControlSize.regular);

  /// Height of text fields and selectors where input is by pointer; touch
  /// platforms keep [controlHeight] whatever the density.
  double get pointerFieldHeight => heightFor(FrostControlSize.regular);

  /// Distance between a page's content and its edges.
  final double pageInset;

  /// Vertical padding of a list row.
  final double rowPadding;

  /// Width of a collapsed flush sidebar.
  final double railWidth;

  static FrostDensity of(BuildContext context) {
    final density = Theme.of(context).extension<FrostDensity>();
    if (density == null) throw frostMissingThemeError('FrostDensity');
    return density;
  }

  @override
  FrostDensity copyWith() => this;

  @override
  FrostDensity lerp(ThemeExtension<FrostDensity>? other, double t) => t < .5 || other is! FrostDensity ? this : other;

  @override
  String toString() => 'FrostDensity.$name';
}
