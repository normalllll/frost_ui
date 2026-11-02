import 'package:flutter/widgets.dart';

/// Shell-owned branding, also captured when tab overviews open on the Navigator.
/// Kept internal so apps configure the existing Shell brand rather than a
/// second, potentially inconsistent base-tab identity.
class FrostTabBrand extends InheritedWidget {
  const FrostTabBrand({required this.icon, required this.name, required super.child, super.key});

  final Widget? icon;
  final String? name;

  static FrostTabBrand? maybeOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<FrostTabBrand>();

  String label(String destination) => name == null || name!.isEmpty ? destination : '$name · $destination';

  @override
  bool updateShouldNotify(FrostTabBrand oldWidget) => icon != oldWidget.icon || name != oldWidget.name;
}
