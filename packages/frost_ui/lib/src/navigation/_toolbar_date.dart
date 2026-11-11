import 'package:flutter/material.dart';

import '../controls/_calendar.dart';
import '../controls/buttons.dart';
import '../foundation/scope.dart';
import '../foundation/spacing.dart';
import '../overlays/_popover_options.dart';
import '../overlays/popover.dart';
import '../overlays/sheet.dart';
import '../primitives/icon.dart';
import 'toolbar_menu_button.dart';

/// Library-only: the fields of a toolbar's one-line date choice, shared by its
/// trigger in the row and its entry in the overflow menu.
class FrostToolbarDateChoice {
  FrostToolbarDateChoice({
    required this.value,
    required this.onChanged,
    required this.label,
    required this.firstDate,
    required this.lastDate,
    required this.placeholder,
    required this.clearable,
    required this.showsYear,
  }) : assert(!frostFirstDate(firstDate).isAfter(frostLastDate(lastDate)));
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final String label;
  final DateTime? firstDate, lastDate;
  final String? placeholder;
  final bool clearable, showsYear;

  /// The chosen date, or the placeholder, or the label when there is neither.
  String valueText(BuildContext context) =>
      value == null ? placeholder ?? label : frostFormatFieldDate(MaterialLocalizations.of(context), value!, showsYear: showsYear);

  /// The calendar, with Clear below it while a date is chosen and the choice
  /// can be cleared. [close] runs after every choice.
  Widget calendar(BuildContext context, VoidCallback close) {
    final calendar = FrostCalendar(
      firstDate: frostFirstDate(firstDate),
      lastDate: frostLastDate(lastDate),
      today: FrostDateClock.todayOf(context),
      start: value == null ? null : frostDateOnly(value!),
      onSelected: (date) {
        onChanged(date);
        close();
      },
    );
    if (!clearable || value == null) return calendar;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        calendar,
        SizedBox(height: FrostGap.of(context).related),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: FrostButton.plain(
            label: FrostScope.labelsOf(context).clear,
            onPressed: () {
              onChanged(null);
              close();
            },
          ),
        ),
      ],
    );
  }

  /// Opens the calendar from the overflow menu, where the trigger is gone: a
  /// fitted sheet on a narrow window, a dialog otherwise.
  Future<void> open(BuildContext context) async {
    if (!context.mounted) return;
    await showFrostSheet<void>(
      context: context,
      title: label,
      detents: const [FrostSheetDetent.fitted],
      scrollable: false,
      builder: (context) {
        final route = ModalRoute.of(context)!;
        return calendar(context, () {
          if (context.mounted && route.isCurrent) Navigator.of(context).pop();
        });
      },
    );
  }
}

/// Library-only: the toolbar row's trigger for a [FrostToolbarDateChoice]. It
/// shows the value on one line; tooltips and screen readers keep the label.
class FrostToolbarDateButton extends StatelessWidget {
  const FrostToolbarDateButton({required this.choice, super.key});
  final FrostToolbarDateChoice choice;

  @override
  Widget build(BuildContext context) {
    final value = choice.valueText(context);
    final semantic = value == choice.label ? value : [choice.label, value].join(', ');
    return FrostPopoverDetents(
      detents: const [FrostSheetDetent.fitted],
      child: FrostPopover(
        title: choice.label,
        maxWidth: frostCalendarCell(context) * 7 + frostCalendarPopoverInset,
        builder: (context, focus, toggle) => FrostToolbarControl(
          label: value,
          semanticLabel: semantic,
          icon: FrostIconSet.of(context).calendar,
          focusNode: focus,
          onPressed: toggle,
          tooltip: semantic,
        ),
        contentBuilder: choice.calendar,
      ),
    );
  }
}
