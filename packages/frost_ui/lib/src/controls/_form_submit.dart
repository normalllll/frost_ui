import 'package:flutter/widgets.dart';

/// Internal override for field completion in a composed submit surface.
/// Controller.submit bypasses this scope, preventing recursive submission.
/// A dialog's default action, for a field that finishes editing outside a form.
/// A null [submit] marks a surface inside the dialog that is not part of it.
class FrostDialogSubmitScope extends InheritedWidget {
  const FrostDialogSubmitScope({required this.submit, required super.child, super.key});
  final Future<void> Function()? submit;
  static Future<void> Function()? maybeOf(BuildContext context) => context.getInheritedWidgetOfExactType<FrostDialogSubmitScope>()?.submit;
  @override
  bool updateShouldNotify(FrostDialogSubmitScope oldWidget) => submit != oldWidget.submit;
}

class FrostFormSubmitScope extends InheritedWidget {
  const FrostFormSubmitScope({required this.submit, required super.child, super.key});
  final Future<bool> Function() submit;
  static Future<bool> Function()? maybeOf(BuildContext context) => context.getInheritedWidgetOfExactType<FrostFormSubmitScope>()?.submit;
  @override
  bool updateShouldNotify(FrostFormSubmitScope oldWidget) => submit != oldWidget.submit;
}
