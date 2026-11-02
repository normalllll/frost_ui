import 'package:flutter/widgets.dart';

import '../navigation/_shell_back_scope.dart';
import '../navigation/shell_navigation_scope.dart';

// Stands in for the shell's reselection events outside a shell; never fires.
final _noReselection = ValueNotifier<({int index, int sequence})>((index: -1, sequence: 0));

/// Back for a layer that a layout shows by itself, such as the routed page of
/// a narrow layout or the detail of a wide pane. While [onClose] is non-null,
/// the shell's Back (when the shell owns Back) and system back call it instead
/// of the app's route; while it is null, Back is left to the app's routes.
class FrostLocalBack extends StatelessWidget {
  const FrostLocalBack({required this.onClose, required this.child, super.key});
  final VoidCallback? onClose;
  final Widget child;

  /// [header] (or a page with its own header) whose Back calls [onClose].
  /// Without a shell-owned Back, the header offers Back itself.
  static Widget header(BuildContext context, VoidCallback onClose, Widget header) {
    final outer = FrostShellNavigationScope.maybeOf(context);
    return FrostShellNavigationScope(
      ownsBackControl: outer?.ownsBackControl ?? false,
      canGoBack: true,
      goBack: onClose,
      primaryReselection: outer?.primaryReselection ?? _noReselection,
      child: header,
    );
  }

  @override
  Widget build(BuildContext context) {
    final close = onClose;
    return FrostShellBackTarget(
      enabled: close != null && (FrostShellNavigationScope.maybeOf(context)?.ownsBackControl ?? false),
      onBack: () => close?.call(),
      child: PopScope<void>(
        canPop: close == null,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) close?.call();
        },
        child: child,
      ),
    );
  }
}
