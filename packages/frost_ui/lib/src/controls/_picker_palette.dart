part of 'picker.dart';

// Color is data: keep the fixed swatch, spacing and selected-ring geometry.
const _swatchGap = 8.0;

class _PalettePicker<T> extends _PickerImpl<T> {
  const _PalettePicker(super.picker);
  @override
  State<_PickerImpl<T>> createState() => _PalettePickerState<T>();
}

class _PalettePickerState<T> extends State<_PickerImpl<T>> with _PickerGroupFocus<T>, _PickerField<T> {
  @override
  FrostColorSwatch? get _trailing => widget.picker.trailingSwatch;
  @override
  FocusNode? get _focusTarget => _groupFocus;
  @override
  Widget build(BuildContext context) => FrostControlScope(
    size: widget.picker.size,
    child: _PickerGroupField<T>(
      owner: this,
      child: _PickerPalette<T>(owner: this),
    ),
  );
}

class _PickerPalette<T> extends StatelessWidget {
  const _PickerPalette({required this.owner});
  final _PickerGroupFocus<T> owner;
  @override
  Widget build(BuildContext context) => FrostSpacedWrap(
    spacing: _swatchGap,
    runSpacing: _swatchGap,
    children: [
      for (final (index, option) in owner.widget.picker.options.indexed)
        ExcludeFocusTraversal(
          excluding: index != owner._tabIndex,
          child: FrostColorSwatch(
            color: option.color!,
            label: option.label,
            icon: option.leading.icon,
            selected: index == owner._selected,
            focusNode: owner._nodes[index],
            onPressed: owner._enabled && option.enabled ? () => owner._choose(index) : null,
          ),
        ),
      if (owner._trailing case final swatch?)
        ExcludeFocusTraversal(
          excluding: owner.widget.picker.options.length != owner._tabIndex,
          child: FrostColorSwatch(
            key: swatch.key,
            color: swatch.color,
            label: swatch.label,
            selected: swatch.selected,
            icon: swatch.icon,
            focusNode: owner._node(owner.widget.picker.options.length),
            onPressed: owner._enabled && swatch.onPressed != null ? () => owner._choose(owner.widget.picker.options.length) : null,
          ),
        ),
    ],
  );
}
