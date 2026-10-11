/// Where a citizen's complaint has got to.
///
/// ---------------------------------------------------------------------------
/// WHY THESE FOUR AND NOT THE ONES YOU MIGHT EXPECT
///
/// This list is not a design choice. `PATCH /api/complaints/<tracking_id>`
/// validates the incoming status against exactly
/// `['Pending', 'Under Review', 'FIR Filed', 'Closed']` and answers HTTP 400
/// for anything else, so a fifth value — "Assigned", "Rejected", "Escalated" —
/// is not a status the app can store, however much it might want one.
///
/// Escalation in particular has no column of its own. It is recorded as a
/// stamped line in `officer_notes` and a move to [underReview]; see
/// `ComplaintAction.escalate`.
/// ---------------------------------------------------------------------------
///
/// The wire values are the exact strings the column holds, spaces and capitals
/// included. Do not "tidy" them: the server compares them literally.
enum ComplaintStatus {
  /// The server's default for a freshly filed complaint. Nobody has looked at
  /// it yet — this is the inbox.
  pending(
    'Pending',
    'Pending',
    'Filed by a citizen, not yet triaged',
  ),

  /// An officer has picked it up. Also where an escalated complaint sits, for
  /// want of a status of its own.
  underReview(
    'Under Review',
    'Under review',
    'An officer is working on it',
  ),

  /// It became an FIR. The number is in `fir_no`, and the case now lives in
  /// police records rather than in this inbox.
  firFiled(
    'FIR Filed',
    'FIR filed',
    'Registered as an FIR',
  ),

  /// Dealt with, or found to need no action. Not deletion — the row stays and
  /// can be moved back to [underReview].
  closed(
    'Closed',
    'Closed',
    'No further action from this desk',
  );

  const ComplaintStatus(this.wireValue, this.label, this.description);

  /// What the `status` column holds and what the PATCH body must carry.
  final String wireValue;

  /// On screen. Sentence case, unlike the wire value, because it appears inside
  /// running text as often as it does on a chip.
  final String label;

  /// One line explaining what the status means, for the filter sheet — an
  /// inbox whose four states are guessed at is an inbox that gets triaged
  /// wrongly.
  final String description;

  /// True when the complaint is still this desk's to act on. What the filter
  /// bar's "Open" shortcut selects, and the closest thing the server's
  /// vocabulary has to the "active" an officer means when they ask for it.
  bool get isOpen => this == pending || this == underReview;

  /// Reads the column.
  ///
  /// Returns null rather than falling back to [pending] for a value the app
  /// does not know. Nothing but this PATCH is supposed to write the column, and
  /// it validates — so an unrecognised value means the row was edited outside
  /// the application, and reporting it as "Pending" would put a complaint
  /// somebody has already dealt with back at the top of the inbox. The entity
  /// keeps the raw text and shows that instead; see `Complaint.statusLabel`.
  static ComplaintStatus? fromWire(String? value) {
    final v = value?.trim().toLowerCase();
    if (v == null || v.isEmpty) return null;

    for (final status in ComplaintStatus.values) {
      if (status.wireValue.toLowerCase() == v) return status;
    }
    return null;
  }
}
