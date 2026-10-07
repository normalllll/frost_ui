import 'package:frost_ui/src/controls/form_controls.dart';
import 'package:flutter/material.dart';
import 'package:frost_ui/src/controls/icon.dart';

class FrostSettingsSelectTile<T extends Object> extends StatelessWidget {
  const FrostSettingsSelectTile({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.items,
    required this.onChanged,
    this.enabled = true,
  });
  FrostSettingsSelectTile.values({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required List<T> values,
    required String Function(T) label,
    required this.onChanged,
    this.enabled = true,
  }) : items = [for (final item in values) FrostSelectItem(value: item, label: label(item))];

  final FrostIconData icon;
  final String title;
  final T value;
  final List<FrostSelectItem<T>> items;
  final ValueChanged<T> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: FrostIcon(icon, color: enabled ? null : Theme.of(context).disabledColor),
    title: ExcludeFocus(
      excluding: !enabled,
      child: IgnorePointer(
        ignoring: !enabled,
        child: Opacity(
          opacity: enabled ? 1 : 0.38,
          child: FrostSelect<T>(label: title, value: value, items: items, onChanged: onChanged),
        ),
      ),
    ),
  );
}
