/// `GET /api/case/<fir_no>/client-status` 200 body (app.py:2526-2532).
///
/// The only case information the website gives a citizen: what the assigned
/// lawyer switched on with "share with client". There is no route that tells a
/// citizen anything more about an FIR, so there is nothing more here.
class CaseClientStatus {
  const CaseClientStatus({
    required this.firNo,
    this.status = '',
    this.nextHearingDate = '',
    this.clientNote = '',
    this.clientNoteUpdatedAt = '',
  });

  final String firNo;

  /// One of the lawyer's statuses — `Investigation`, `Court Proceedings`,
  /// `Trial`, `Closed` (app.py:2428) — or empty.
  final String status;
  final String nextHearingDate;
  final String clientNote;

  /// ISO 8601 with offset, as Supabase stores it.
  final String clientNoteUpdatedAt;

  /// What the pill says: the status, or "Active" when there is none
  /// (`data.status || 'Active'`, citizen_dashboard.html:1093).
  String get statusLabel => status.isEmpty ? 'Active' : status;

  /// `data.next_hearing_date || 'Not scheduled'`.
  String get hearingLabel =>
      nextHearingDate.isEmpty ? 'Not scheduled' : nextHearingDate;

  bool get hasNote => clientNote.isNotEmpty;

  factory CaseClientStatus.fromJson(Map<String, dynamic> json) {
    String text(String key) => json[key]?.toString().trim() ?? '';
    return CaseClientStatus(
      firNo: text('fir_no'),
      status: text('status'),
      nextHearingDate: text('next_hearing_date'),
      clientNote: text('client_note'),
      clientNoteUpdatedAt: text('client_note_updated_at'),
    );
  }
}

/// A port of the website's `formatRelativeTime` (citizen_dashboard.html:
/// 1054-1071), used for "Note from your lawyer".
///
/// Same thresholds, same words. The one difference is the month name in the
/// last case: the browser asks `toLocaleDateString('en-IN', {month: 'short'})`,
/// whose exact spelling depends on the browser's ICU data; this uses the plain
/// three-letter English abbreviations.
String formatRelativeTime(String isoString, {DateTime? now}) {
  if (isoString.isEmpty) return '';
  final then = DateTime.tryParse(isoString);
  if (then == null) return '';

  final at = (now ?? DateTime.now()).toUtc();
  final diff = at.difference(then.toUtc());
  final mins = diff.inMinutes;
  final hours = diff.inHours;
  final days = diff.inDays;

  if (mins < 1) return 'just now';
  if (mins < 60) return 'Updated $mins min ago';
  if (hours < 24) return 'Updated $hours hr${hours > 1 ? 's' : ''} ago';
  if (days < 7) return 'Updated $days day${days > 1 ? 's' : ''} ago';

  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final local = then.toLocal();
  return 'Updated on ${local.day} ${months[local.month - 1]} ${local.year}';
}
