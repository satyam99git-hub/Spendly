import 'package:flutter/material.dart';

import '../../../../core/utils/form_dates.dart';

/// Date and time entry for the FIR form, returning values already in the wire
/// format so no caller has to remember what that is.
///
/// Both return null when the picker is dismissed. Callers must treat that as
/// "unchanged", never as "cleared" — clearing is a separate affordance on the
/// field itself, because a mis-tapped Cancel that wiped the date of occurrence
/// would be indistinguishable from an intentional one.

/// The earliest date any entry on this form can refer to.
///
/// Not a limit on the offence — it is a floor on the *date picker*, which needs
/// one to render a scrollable year list at all. 1900 clears any complainant's
/// date of birth by a comfortable margin.
final _earliest = DateTime(1900);

/// Opens the calendar. [lastDate] defaults to today: nothing on an FIR happens
/// in the future, and a picker that offers next month invites a typo that ends
/// up in a statutory record.
Future<String?> pickWireDate(
  BuildContext context, {
  required String current,
  String? helpText,
  DateTime? firstDate,
  DateTime? lastDate,
}) async {
  final now = DateTime.now();
  final last = lastDate ?? DateTime(now.year, now.month, now.day);
  final first = firstDate ?? _earliest;

  var initial = FormDates.parseWireDate(current) ?? last;
  // A restored draft can hold a date outside the range this particular field
  // allows; showDatePicker asserts on that rather than clamping.
  if (initial.isBefore(first)) initial = first;
  if (initial.isAfter(last)) initial = last;

  final picked = await showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: first,
    lastDate: last,
    helpText: helpText,
  );

  return picked == null ? null : FormDates.toWireDate(picked);
}

/// Opens the clock. Always starts in dial mode; the input mode's am/pm toggle
/// invites a 12-hour reading of a column every other FIR records in 24-hour.
Future<String?> pickWireTime(
  BuildContext context, {
  required String current,
  String? helpText,
}) async {
  final existing = FormDates.parseWireTime(current);
  final now = TimeOfDay.now();

  final picked = await showTimePicker(
    context: context,
    initialTime: existing == null
        ? now
        : TimeOfDay(hour: existing.hour, minute: existing.minute),
    helpText: helpText,
    builder: (context, child) => MediaQuery(
      // Forces the 24-hour dial regardless of the handset's locale setting, so
      // the value shown while picking matches the value that gets stored.
      data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
      child: child!,
    ),
  );

  return picked == null ? null : FormDates.toWireTime(picked.hour, picked.minute);
}
