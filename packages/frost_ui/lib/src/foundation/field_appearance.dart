import 'package:flutter/widgets.dart';

enum FrostFieldAppearance { standard, composer, subtle, onMedia }

/// Shared appearance data stays below fields and overlay rendering.
class FrostFieldAppearanceData extends InheritedWidget {
  const FrostFieldAppearanceData({required this.appearance, required super.child, super.key});
  final FrostFieldAppearance? appearance;
  @override
  bool updateShouldNotify(FrostFieldAppearanceData oldWidget) => appearance != oldWidget.appearance;
}
