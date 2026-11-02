part of 'picker.dart';

class _InlinePicker<T> extends _PickerImpl<T> {
  const _InlinePicker(super.picker);
  @override
  State<_PickerImpl<T>> createState() => _InlinePickerState<T>();
}

class _InlinePickerState<T> extends State<_PickerImpl<T>> with _PickerGroupFocus<T>, _PickerField<T> {
  @override
  FocusNode? get _focusTarget => _groupFocus;
  @override
  Widget build(BuildContext context) => FrostControlScope(
    size: widget.picker.size,
    child: _PickerGroupField<T>(
      owner: this,
      child: _PickerInline<T>(owner: this),
    ),
  );
}

class _PickerInline<T> extends StatelessWidget {
  const _PickerInline({required this.owner});
  final _PickerGroupFocus<T> owner;
  @override
  Widget build(BuildContext context) {
    final placement = FrostRowPlacement.of(context);
    final rows = [
      for (final (index, option) in owner.widget.picker.options.indexed)
        ExcludeFocusTraversal(
          excluding: index != owner._tabIndex,
          child: FrostRowFocus(
            focusNode: owner._nodes[index],
            child: Semantics(
              label: option.label,
              value: option.subtitle,
              checked: index == owner._selected,
              inMutuallyExclusiveGroup: true,
              enabled: owner._enabled && option.enabled,
              onTap: owner._enabled && option.enabled ? () => owner._choose(index) : null,
              excludeSemantics: true,
              child: FrostListRow(
                title: option.label,
                subtitle: option.subtitle == null ? null : FrostRowSubtitle(option.subtitle!),
                leading: FrostLeading.custom(FrostChoiceMark(value: index == owner._selected, kind: FrostChoiceKind.radio)),
                enabled: owner._enabled && option.enabled,
                onPressed: owner._enabled && option.enabled ? () => owner._choose(index) : null,
              ),
            ),
          ),
        ),
    ];
    return placement == null
        ? Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: rows)
        : FrostContiguousRows(corners: placement.corners ?? BorderRadius.zero, lastTextAnchor: placement.textAnchor, children: rows);
  }
}
