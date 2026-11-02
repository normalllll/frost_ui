import 'package:flutter/widgets.dart';

import '../primitives/glyph.dart';

/// One value option across menus, segments, inline rows and color palettes.
/// color is palette data; other styles deliberately ignore it.
@immutable
class FrostPickerOption<T> {
  const FrostPickerOption({required this.value, required this.label, this.leading, this.subtitle, this.enabled = true, this.color});
  final T value;
  final String label;

  /// Drawn at the icon size of each control that shows the option: the
  /// collapsed menu trigger, anchored menu rows and compact sheet rows. An
  /// avatar is excluded from semantics; [label] speaks for the option.
  final FrostGlyph? leading;
  final String? subtitle;
  final bool enabled;
  final Color? color;
}
