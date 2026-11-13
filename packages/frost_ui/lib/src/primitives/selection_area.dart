import 'package:flutter/rendering.dart' show SelectedContent;
import 'package:flutter/widgets.dart';
import 'package:material_ui/material_ui.dart' show SelectionArea, SelectionAreaState;

import '../foundation/_key_bindings.dart';
import '_text_selection_chrome.dart';

/// Makes the text in [child] selectable across widgets with Frost's handles
/// and copy menu, for text the application lays out itself.
///
/// [onSelectionChanged] reports the selected content, or null once nothing is
/// selected. Escape clears a selection, as does a tap outside it; with nothing
/// selected Escape reaches the enclosing page. [FrostSelectionAreaState.clearSelection]
/// clears it from the application, through a [GlobalKey].
class FrostSelectionArea extends StatefulWidget {
  const FrostSelectionArea({required this.child, this.onSelectionChanged, super.key});
  final Widget child;
  final ValueChanged<SelectedContent?>? onSelectionChanged;
  @override
  State<FrostSelectionArea> createState() => FrostSelectionAreaState();
}

class FrostSelectionAreaState extends State<FrostSelectionArea> {
  final _area = GlobalKey<SelectionAreaState>();
  late final _clear = _ClearSelectionAction(this);
  bool _selected = false;

  void clearSelection() {
    _area.currentState?.selectableRegion.clearSelection();
    _changed(null);
  }

  void _changed(SelectedContent? content) {
    final selected = content != null && content.plainText.isNotEmpty;
    final report = selected || _selected;
    _selected = selected;
    if (report) widget.onSelectionChanged?.call(selected ? content : null);
  }

  @override
  // The region consumes DismissIntent even with nothing selected, so Escape is
  // bound here only while there is a selection; then it reaches the page.
  Widget build(BuildContext context) => FrostDismissKey(
    active: () => _selected,
    child: Actions(
      actions: {DismissIntent: _clear},
      child: SelectionArea(
        key: _area,
        selectionControls: frostTextSelectionControls,
        contextMenuBuilder: (context, state) => frostSelectionMenu(context, state.contextMenuAnchors, state.contextMenuButtonItems),
        onSelectionChanged: _changed,
        child: widget.child,
      ),
    ),
  );
}

/// Clears a selection; with nothing selected it hands the intent to the
/// enclosing page, since the region passes DismissIntent up only to the
/// nearest action and stops at a disabled one.
class _ClearSelectionAction extends Action<DismissIntent> {
  _ClearSelectionAction(this.area);
  final FrostSelectionAreaState area;
  Action<DismissIntent>? _outer(DismissIntent intent) => Actions.maybeFind<DismissIntent>(area.context, intent: intent);
  @override
  bool isEnabled(DismissIntent intent) => area._selected || (_outer(intent)?.isEnabled(intent) ?? false);
  @override
  Object? invoke(DismissIntent intent) {
    if (area._selected) {
      area.clearSelection();
      return null;
    }
    return Actions.maybeInvoke(area.context, intent);
  }
}
