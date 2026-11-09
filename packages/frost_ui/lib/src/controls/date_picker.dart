import 'package:flutter/material.dart';

import '../foundation/control_scope.dart';
import '../foundation/scope.dart';
import '../foundation/sizes.dart';
import '../overlays/_popover_options.dart';
import '../overlays/popover.dart';
import '../overlays/sheet.dart';
import '../primitives/icon.dart';
import '_calendar.dart';
import '_field_clear_button.dart';
import '_field_trigger.dart';
import 'form.dart';

/// A localized date field. Incoming legacy values may be outside the bounds;
/// the calendar only lets users select dates inside them.
class FrostDatePicker extends StatefulWidget {
  FrostDatePicker({
    required this.value,
    required this.onChanged,
    required this.label,
    this.firstDate,
    this.lastDate,
    this.placeholder,
    this.help,
    this.error,
    this.clearable = false,
    this.showsYear = false,
    this.size,
    super.key,
  }) : assert(!frostFirstDate(firstDate).isAfter(frostLastDate(lastDate)));
  final DateTime? value;
  final ValueChanged<DateTime?>? onChanged;
  final String label;
  final DateTime? firstDate, lastDate;
  final String? placeholder, help, error;
  final bool clearable;

  /// Shows the value with its year and without its weekday, for dates that can
  /// fall outside the current year.
  final bool showsYear;
  final FrostControlSize? size;
  @override
  State<FrostDatePicker> createState() => _DatePickerState();
}

class _DatePickerState extends State<FrostDatePicker> {
  FocusNode? _focus;
  bool get _enabled => widget.onChanged != null && FrostControlScope.enabledOf(context);
  @override
  Widget build(BuildContext context) {
    final enabled = widget.onChanged != null && FrostControlScope.enabledOf(context);
    final today = FrostDateClock.todayOf(context), icons = FrostIconSet.of(context);
    return FrostFormFieldRegistration(
      focusOf: () => _focus,
      enabled: enabled,
      error: widget.error,
      child: FrostPopoverDetents(
        detents: const [FrostSheetDetent.fitted],
        child: FrostPopover(
          title: widget.label,
          maxWidth: frostCalendarCell(context) * 7 + frostCalendarPopoverInset,
          builder: (context, focus, toggle) {
            _focus = focus;
            return FrostFieldTrigger(
              label: widget.label,
              value: widget.value == null
                  ? widget.placeholder ?? ''
                  : frostFormatFieldDate(MaterialLocalizations.of(context), widget.value!, showsYear: widget.showsYear),
              onPressed: enabled ? toggle : null,
              focus: focus,
              size: widget.size,
              help: widget.help,
              error: widget.error,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.clearable)
                    FrostFieldClearButton(
                      visible: enabled && widget.value != null,
                      label: FrostScope.labelsOf(context).clear,
                      onClear: () {
                        if (_enabled) widget.onChanged!(null);
                      },
                    ),
                  FrostIcon(icons.calendar, size: (widget.size ?? FrostControlScope.sizeOf(context)).iconSize),
                ],
              ),
            );
          },
          contentBuilder: (context, close) => FrostCalendar(
            firstDate: frostFirstDate(widget.firstDate),
            lastDate: frostLastDate(widget.lastDate),
            today: today,
            start: widget.value == null ? null : frostDateOnly(widget.value!),
            onSelected: (date) {
              if (mounted && _enabled) widget.onChanged!(date);
              close();
            },
          ),
        ),
      ),
    );
  }
}
