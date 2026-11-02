import 'package:flutter/widgets.dart';

import '../controls/buttons.dart';
import 'shell_navigation_scope.dart';

/// Place beside a custom/media Back. Page headers include this automatically.
/// An onMedia scope gives it the same circular media treatment as ordinary Back.
class FrostBackToFirstButton extends StatelessWidget {
  const FrostBackToFirstButton({super.key});
  @override
  Widget build(BuildContext context) {
    final navigation = FrostShellNavigationScope.maybeOf(context);
    final backToFirst = navigation?.backToFirst;
    if (backToFirst == null || !navigation!.showsBackToFirst) return const SizedBox.shrink();
    return FrostButton.icon(label: backToFirst.label, icon: backToFirst.icon, onPressed: backToFirst.onPressed);
  }
}
