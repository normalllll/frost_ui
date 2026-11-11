part of 'toolbar.dart';

enum FrostToolbarPriority { high, normal, low }

sealed class FrostToolbarItem {
  const FrostToolbarItem(this.priority);
  final FrostToolbarPriority priority;

  /// Pass [disabledReason] with a null [onPressed] to say why the action is
  /// unavailable. It shows in the tooltip (below the label for an icon-only
  /// action), is the semantics hint, and shows on the overflow menu item.
  factory FrostToolbarItem.action({
    required FrostIconData icon,
    required String label,
    VoidCallback? onPressed,
    String? disabledReason,
    FrostToolbarPriority priority,
    bool showsLabel,
  }) = _Action;
  static FrostToolbarItem picker<T>({
    required List<FrostPickerOption<T>> choices,
    required T value,
    required ValueChanged<T> onChanged,
    required String label,
    FrostToolbarPriority priority = FrostToolbarPriority.normal,
  }) => _Picker<T>(choices, value, onChanged, label, priority);

  /// Pass [valueLabel] for a selector: its trigger shows the current value,
  /// and overflow/accessibility retain the selector purpose in [label].
  factory FrostToolbarItem.menu({
    required String label,
    required List<FrostMenuEntry> entries,
    String? valueLabel,
    FrostIconData? icon,
    bool showsLabel,
    FrostToolbarPriority priority,
  }) = _Menu;

  /// Sort trigger and overflow submenu generated from one set of fields.
  static FrostToolbarItem sortMenu<T>({
    required List<FrostPickerOption<T>> fields,
    required T value,
    required bool ascending,
    required void Function(T field, bool ascending) onChanged,
    required String label,
    FrostToolbarPriority priority = FrostToolbarPriority.normal,
  }) => _SortMenu<T>(fields, value, ascending, onChanged, label, priority);

  /// Pass [plated] when [builder] returns a text button with a filled plate. It
  /// sits at the end of the [minWidth] slot, and at the end of the row its plate
  /// lines up with the content edge, like a field below it. Without [plated] the
  /// slot reaches past that edge by the inset of an unfilled text button.
  factory FrostToolbarItem.custom({
    required WidgetBuilder builder,
    required double minWidth,
    required FrostMenuEntry overflowEntry,
    FrostToolbarPriority priority,
    bool plated,
  }) = _Custom;
  bool get _canCompact;

  /// Whether the item shows as a bare icon target in this form.
  bool _iconOnly(bool compact) => false;

  /// Whether the item draws a filled plate in this form, which starts on the
  /// content edge when the item comes first in the row.
  bool _platedIn(bool compact) => false;
  bool get _isOverflowGroup => false;
  bool get _isPicker => false;
  Widget _build(BuildContext context, bool compact);
  FrostMenuEntry _overflow(BuildContext context);
}

class _Action extends FrostToolbarItem {
  const _Action({
    required this.icon,
    required this.label,
    this.onPressed,
    this.disabledReason,
    FrostToolbarPriority priority = FrostToolbarPriority.normal,
    this.showsLabel = false,
  }) : super(priority);
  final FrostIconData icon;
  final String label;
  final VoidCallback? onPressed;
  final String? disabledReason;
  final bool showsLabel;
  @override
  bool get _canCompact => showsLabel;
  @override
  bool _iconOnly(bool compact) => !showsLabel || compact;
  @override
  Widget _build(BuildContext context, bool compact) {
    final reason = onPressed == null ? disabledReason : null;
    final iconOnly = _iconOnly(compact);
    final control = FrostToolbarControl(
      label: label,
      icon: icon,
      showsLabel: showsLabel && !compact,
      onPressed: onPressed,
      tooltip: reason != null && !iconOnly ? reason : null,
    );
    if (reason == null || !iconOnly) return control;
    // The tooltip reads label then reason, while semantics already carry the
    // label, so the hint is the reason alone. The control's own label tooltip
    // is hidden in favour of this one.
    return FrostTooltip(
      message: '$label\n$reason',
      excludeFromSemantics: true,
      child: MergeSemantics(
        child: Semantics(
          hint: reason,
          child: TooltipVisibility(visible: false, child: control),
        ),
      ),
    );
  }

  @override
  // The menu item has no secondary-text slot; its tooltip carries the reason.
  FrostMenuEntry _overflow(BuildContext context) =>
      FrostMenuAction(label, leading: FrostGlyph.icon(icon), onSelected: onPressed, tooltip: onPressed == null ? disabledReason : null);
}

class _Picker<T> extends FrostToolbarItem {
  const _Picker(this.choices, this.value, this.onChanged, this.label, super.priority) : assert(choices.length > 0);
  final List<FrostPickerOption<T>> choices;
  final T value;
  final ValueChanged<T> onChanged;
  final String label;
  List<FrostMenuEntry> get _entries => [
    for (final choice in choices)
      FrostMenuAction(choice.label, leading: choice.leading, checked: choice.value == value, onSelected: choice.enabled ? () => onChanged(choice.value) : null),
  ];
  @override
  bool get _canCompact => true;
  @override
  bool get _isPicker => true;
  @override
  bool _platedIn(bool compact) => !compact;
  @override
  Widget _build(BuildContext context, bool compact) => compact
      ? FrostPicker<T>.menu(value: value, options: choices, onChanged: onChanged, label: label)
      : FrostPicker<T>.segmented(options: choices, value: value, onChanged: onChanged, label: label);
  @override
  FrostMenuEntry _overflow(BuildContext context) =>
      FrostMenuSubmenu(_overflowChoiceLabel(label, choices.where((choice) => choice.value == value).firstOrNull?.label), entries: _entries);
}

class _Menu extends FrostToolbarItem {
  const _Menu({
    required this.label,
    required this.entries,
    this.icon,
    this.valueLabel,
    this.showsLabel = true,
    FrostToolbarPriority priority = FrostToolbarPriority.normal,
  }) : assert(showsLabel || icon != null),
       super(priority);
  final String label;
  final List<FrostMenuEntry> entries;
  final String? valueLabel;
  final FrostIconData? icon;
  final bool showsLabel;
  @override
  bool get _canCompact => false;
  @override
  bool _iconOnly(bool compact) => !showsLabel;
  @override
  bool get _isOverflowGroup => !showsLabel;
  @override
  Widget _build(BuildContext context, bool compact) =>
      FrostToolbarMenuButton(label: label, valueLabel: valueLabel, entries: entries, icon: icon, showsLabel: showsLabel);
  @override
  FrostMenuEntry _overflow(BuildContext context) => !showsLabel && label == FrostScope.labelsOf(context).more
      ? FrostMenuSection(entries: entries)
      : FrostMenuSubmenu(_overflowChoiceLabel(label, valueLabel), leading: icon == null ? null : FrostGlyph.icon(icon!), entries: entries);
}

class _Custom extends FrostToolbarItem {
  const _Custom({
    required this.builder,
    required this.minWidth,
    required this.overflowEntry,
    FrostToolbarPriority priority = FrostToolbarPriority.normal,
    this.plated = false,
  }) : assert(minWidth >= 0 && minWidth < double.infinity),
       super(priority);
  final WidgetBuilder builder;
  final double minWidth;
  final FrostMenuEntry overflowEntry;
  final bool plated;
  @override
  bool get _canCompact => false;
  @override
  bool _platedIn(bool compact) => plated;
  @override
  bool get _isOverflowGroup => overflowEntry is FrostMenuSection;
  @override
  Widget _build(BuildContext context, bool compact) => SizedBox(
    width: minWidth,
    child: plated
        ? Align(
            alignment: AlignmentDirectional.centerEnd,
            heightFactor: 1,
            child: Builder(builder: builder),
          )
        : Builder(builder: builder),
  );
  @override
  FrostMenuEntry _overflow(BuildContext context) => overflowEntry;
}

class _SortMenu<T> extends FrostToolbarItem {
  _SortMenu(this.fields, this.value, this.ascending, this.onChanged, this.label, super.priority)
    : assert(fields.isNotEmpty),
      assert(fields.map((field) => field.value).toSet().length == fields.length);
  final List<FrostPickerOption<T>> fields;
  final T value;
  final bool ascending;
  final void Function(T field, bool ascending) onChanged;
  final String label;
  @override
  bool get _canCompact => false;
  @override
  Widget _build(BuildContext context, bool compact) => FrostSortMenu<T>(fields: fields, value: value, ascending: ascending, onChanged: onChanged, label: label);
  @override
  FrostMenuEntry _overflow(BuildContext context) => FrostMenuSubmenu(
    _overflowChoiceLabel(label, fields.where((field) => field.value == value).firstOrNull?.label),
    entries: frostSortMenuEntries(context, fields: fields, value: value, ascending: ascending, onChanged: onChanged),
  );
}

// Overflow selectors keep their purpose after the visible value leaves its
// original toolbar context. Unknown values retain the selector name alone.
String _overflowChoiceLabel(String label, String? value) => value == null || value == label ? label : [label, value].join(' · ');
