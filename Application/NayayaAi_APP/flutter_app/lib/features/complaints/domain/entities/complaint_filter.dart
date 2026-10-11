import 'complaint.dart';
import 'complaint_category.dart';
import 'complaint_status.dart';

/// Which complaints the inbox is showing.
///
/// ---------------------------------------------------------------------------
/// WHY THE FILTERING IS ALL CLIENT-SIDE
///
/// `GET /api/complaints/all` takes no query, no page, no status and no date
/// range. It answers with the whole `citizen_complaints` table or with nothing,
/// so there is no version of the inbox that asks the server a narrower question
/// — the choice is only whether the narrowing happens here or not at all.
///
/// The same call FIR history makes, for the same reason, and with the same
/// honest limit: a district with tens of thousands of complaints will feel every
/// open of this screen, and the fix is a filtered endpoint server-side rather
/// than a cleverer client.
/// ---------------------------------------------------------------------------
///
/// Immutable and pure: [apply] is a function of the filter, the list and the
/// clock, which is what lets every rule below be unit-tested without a widget.
class ComplaintFilter {
  const ComplaintFilter({
    this.query = '',
    this.stage = ComplaintStage.all,
    this.category = ComplaintCategoryFilter.all,
    this.datePreset = ComplaintDatePreset.anyTime,
    this.customFrom,
    this.customTo,
  });

  /// Free text, as typed. Trimmed and lowercased inside [apply] rather than by
  /// the caller, so no screen can forget to.
  final String query;

  /// Which part of the workflow. See [ComplaintStage].
  final ComplaintStage stage;

  /// Which kind of offence the server made of the narrative. See
  /// [ComplaintCategoryFilter].
  final ComplaintCategoryFilter category;

  /// Which stretch of time the complaint arrived in. See [ComplaintDatePreset].
  final ComplaintDatePreset datePreset;

  /// The chosen range's ends, used only when [datePreset] is
  /// [ComplaintDatePreset.custom]. Whole days, inclusive of both: picking
  /// 3–5 August means everything filed on the 3rd, 4th or 5th.
  final DateTime? customFrom;
  final DateTime? customTo;

  /// True when the inbox is showing anything other than everything — what the
  /// "Clear" affordance keys off, and what tells the empty state to say "nothing
  /// matches these filters" rather than "no complaints yet".
  bool get isActive =>
      query.trim().isNotEmpty ||
      stage != ComplaintStage.all ||
      category != ComplaintCategoryFilter.all ||
      datePreset != ComplaintDatePreset.anyTime;

  /// How many of the four are narrowing the list. Shown on the filter button so
  /// a filter left on from yesterday is visible without opening anything.
  int get activeCount => [
        query.trim().isNotEmpty,
        stage != ComplaintStage.all,
        category != ComplaintCategoryFilter.all,
        datePreset != ComplaintDatePreset.anyTime,
      ].where((on) => on).length;

  /// What the date filter is doing, short enough for a chip.
  ///
  /// A custom range prints its own dates — `3/8 – 5/8` — rather than the word
  /// "Custom", because a button that says only "Custom range" leaves the officer
  /// unable to tell which range without opening the sheet, which is the state
  /// this label exists to prevent.
  ///
  /// `d/M` rather than a month name: it sits inside a chip beside five others,
  /// and both ends have to fit without pushing the stage chips off the row.
  String get dateLabel {
    if (datePreset != ComplaintDatePreset.custom) return datePreset.label;

    final from = customFrom;
    final to = customTo;
    if (from == null || to == null) return datePreset.label;

    String short(DateTime at) => '${at.day}/${at.month}';
    return _startOfUtcDay(from) == _startOfUtcDay(to)
        ? short(from)
        : '${short(from)} – ${short(to)}';
  }

  // ---- the filter itself ----------------------------------------------------

  /// [all], narrowed. Order is preserved — the repository has already put the
  /// list newest-first and filtering must not disturb that.
  ///
  /// [now] is injected rather than read from the clock so "Today" is testable.
  /// Callers pass `DateTime.now().toUtc()`.
  List<Complaint> apply(List<Complaint> all, {required DateTime now}) {
    final needle = query.trim().toLowerCase();
    final window = _window(now);

    return all
        .where((c) => c.matches(needle))
        .where(stage.accepts)
        .where(category.accepts)
        .where((c) => window == null || window.contains(c.receivedAt))
        .toList();
  }

  /// The instants the date filter admits, or null when it admits everything.
  ///
  /// **Days are UTC days.** Every timestamp this app shows is labelled UTC —
  /// `ServerTime` states the zone rather than converting it, because the server
  /// stores naive UTC and the website's console reads it back the same way. If
  /// the filter used the handset's local midnight instead, a complaint whose row
  /// reads `9 Aug 2026, 19:00 UTC` would appear under "Today" on the 10th in
  /// India, and the officer would be looking at a list that contradicts the dates
  /// printed in it. Consistency with what is on screen wins.
  _DateWindow? _window(DateTime now) {
    final today = _startOfUtcDay(now);
    const day = Duration(days: 1);

    switch (datePreset) {
      case ComplaintDatePreset.anyTime:
        return null;

      case ComplaintDatePreset.today:
        return _DateWindow(today, today.add(day));

      case ComplaintDatePreset.yesterday:
        return _DateWindow(today.subtract(day), today);

      // Inclusive of today, so "last 7 days" is this day and the six before it —
      // seven dates on a calendar, which is what an officer counting back means.
      case ComplaintDatePreset.last7Days:
        return _DateWindow(today.subtract(const Duration(days: 6)), today.add(day));

      case ComplaintDatePreset.last30Days:
        return _DateWindow(
          today.subtract(const Duration(days: 29)),
          today.add(day),
        );

      case ComplaintDatePreset.custom:
        final from = customFrom;
        final to = customTo;
        // A half-set custom range narrows nothing rather than hiding the whole
        // inbox behind a filter the officer has not finished choosing.
        if (from == null || to == null) return null;

        final start = _startOfUtcDay(from);
        final end = _startOfUtcDay(to).add(day);
        // Tolerates the ends arriving the wrong way round, which a picker
        // returning (to, from) or a caller building the filter by hand can do.
        return start.isAfter(end)
            ? _DateWindow(end.subtract(day), start.add(day))
            : _DateWindow(start, end);
    }
  }

  /// Midnight UTC on the day [at] falls in. Rebuilt from the parts rather than
  /// subtracted from, so a local [DateTime] handed in by a date picker is read as
  /// the calendar day the officer tapped rather than shifted by the handset's
  /// offset.
  static DateTime _startOfUtcDay(DateTime at) =>
      DateTime.utc(at.year, at.month, at.day);

  // ---- copy -----------------------------------------------------------------

  /// Null means "leave as it was". [clearCustomRange] exists because clearing the
  /// range cannot be expressed by passing null to [customFrom].
  ComplaintFilter copyWith({
    String? query,
    ComplaintStage? stage,
    ComplaintCategoryFilter? category,
    ComplaintDatePreset? datePreset,
    DateTime? customFrom,
    DateTime? customTo,
    bool clearCustomRange = false,
  }) {
    return ComplaintFilter(
      query: query ?? this.query,
      stage: stage ?? this.stage,
      category: category ?? this.category,
      datePreset: datePreset ?? this.datePreset,
      customFrom: clearCustomRange ? null : (customFrom ?? this.customFrom),
      customTo: clearCustomRange ? null : (customTo ?? this.customTo),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ComplaintFilter &&
          other.query == query &&
          other.stage == stage &&
          other.category == category &&
          other.datePreset == datePreset &&
          other.customFrom == customFrom &&
          other.customTo == customTo;

  @override
  int get hashCode =>
      Object.hash(query, stage, category, datePreset, customFrom, customTo);

  @override
  String toString() => 'ComplaintFilter(${stage.name}, ${category.name}, '
      '${datePreset.name}, "$query")';
}

/// Half-open on purpose: `[start, end)`. A complaint filed at exactly midnight
/// belongs to the day starting then, and to only one day.
class _DateWindow {
  const _DateWindow(this.start, this.end);

  final DateTime start;
  final DateTime end;

  /// A complaint whose timestamp is missing or unreadable is **excluded** while
  /// any date filter is on.
  ///
  /// The alternative — showing it under every range — would put the same rows in
  /// "Today" and in "Yesterday" and make the counts lie. Under "Any time" the
  /// window is null and no such row is ever hidden, so nothing becomes
  /// unreachable; it just does not claim a date it does not have.
  bool contains(DateTime? at) {
    if (at == null) return false;
    final utc = at.toUtc();
    return !utc.isBefore(start) && utc.isBefore(end);
  }
}

/// The status filter, in the words an officer uses for it.
///
/// [open] and [all] are the two that are not statuses. They exist because the
/// question an officer actually asks the inbox is "what still needs me?", and
/// answering that with two chips they have to remember to tap together is
/// answering it badly.
enum ComplaintStage {
  all('All'),

  /// Everything still waiting on this desk: [ComplaintStatus.pending],
  /// [ComplaintStatus.underReview], and any row whose status the app does not
  /// recognise. The last of those is deliberate — an unclassifiable complaint is
  /// one nobody can prove has been dealt with, and it belongs in front of an
  /// officer rather than filed away by a client that could not read it.
  open('Active'),

  pending('Pending'),

  /// The server's "Under Review" — the state a complaint is *in process* in.
  underReview('Under review'),

  firFiled('FIR filed'),

  closed('Closed');

  const ComplaintStage(this.label);

  /// On the chip.
  final String label;

  /// Whether [complaint] belongs in this stage.
  bool accepts(Complaint complaint) {
    switch (this) {
      case ComplaintStage.all:
        return true;
      case ComplaintStage.open:
        return complaint.isOpen;
      case ComplaintStage.pending:
        return complaint.status == ComplaintStatus.pending;
      case ComplaintStage.underReview:
        return complaint.status == ComplaintStatus.underReview;
      case ComplaintStage.firFiled:
        return complaint.status == ComplaintStatus.firFiled;
      case ComplaintStage.closed:
        return complaint.status == ComplaintStatus.closed;
    }
  }
}

/// Which day, or stretch of days, a complaint arrived in.
///
/// Filtered on `created_at` — when the complaint reached the station — and not
/// on `incident_date`. Two reasons, and the second is the decisive one: triage
/// is a question about the inbox ("what came in today"), and `incident_date` is
/// free text a citizen typed, so half the table cannot be filtered on it at all.
/// The incident date is still shown on every row and searched as text.
enum ComplaintDatePreset {
  anyTime('Any time'),
  today('Today'),
  yesterday('Yesterday'),
  last7Days('Last 7 days'),
  last30Days('Last 30 days'),

  /// Two dates the officer picked. The ends live on [ComplaintFilter] rather
  /// than here, because an enum cannot carry them.
  custom('Custom range');

  const ComplaintDatePreset(this.label);

  final String label;
}

/// Which kind of offence the inbox is showing.
///
/// ---------------------------------------------------------------------------
/// WHY THIS IS NOT ONE ENTRY PER CATEGORY
///
/// The website's board has a column for each of the seven cognizable categories
/// and one for everything else, which is the right shape for a desktop board
/// that shows all eight at once. A filter is not a board: an officer picks one
/// value from it, and a ten-item list to pick from on a phone is a list that
/// gets scrolled past rather than used.
///
/// So the seven that matter individually are here, the three "we could not tell"
/// buckets collapse into [other] exactly as the website's board collapses them,
/// and [cognizable] is added at the top because it is the question an officer
/// actually asks the inbox — *which of these can I register an FIR on?* — and
/// answering it otherwise means tapping seven filters one after another.
/// ---------------------------------------------------------------------------
enum ComplaintCategoryFilter {
  all('Any kind'),

  /// Every complaint the server flagged as cognizable, whatever the category.
  ///
  /// Reads [Complaint.isCognizable], which prefers the row's own column over
  /// the category's default — so a row the categoriser marked cognizable under
  /// a category this app has never heard of is still caught here.
  cognizable('FIR possible'),

  murder('Murder / homicide', ComplaintCategory.murder),
  sexualOffence('Sexual offence', ComplaintCategory.sexualOffence),
  kidnapping('Kidnapping / missing', ComplaintCategory.kidnapping),
  assault('Assault / violence', ComplaintCategory.assault),
  theft('Theft / robbery', ComplaintCategory.theft),
  cybercrime('Cybercrime / fraud', ComplaintCategory.cybercrime),
  financialFraud('Financial fraud', ComplaintCategory.financialFraud),

  /// The three buckets that mean "the categoriser could not tell", plus every
  /// row filed before it existed and every row whose category this app does not
  /// recognise.
  ///
  /// Those last two are the reason this is not simply the three enum values: a
  /// complaint nobody has classified is exactly the one that needs reading, and
  /// leaving it out of the only filter that would surface it would bury it.
  other('Needs a read');

  const ComplaintCategoryFilter(this.label, [this.exact]);

  /// On the chip.
  final String label;

  /// The single category this filter selects, when it selects one. Null for
  /// [all], [cognizable] and [other], each of which spans several.
  final ComplaintCategory? exact;

  /// Whether [complaint] belongs in this filter.
  bool accepts(Complaint complaint) {
    switch (this) {
      case ComplaintCategoryFilter.all:
        return true;
      case ComplaintCategoryFilter.cognizable:
        return complaint.isCognizable;
      case ComplaintCategoryFilter.other:
        final known = complaint.category;
        return known == null || known.isUnclassified;
      default:
        return complaint.category == exact;
    }
  }
}
