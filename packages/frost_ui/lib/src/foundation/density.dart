import 'package:flutter/material.dart';

/// Spacing and control sizes chosen by the user's density setting. Text sizes
/// never follow density; they stay with the app's reading settings.
///
/// Carried in the theme built by `FrostTheme.build`; read it with [of].
@immutable
class FrostDensity extends ThemeExtension<FrostDensity> {
  const FrostDensity._({
    required this.name,
    required this.targetHeight,
    required this.controlHeight,
    required this.pointerFieldHeight,
    required this.pageInset,
    required this.rowPadding,
    required this.railWidth,
  });

  /// Touch-sized spacing: the design's original values.
  static const comfortable = FrostDensity._(
    name: 'comfortable',
    targetHeight: 44,
    controlHeight: 48,
    pointerFieldHeight: 44,
    pageInset: 16,
    rowPadding: 16,
    railWidth: 80,
  );

  /// Pointer-sized spacing for desktop windows.
  static const compact = FrostDensity._(
    name: 'compact',
    targetHeight: 36,
    controlHeight: 40,
    pointerFieldHeight: 40,
    pageInset: 12,
    rowPadding: 12,
    railWidth: 56,
  );

  static const values = [comfortable, compact];

  final String name;

  /// Height of compact targets: navigation and menu rows, small buttons.
  final double targetHeight;

  /// Height of icon buttons and full-size buttons.
  final double controlHeight;

  /// Height of text fields and selectors where input is by pointer; touch
  /// platforms keep [controlHeight] whatever the density.
  final double pointerFieldHeight;

  /// Distance between a page's content and its edges.
  final double pageInset;

  /// Vertical padding of a list row.
  final double rowPadding;

  /// Width of a collapsed flush sidebar.
  final double railWidth;

  static FrostDensity of(BuildContext context) => Theme.of(context).extension<FrostDensity>() ?? comfortable;

  @override
  FrostDensity copyWith() => this;

  @override
  FrostDensity lerp(ThemeExtension<FrostDensity>? other, double t) => t < .5 || other is! FrostDensity ? this : other;

  @override
  String toString() => 'FrostDensity.$name';
}
