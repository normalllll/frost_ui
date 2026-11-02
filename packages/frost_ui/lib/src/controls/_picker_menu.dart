part of 'picker.dart';

class _MenuPicker<T> extends _PickerImpl<T> {
  const _MenuPicker(super.picker);
  @override
  State<_PickerImpl<T>> createState() => _MenuPickerState<T>();
}

class _MenuPickerState<T> extends State<_PickerImpl<T>> with _PickerField<T> {
  FocusNode? _menuFocus;
  @override
  FocusNode? get _focusTarget => _menuFocus;
  @override
  Widget build(BuildContext context) => FrostControlScope(
    size: widget.picker.size,
    child: _PickerMenu<T>(picker: widget.picker, enabled: _enabled, onFocus: (focus) => _menuFocus = focus),
  );
}

/// The menu trigger: a field in forms, a plain button in rows and toolbars.
class _PickerMenu<T> extends StatelessWidget {
  const _PickerMenu({required this.picker, required this.enabled, required this.onFocus});
  final FrostPicker<T> picker;
  final bool enabled;

  /// Receives the trigger's focus node, the node a form focuses.
  final ValueSetter<FocusNode> onFocus;
  @override
  Widget build(BuildContext context) {
    final picker = this.picker, size = picker.size ?? FrostControlScope.sizeOf(context);
    final selected = picker.options.where((option) => option.value == picker.value).firstOrNull;
    final toolbar = FrostControlScope.toolbarOf(context), row = FrostPickerRowScope.of(context);
    final field = !toolbar && !row;
    // The icon slot of the trigger button, which an avatar glyph fills exactly.
    final slot = (toolbar ? frostToolbarButtonGeometry(context).iconSize : null) ?? (toolbar ? FrostControlSize.compact : size).iconSize;
    final glyph = selected?.leading.widget;
    final leading = glyph == null ? null : FrostIconSlot(size: slot, child: glyph);
    final trigger = FrostMenuTarget(
      child: FrostPickerMenuHost<T>(
        items: picker.options,
        value: picker.value,
        title: picker.label,
        enabled: enabled,
        onSelected: (value) {
          if (enabled) picker.onChanged!(value);
        },
        builder: (context, focus, toggle) {
          onFocus(focus);
          if (field) {
            return FrostFieldTrigger(
              label: picker.label,
              value: selected?.label ?? '',
              leading: selected?.leading.icon,
              leadingWidget: leading,
              focus: focus,
              onPressed: enabled ? toggle : null,
              size: size,
              error: picker.error,
              chevron: FrostButtonChevron.upDown,
            );
          }
          return FrostButtonControl(
            label: selected?.label ?? '',
            semanticLabel: selected == null ? picker.label : [picker.label, selected.label].join(', '),
            icon: selected?.leading.icon,
            iconWidget: leading,
            focusNode: focus,
            onPressed: enabled ? toggle : null,
            size: toolbar ? FrostControlSize.compact : size,
            variant: FrostButtonVariant.plain,
            chevron: toolbar ? FrostButtonChevron.down : FrostButtonChevron.upDown,
            textRole: FrostTextRole.callout,
            geometry: toolbar ? frostToolbarButtonGeometry(context) : null,
            truncates: toolbar,
            wrapsLabel: !toolbar,
          );
        },
      ),
    );
    return field || picker.error == null ? trigger : FrostFieldLayout(error: picker.error, enabled: enabled, child: trigger);
  }
}
