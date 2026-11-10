part of 'picker.dart';

/// One style's private implementation of [FrostPicker].
abstract class _PickerImpl<T> extends StatefulWidget {
  const _PickerImpl(this.picker);
  final FrostPicker<T> picker;
}

/// Enabled resolution and form registration, shared by every style.
mixin _PickerField<T> on State<_PickerImpl<T>> {
  FrostFormCoordinator? _form;
  late final _formField = FrostFormFieldHandle(
    context: context,
    focusOf: () => _focusTarget,
    errorOf: () => widget.picker.error != null,
    enabledOf: () => _enabled,
  );

  /// The node a form focuses for this field.
  FocusNode? get _focusTarget;
  bool get _enabled => widget.picker.onChanged != null && FrostControlScope.enabledOf(context) && widget.picker.options.isNotEmpty;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final form = FrostFormScope.maybeOf(context);
    if (_form != form) {
      _form?.unregister(_formField);
      _form = form;
      _form?.register(_formField);
    }
    _formField.order = FrostFormOrder.of(context);
  }

  @override
  void dispose() {
    _form?.unregister(_formField);
    super.dispose();
  }
}

/// One focus node per item, a single Tab stop and arrow-key traversal that
/// selects as it moves; shared by the segmented, inline and palette groups.
mixin _PickerGroupFocus<T> on State<_PickerImpl<T>> {
  final _nodes = <FocusNode>[];
  int? _active;
  bool get _enabled;

  /// An optional final action after the options; only palettes have one.
  FrostColorSwatch? get _trailing => null;
  List<FrostPickerOption<T>> get _options => widget.picker.options;
  int get _itemCount => _options.length + (_trailing == null ? 0 : 1);
  FocusNode _node(int index) => index < _options.length ? _nodes[index] : _trailing?.focusNode ?? _nodes[index];
  bool _itemEnabled(int index) => index < _options.length ? _options[index].enabled : _trailing?.onPressed != null;
  int? get _selected {
    if (_trailing?.selected ?? false) return null;
    final index = _options.indexWhere((option) => option.value == widget.picker.value);
    return index < 0 ? null : index;
  }

  int? get _tabIndex {
    if (!_enabled) return null;
    if (_active case final active? when active < _itemCount && _itemEnabled(active)) return active;
    if (_trailing case final swatch? when swatch.selected && swatch.onPressed != null) return _options.length;
    if (_selected case final selected? when _options[selected].enabled) return selected;
    final first = _options.indexWhere((option) => option.enabled);
    return first < 0 ? null : first;
  }

  FocusNode? get _groupFocus => _tabIndex == null ? null : _node(_tabIndex!);
  void _syncNodes() {
    while (_nodes.length < _itemCount) {
      _nodes.add(FocusNode());
    }
    while (_nodes.length > _itemCount) {
      _nodes.removeLast().dispose();
    }
  }

  @override
  void initState() {
    super.initState();
    _syncNodes();
  }

  @override
  void didUpdateWidget(covariant _PickerImpl<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncNodes();
    if (oldWidget.picker.value != widget.picker.value) _active = _selected;
    if (widget.picker.onChanged == null) _active = null;
  }

  @override
  void dispose() {
    for (final node in _nodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _choose(int index, {bool activate = true}) {
    if (!_enabled || !_itemEnabled(index)) return;
    setState(() => _active = index);
    _node(index).requestFocus();
    if (index == _options.length) {
      if (activate) _trailing?.onPressed?.call();
      return;
    }
    if (_options[index].value != widget.picker.value || _selected == null) widget.picker.onChanged!(_options[index].value);
  }

  /// The arrows move the selection to the next enabled option, wrapping.
  Map<ShortcutActivator, bool Function()> get _keys {
    bool rtl() => Directionality.of(context) == TextDirection.rtl;
    return {
      const FrostKeyPress(LogicalKeyboardKey.arrowDown): () => _step(1),
      const FrostKeyPress(LogicalKeyboardKey.arrowUp): () => _step(-1),
      const FrostKeyPress(LogicalKeyboardKey.arrowRight): () => _step(rtl() ? -1 : 1),
      const FrostKeyPress(LogicalKeyboardKey.arrowLeft): () => _step(rtl() ? 1 : -1),
    };
  }

  bool _step(int direction) {
    if (!_enabled || _options.isEmpty) return false;
    var index = List.generate(_itemCount, _node).indexWhere((node) => node.hasFocus);
    if (index < 0) index = _tabIndex ?? 0;
    for (var tried = 0; tried < _itemCount; tried++) {
      index = (index + direction) % _itemCount;
      if (_itemEnabled(index)) {
        _choose(index, activate: false);
        break;
      }
    }
    return true;
  }
}

/// The sliding thumb's position: it stays on the last selected segment while
/// nothing is selected.
mixin _PickerSegmentThumb<T> on _PickerGroupFocus<T> {
  int _thumbIndex = 0;

  @override
  void initState() {
    super.initState();
    _thumbIndex = _selected ?? 0;
  }

  @override
  void didUpdateWidget(covariant _PickerImpl<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_selected case final selected?) _thumbIndex = selected;
  }
}

/// The labelled group around segments, inline rows and palettes: one
/// semantics container, the arrow-key handler and supporting error text.
class _PickerGroupField<T> extends StatelessWidget {
  const _PickerGroupField({required this.owner, required this.child, this.measurement = false});
  final _PickerGroupFocus<T> owner;
  final bool measurement;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final picker = owner.widget.picker;
    final group = Semantics(
      container: true,
      explicitChildNodes: true,
      label: picker.label,
      child: measurement ? child : FrostKeyBindings(bindings: owner._keys, child: child),
    );
    // Group controls keep their intrinsic width, including in toolbar probes.
    return FrostFieldLayout(stretch: false, error: measurement ? null : picker.error, enabled: owner._enabled, supportingPresence: true, child: group);
  }
}
