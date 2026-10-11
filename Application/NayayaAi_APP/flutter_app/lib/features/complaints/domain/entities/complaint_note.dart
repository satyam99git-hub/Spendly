import '../../../../core/utils/server_time.dart';

/// The `officer_notes` column, treated as a log rather than as a text box.
///
/// ---------------------------------------------------------------------------
/// WHY EVERY ENTRY IS APPENDED, STAMPED AND SIGNED
///
/// There is one free-text column and no history table. Every action the desk
/// takes therefore has a choice: overwrite what the last officer wrote, or add
/// to it.
///
/// It adds. This column is the only place the station's reasoning about a
/// complaint survives — "escalated to the SP's office on the 9th because the
/// accused is a serving officer, FIR registered on the 11th" is precisely what
/// somebody reviewing the decision months later is looking for, and precisely
/// what an overwrite would delete as a side effect of doing the right thing.
///
/// Each entry carries the time and a name for the same reason. A trail that
/// cannot say who decided something, or when, is a paragraph rather than a
/// record, and this column is readable by the website's console and quotable in
/// a case diary.
///
/// The cost is that the column grows without bound and nothing prunes it. That
/// is the right trade for a complaint, which has a handful of entries in its
/// life; it would not be for a chat log.
/// ---------------------------------------------------------------------------
abstract final class ComplaintNote {
  const ComplaintNote._();

  /// What is written when the app has no name to sign with.
  ///
  /// Reachable only if the session went away between the screen opening and the
  /// save — the complaints screens are behind the router's police guard. Written
  /// rather than left blank because an unsigned entry in a trail reads as one
  /// somebody removed the name from.
  static const unknownOfficer = 'an officer';

  /// [existing] with a new stamped entry under it.
  ///
  /// Returns [existing] untouched when [body] is blank: a status change with
  /// nothing to say about it is a legitimate action, and stamping an empty line
  /// for it would fill the one column that has to stay readable with noise.
  static String append(
    String existing, {
    required String body,
    required String officer,
    required DateTime at,
  }) {
    final entry = body.trim();
    if (entry.isEmpty) return existing.trim();

    final who = officer.trim().isEmpty ? unknownOfficer : officer.trim();
    final line = '[${stamp(at)} · $who] $entry';

    final before = existing.trim();
    return before.isEmpty ? line : '$before\n$line';
  }

  /// `9 Aug 2026, 02:31 UTC`.
  ///
  /// Deliberately the same wording [ServerTime.display] produces for `created_at`
  /// and `updated_at`, so a note and the timestamps printed beside it read as the
  /// same kind of thing — and UTC for the same reason those are: the server
  /// stores naive UTC and the website's console shows it that way, so a note
  /// stamped in the handset's local time would sit in the same record disagreeing
  /// with everything around it by five and a half hours.
  ///
  /// Built by handing [ServerTime] a string in the shape it already parses,
  /// rather than formatting here, so the two cannot drift apart.
  static String stamp(DateTime at) {
    final utc = at.toUtc();
    String two(int value) => value.toString().padLeft(2, '0');

    return ServerTime.display(
      '${utc.year}-${two(utc.month)}-${two(utc.day)} '
      '${two(utc.hour)}:${two(utc.minute)}:${two(utc.second)}',
    );
  }

  /// The entries as separate lines, newest last, for a screen that renders them.
  ///
  /// Splits on newlines and nothing cleverer. The column is free text that the
  /// website's own console can write into, so a note that was not made by this
  /// app is one paragraph rather than an error.
  static List<String> lines(String notes) => notes
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();
}
