import 'package:flutter/widgets.dart';

import '../foundation/_row_metrics.dart';
import '../foundation/control_scope.dart';
import '../foundation/spacing.dart';
import '../lists/_row_scope.dart';
import '../lists/list_row.dart';
import '../motion/_user_selection_draw.dart';
import '../primitives/glyph.dart';
import '../primitives/keyline.dart';
import '_choice_mark.dart';
import 'form.dart';

/// An entire list row toggles one checkbox and exposes one checked/mixed node.
///
/// In a form column (under FrostForm or FrostFormSection, outside a grouped
/// list) the mark sits on the fields' leading edge, and the row's hover and
/// press fill reaches past the field edges into the surrounding padding.
class FrostCheckboxRow extends StatelessWidget {
  const FrostCheckboxRow({required this.title, this.subtitle, required this.value, required this.onChanged, this.tristate = false, super.key})
    : assert(tristate || value != null);
  final String title;
  final String? subtitle;
  final bool? value;
  final ValueChanged<bool?>? onChanged;
  final bool tristate;
  @override
  Widget build(BuildContext context) {
    final enabled = onChanged != null && FrostControlScope.enabledOf(context);
    final formColumn = FrostFormOrder.of(context).isNotEmpty && FrostRowPlacement.of(context) == null && FrostListItemScope.of(context) == null;
    return FrostUserSelectionDraw(
      selected: value,
      onActivate: enabled ? () => onChanged?.call(frostNextCheckboxValue(value, tristate)) : null,
      builder: (context, trigger, activate) {
        Widget row = FrostListRow(
          title: title,
          subtitle: subtitle == null ? null : FrostRowSubtitle(subtitle!),
          leading: FrostLeading.custom(
            formColumn
                // The mark's own edge, not its icon column, meets the field edge.
                ? SizedBox(
                    width: frostRowIconColumn,
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: FrostChoiceMark(value: value, drawTrigger: trigger),
                    ),
                  )
                : FrostChoiceMark(value: value, drawTrigger: trigger),
          ),
          enabled: enabled,
          onPressed: enabled ? activate : null,
        );
        if (formColumn) {
          // A field-aligned keyline with room for the row's own bleed.
          final room = FrostGap.of(context).hitInset;
          row = FrostKeyline(
            leadingRoom: room,
            trailingRoom: room,
            edgeDistanceStart: room,
            edgeDistanceEnd: room,
            insideContainer: false,
            contentStart: 0,
            child: row,
          );
        }
        return Semantics(
          label: title,
          value: subtitle,
          checked: value == true,
          mixed: tristate ? value == null : null,
          enabled: enabled,
          onTap: enabled ? activate : null,
          excludeSemantics: true,
          child: row,
        );
      },
    );
  }
}
