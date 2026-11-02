import 'package:flutter/widgets.dart';

import '../foundation/icon_data.dart';
import '../foundation/scope.dart';
import '../foundation/sizes.dart';
import '../primitives/presence.dart';
import '_button_parts.dart';
import 'buttons.dart';

/// The single expanding clear accessory for ordinary and search inputs.
class FrostFieldClearButton extends StatelessWidget {
  const FrostFieldClearButton({required this.visible, required this.onClear, this.label, super.key});
  final bool visible;

  /// Defaults to the clear-text label.
  final String? label;
  final VoidCallback onClear;
  @override
  Widget build(BuildContext context) => FrostPresence(
    visible: visible,
    effect: FrostPresenceEffect.expand,
    axis: Axis.horizontal,
    child: FrostFieldIconScope(
      child: FrostButton.icon(
        icon: FrostIconSet.of(context).close,
        label: label ?? FrostScope.labelsOf(context).clearText,
        size: FrostControlSize.compact,
        onPressed: onClear,
      ),
    ),
  );
}
