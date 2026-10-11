/// Date and time formatting for the statutory forms.
///
/// Two representations, and the split is deliberate:
///
///   - **wire** — `yyyy-MM-dd` and `HH:mm`. Exactly what the website's `<input
///     type="date">` and `<input type="time">` post, so an FIR filed from the
///     app is byte-identical in the database to one filed from a desk. The
///     server stores these as opaque strings and never parses them, which means
///     the app is the only thing keeping the column consistent.
///   - **display** — `12 Aug 2026`. Unambiguous in a way `12/08/2026` is not.
///
/// Written by hand rather than with `intl`: this needs two month tables and a
/// weekday name, and the package would add a dependency plus locale
/// initialisation for that. Everything here is English-only, matching the rest
/// of the app; revisit together with the language setting (F40).
abstract final class FormDates {
  const FormDates._();

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static const _weekdays = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', //
    'Friday', 'Saturday', 'Sunday',
  ];

  /// `yyyy-MM-dd`, the form's storage format.
  static String toWireDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  /// `HH:mm`, 24-hour. Police records are read as 24-hour; an am/pm value in
  /// this column would be the odd one out against every FIR already stored.
  static String toWireTime(int hour, int minute) =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  /// Parses a wire date back to a [DateTime], or null if it is empty or
  /// malformed. Used to seed a date picker with what the field already holds.
  static DateTime? parseWireDate(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return null;
    return DateTime.tryParse(v);
  }

  /// Parses `HH:mm` into (hour, minute), or null. Tolerates `H:m`.
  static ({int hour, int minute})? parseWireTime(String? value) {
    final parts = (value ?? '').trim().split(':');
    if (parts.length < 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
    return (hour: hour, minute: minute);
  }

  /// `2026-08-12` → `12 Aug 2026`. Returns the input unchanged when it does not
  /// parse, so a value typed on the website in another format still shows.
  static String displayDate(String? wire) {
    final date = parseWireDate(wire);
    if (date == null) return wire?.trim() ?? '';
    return '${date.day} ${_months[date.month - 1]} ${date.year}';
  }

  /// `14:05` → `14:05 hrs`. The suffix is what makes a bare four digits read as
  /// a time rather than as a case number.
  static String displayTime(String? wire) {
    final time = parseWireTime(wire);
    if (time == null) return wire?.trim() ?? '';
    return '${toWireTime(time.hour, time.minute)} hrs';
  }

  /// The day of the week a wire date falls on, e.g. `Wednesday`. Empty when the
  /// date is missing.
  ///
  /// FORM IF-1 asks for the day of occurrence *and* the date of occurrence as
  /// separate entries. They cannot disagree, so the app derives one from the
  /// other instead of asking twice and trusting the officer to keep them in
  /// step — a mismatch in a filed FIR is the kind of defect that gets raised in
  /// court.
  static String weekdayName(String? wireDate) {
    final date = parseWireDate(wireDate);
    if (date == null) return '';
    return _weekdays[date.weekday - 1];
  }
}
