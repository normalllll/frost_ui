import 'package:flutter/widgets.dart';

import 'typography.dart';

/// Page titles keep their hierarchy even when supplied as semantic FrostText.
class FrostPageTitleScope extends InheritedWidget {
  const FrostPageTitleScope({required this.role, required super.child, super.key});
  final FrostTextRole role;
  static FrostTextRole? of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<FrostPageTitleScope>()?.role;
  @override
  bool updateShouldNotify(FrostPageTitleScope oldWidget) => role != oldWidget.role;
}
