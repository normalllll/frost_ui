import 'package:flutter/material.dart';
import 'package:frost_ui/src/foundation/metrics.dart';
import 'package:frost_ui/src/surface/grouped_rows.dart';

class FrostGroupedSettingsList extends StatelessWidget {
  const FrostGroupedSettingsList({required this.groups, this.horizontalPadding, super.key});

  final List<List<Widget>> groups;

  /// Defaults to the shared content column; a split settings pane passes the
  /// part of the column its list occupies.
  final EdgeInsets? horizontalPadding;

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.sizeOf(context).width >= 600 ? FrostMetrics.sectionGap : FrostMetrics.pageInset;

    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontal = horizontalPadding ?? FrostMetrics.columnPadding(constraints.maxWidth, maxWidth: FrostMetrics.settingsMaxWidth);
        return ListView.separated(
          primary: false,
          padding: EdgeInsets.fromLTRB(
            horizontal.left,
            topPadding + MediaQuery.paddingOf(context).top,
            horizontal.right,
            28 + MediaQuery.paddingOf(context).bottom,
          ),
          itemCount: groups.length,
          separatorBuilder: (_, _) => const SizedBox(height: FrostMetrics.itemGap),
          itemBuilder: (context, groupIndex) {
            final items = groups[groupIndex];
            return FrostGroupedRows(children: items);
          },
        );
      },
    );
  }
}
