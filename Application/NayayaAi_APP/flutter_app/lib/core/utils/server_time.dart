/// Reading the timestamps the NyayaAI server writes.
///
/// Separate from [FormDates] on purpose. That file is about the *form's* two
/// representations — `yyyy-MM-dd` on the wire, `12 Aug 2026` on screen — which
/// the app controls end to end because the server stores those columns as opaque
/// strings and never parses them.
///
/// This one is about a value the app does not control at all: `created_at` is a
/// real `datetime` in Mongo, and it reaches the client in **two different
/// spellings** depending on which handler answered.
///
///   - `GET /api/fir-records` → `Sat, 09 Aug 2026 02:31:00 GMT`
///     Flask's `jsonify` serialises a `datetime` as an RFC 1123 HTTP date.
///   - `POST /generate_fir` → `2026-08-09 02:31:00.345678`
///     That handler stringifies it by hand with `str(...)` before replying.
///
/// A viewer that understood only one would show a filing date on some screens
/// and a raw string on others, for the same record. Both are UTC — Mongo stores
/// naive UTC and the server never applies a zone — so both parse to a UTC
/// [DateTime] here, and anything displayed says so rather than implying a local
/// time the server never sent.
abstract final class ServerTime {
  const ServerTime._();

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  /// The timestamp as a UTC [DateTime], or null when it is empty or in neither
  /// shape.
  ///
  /// Null is a normal answer, not an error: records seeded straight into Mongo
  /// by the website's own scripts have turned up with an empty `created_at`, and
  /// a history list must still be able to show them.
  static DateTime? parse(String? raw) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty) return null;

    return _parseHttpDate(value) ?? _parsePythonStr(value);
  }

  /// `Sat, 09 Aug 2026 02:31:00 GMT`.
  ///
  /// The weekday is thrown away rather than checked. It is derived from the same
  /// instant as the rest of the string, so it cannot carry information the date
  /// does not — and rejecting a timestamp because a server computed its weekday
  /// wrongly would lose the whole record over a decoration.
  static DateTime? _parseHttpDate(String value) {
    final comma = value.indexOf(',');
    if (comma == -1) return null;

    final parts = value
        .substring(comma + 1)
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.length < 4) return null;

    final day = int.tryParse(parts[0]);
    final month = _months.indexWhere(
          (m) => m.toLowerCase() == parts[1].toLowerCase(),
        ) +
        1;
    final year = int.tryParse(parts[2]);
    if (day == null || month == 0 || year == null) return null;

    final clock = parts[3].split(':');
    if (clock.length < 3) return null;
    final hour = int.tryParse(clock[0]);
    final minute = int.tryParse(clock[1]);
    final second = int.tryParse(clock[2]);
    if (hour == null || minute == null || second == null) return null;

    return DateTime.utc(year, month, day, hour, minute, second);
  }

  /// `2026-08-09 02:31:00.345678`, which is what `str(datetime)` produces.
  ///
  /// [DateTime.tryParse] accepts it but reads it as *local* time, because the
  /// string carries no zone. The instant is UTC, so it is rebuilt as UTC rather
  /// than trusted — otherwise every timestamp shifts by the handset's offset,
  /// which in India is five and a half hours and reads as a filing that has not
  /// happened yet.
  static DateTime? _parsePythonStr(String value) {
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return null;
    if (parsed.isUtc) return parsed;

    return DateTime.utc(
      parsed.year,
      parsed.month,
      parsed.day,
      parsed.hour,
      parsed.minute,
      parsed.second,
      parsed.millisecond,
      parsed.microsecond,
    );
  }

  /// `9 Aug 2026, 02:31 UTC`, or the input unchanged when it does not parse.
  ///
  /// Returning the raw string rather than an empty one is the same call
  /// [FormDates.displayDate] makes: a value the app cannot read is still a value
  /// the officer might recognise, and blanking it says "never recorded", which
  /// is a different and false claim.
  ///
  /// **UTC is stated, not converted.** Every FIR in the database is timestamped
  /// in UTC and the website's own console shows it that way; quietly rendering
  /// the handset's local time would make the app disagree with the desk about
  /// when a statutory record was created.
  static String display(String? raw) {
    final at = parse(raw);
    if (at == null) return raw?.trim() ?? '';

    final hour = at.hour.toString().padLeft(2, '0');
    final minute = at.minute.toString().padLeft(2, '0');
    return '${at.day} ${_months[at.month - 1]} ${at.year}, $hour:$minute UTC';
  }

  /// Just the date part — `9 Aug 2026`. For list rows, where the clock time is
  /// noise next to the FIR number it sits beside.
  static String displayDay(String? raw) {
    final at = parse(raw);
    if (at == null) return raw?.trim() ?? '';
    return '${at.day} ${_months[at.month - 1]} ${at.year}';
  }
}
