import 'package:flutter/material.dart';
import 'package:frost_ui/src/layout/auto_scaffold.dart';
import 'package:frost_ui/src/foundation/metrics.dart';
import 'package:frost_ui/src/foundation/tokens.dart';
import 'package:frost_ui/src/layout/grouped_settings_list.dart';

/// Settings split into sections: a section list beside the selected group on
/// wide windows, every group in one list otherwise.
class FrostSettingsSections extends StatefulWidget {
  const FrostSettingsSections({required this.labels, required this.groups, this.status, super.key}) : assert(labels.length == groups.length);

  final List<String> labels;
  final List<List<Widget>> groups;

  /// A row kept above the selected group on wide windows and above all
  /// groups otherwise, such as a pending save or a sync state.
  final Widget? status;

  @override
  State<FrostSettingsSections> createState() => _SettingsSectionsState();
}

class _SettingsSectionsState extends State<FrostSettingsSections> {
  static const _sectionListWidth = 200.0;

  int _selected = 0;
  @override
  Widget build(BuildContext context) {
    final tokens = FrostThemeTokens.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        if (!FrostAutoScaffold.usesHorizontalLayoutOf(context) || constraints.maxWidth < 720) {
          return FrostGroupedSettingsList(
            groups: [
              if (widget.status case final status?) [status],
              ...widget.groups,
            ],
          );
        }
        // The section list and the groups share the pages' content column:
        // the list starts at the column's left edge and the groups end at its
        // right edge, while the groups' scroll view still reaches the window
        // edge for its scrollbar.
        final column = FrostMetrics.columnPadding(constraints.maxWidth, maxWidth: FrostMetrics.settingsMaxWidth);
        return SafeArea(
          child: Row(
            children: [
              SizedBox(
                width: column.left + _sectionListWidth,
                child: ListView.builder(
                  padding: EdgeInsets.fromLTRB(column.left, FrostMetrics.sectionGap, 0, FrostMetrics.sectionGap),
                  itemCount: widget.labels.length,
                  itemBuilder: (context, index) => ListTile(
                    selected: _selected == index,
                    selectedTileColor: tokens.selectionFill,
                    selectedColor: tokens.selectionInk,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(FrostMetrics.controlRadius)),
                    title: Text(widget.labels[index]),
                    onTap: () => setState(() => _selected = index),
                  ),
                ),
              ),
              const SizedBox(width: FrostMetrics.sectionGap),
              Expanded(
                child: FrostGroupedSettingsList(
                  key: PageStorageKey('settings-$_selected'),
                  groups: [
                    if (widget.status case final status?) [status],
                    widget.groups[_selected],
                  ],
                  horizontalPadding: EdgeInsets.only(right: column.right),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
