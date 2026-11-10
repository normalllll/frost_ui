import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../feedback/_skeleton_geometry.dart';
import '../foundation/_control_geometry.dart';
import '../foundation/_key_bindings.dart';
import '../foundation/control_scope.dart';
import '../foundation/density.dart';
import '../foundation/metrics.dart';
import '../foundation/radius.dart';
import '../foundation/scope.dart';
import '../foundation/sizes.dart';
import '../foundation/spacing.dart';
import '../foundation/tokens.dart';
import '../foundation/typography.dart';
import '../lists/_contiguous_rows.dart';
import '../lists/_row_scope.dart';
import '../lists/list_row.dart';
import '../motion/_layout_identity.dart';
import '../motion/layout_crossfade.dart';
import '../motion/spring.dart';
import '../overlays/_menu_target.dart';
import '../overlays/_value_picker.dart';
import '../overlays/tooltip.dart';
import '../primitives/_click_feedback.dart';
import '../primitives/_icon_slot.dart';
import '../primitives/_spaced_wrap.dart';
import '../primitives/click_surface.dart';
import '../primitives/glyph.dart';
import '../primitives/icon.dart' show FrostIcon;
import '_button_control.dart';
import '_button_types.dart';
import '_choice_mark.dart';
import '_control_surfaces.dart';
import '_field_layout.dart';
import '_field_trigger.dart';
import '_input_surface.dart';
import '_picker_row_scope.dart';
import '_toolbar_geometry.dart';
import 'color_swatch.dart';
import 'form.dart';
import 'picker_option.dart';

part '_picker_inline.dart';
part '_picker_layout.dart';
part '_picker_menu.dart';
part '_picker_palette.dart';
part '_picker_segments.dart';
part '_picker_state.dart';

enum FrostPickerStyle { auto, menu, segmented, inline, palette }

/// A controlled, mutually exclusive value choice. Auto chooses palettes first,
/// then up to four subtitle-free segments when their real layout fits.
/// Rows always choose menus; toolbar menus stay anchored at compact widths.
/// Values must be distinct. An unmatched value leaves the group unselected;
/// null matches a nullable option's null value just like any other value.
/// Errors do not change the selected style. Menu errors outline the field;
/// other styles show supporting error text without outlining the group.
class FrostPicker<T> extends StatefulWidget {
  const FrostPicker({
    required this.options,
    required this.value,
    required this.onChanged,
    required this.label,
    this.style = FrostPickerStyle.auto,
    this.size,
    this.error,
    super.key,
  }) : trailingSwatch = null,
       _iconOnly = false;
  const FrostPicker.menu({required this.options, required this.value, required this.onChanged, required this.label, this.size, this.error, super.key})
    : style = FrostPickerStyle.menu,
      trailingSwatch = null,
      _iconOnly = false;
  const FrostPicker.segmented({
    required this.options,
    required this.value,
    required this.onChanged,
    required this.label,
    this.size,
    this.error,
    bool iconOnly = false,
    super.key,
  }) : style = FrostPickerStyle.segmented,
       trailingSwatch = null,
       // Keep the public parameter name independent from private storage.
       // ignore: prefer_initializing_formals
       _iconOnly = iconOnly;
  const FrostPicker.inline({required this.options, required this.value, required this.onChanged, required this.label, this.size, this.error, super.key})
    : style = FrostPickerStyle.inline,
      trailingSwatch = null,
      _iconOnly = false;
  const FrostPicker.palette({
    required this.options,
    required this.value,
    required this.onChanged,
    required this.label,
    this.size,
    this.error,
    this.trailingSwatch,
    super.key,
  }) : style = FrostPickerStyle.palette,
       _iconOnly = false;

  /// Optional final palette action, sharing arrow traversal and the group Tab
  /// stop. Its callback runs on activation, never when arrows merely focus it.
  /// App owns selected when the current custom colour is outside preset values.
  final FrostColorSwatch? trailingSwatch;
  final List<FrostPickerOption<T>> options;
  final T? value;
  final ValueChanged<T>? onChanged;
  final String label;
  final FrostPickerStyle style;
  final FrostControlSize? size;
  final String? error;
  final bool _iconOnly;
  @override
  State<FrostPicker<T>> createState() => _PickerHostState<T>();
}

/// Dispatches to one private implementation per style; each implementation
/// owns its own state. The public widget stays stateful so its type is
/// unchanged.
class _PickerHostState<T> extends State<FrostPicker<T>> {
  @override
  Widget build(BuildContext context) {
    final picker = widget;
    assert(picker.options.map((option) => option.value).toSet().length == picker.options.length);
    assert(!picker._iconOnly || picker.options.every((option) => option.leading.icon != null));
    assert(picker.style != FrostPickerStyle.palette || picker.options.every((option) => option.color != null));
    return switch (picker.style) {
      FrostPickerStyle.auto => _AutoPicker<T>(picker),
      FrostPickerStyle.menu => _MenuPicker<T>(picker),
      FrostPickerStyle.segmented => _SegmentedPicker<T>(picker),
      FrostPickerStyle.inline => _InlinePicker<T>(picker),
      FrostPickerStyle.palette => _PalettePicker<T>(picker),
    };
  }
}
