import 'package:flutter/material.dart' show SelectionArea, SelectionAreaState;
import 'package:flutter/rendering.dart' show SelectedContent;
import 'package:flutter/widgets.dart';

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
  Widget build(BuildContext context) => Actions(
    actions: {DismissIntent: _clear},
    child: SelectionArea(
      key: _area,
      selectionControls: frostTextSelectionControls,
      contextMenuBuilder: (context, state) => frostSelectionMenu(context, state.contextMenuAnchors, state.contextMenuButtonItems),
      onSelectionChanged: _changed,
      child: widget.child,
    ),
  );
}

class _ClearSelectionAction extends Action<DismissIntent> {
  _ClearSelectionAction(this.area);
  final FrostSelectionAreaState area;
  @override
  bool isEnabled(DismissIntent intent) => area._selected;
  @override
  void invoke(DismissIntent intent) => area.clearSelection();
}
