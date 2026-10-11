import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/complaint.dart';
import '../../domain/entities/complaint_filter.dart';
import 'complaint_providers.dart';

/// What the inbox is currently filtered to.
///
/// **Not `autoDispose`, and that is the point.** An officer who has narrowed the
/// inbox to "Active, last 7 days" opens a complaint, deals with it, and comes
/// back — to the list they were working, not to an unfiltered one they have to
/// narrow again. The filter is the officer's place in the inbox, and losing it
/// on every navigation is how a triage session turns into re-filtering.
///
/// It does reset on sign-out, along with everything else the provider container
/// holds for a session.
final complaintFilterProvider =
    NotifierProvider<ComplaintFilterController, ComplaintFilter>(
  ComplaintFilterController.new,
);

class ComplaintFilterController extends Notifier<ComplaintFilter> {
  @override
  ComplaintFilter build() => const ComplaintFilter();

  /// The search box. Every keystroke, undebounced — the list is already in
  /// memory and a `contains` over it is cheaper than the frame that renders the
  /// result, so a debounce would only add lag. Same call FIR history makes.
  void setQuery(String value) {
    if (value == state.query) return;
    state = state.copyWith(query: value);
  }

  void setStage(ComplaintStage stage) {
    if (stage == state.stage) return;
    state = state.copyWith(stage: stage);
  }

  void setCategory(ComplaintCategoryFilter category) {
    if (category == state.category) return;
    state = state.copyWith(category: category);
  }

  /// Switches the date preset.
  ///
  /// Moving *away* from [ComplaintDatePreset.custom] clears the two ends rather
  /// than keeping them, so a later return to "Custom range" opens empty instead
  /// of silently re-applying a range chosen an hour ago.
  void setDatePreset(ComplaintDatePreset preset) {
    if (preset == state.datePreset) return;
    state = state.copyWith(
      datePreset: preset,
      clearCustomRange: preset != ComplaintDatePreset.custom,
    );
  }

  /// Sets both ends of the custom range and selects it.
  ///
  /// Takes the pair together because a range with one end set filters nothing
  /// (see `ComplaintFilter._window`), so there is no useful intermediate state
  /// to hold — the picker returns both or the officer cancelled.
  void setCustomRange(DateTime from, DateTime to) {
    state = state.copyWith(
      datePreset: ComplaintDatePreset.custom,
      customFrom: from,
      customTo: to,
    );
  }

  /// Back to the whole inbox, search box included.
  ///
  /// Unlike the filter sheet's own "Clear", this one takes the query too: it is
  /// offered from the empty state ("nothing matches these filters"), where the
  /// query is as likely to be the cause as anything else, and leaving it on
  /// would show the officer another empty list.
  void clear() {
    if (state == const ComplaintFilter()) return;
    state = const ComplaintFilter();
  }
}

/// Now, in UTC, as a function rather than a value.
///
/// A function so it is read at the moment of filtering rather than at the moment
/// the provider was first built — otherwise "Today" would mean the day the app
/// was launched, which for a handset left on a charge-point overnight is
/// yesterday.
///
/// A provider so a test can pin the clock and prove that "Last 7 days" means what
/// it should. Every date filter in the inbox goes through this and nothing else
/// calls `DateTime.now()`.
final complaintClockProvider = Provider<DateTime Function()>(
  (ref) => () => DateTime.now().toUtc(),
);

/// The inbox, narrowed by [complaintFilterProvider].
///
/// A provider rather than a line in the screen's `build`, for two reasons: the
/// count printed above the list and the list itself cannot then disagree, and
/// the filtering is exercised by tests that never build a widget.
///
/// Keeps the [AsyncValue] rather than unwrapping it — loading and error are
/// states the inbox has to draw, and flattening them here would mean the screen
/// watching two providers and reassembling what this one took apart.
final filteredComplaintsProvider =
    Provider.autoDispose<AsyncValue<List<Complaint>>>((ref) {
  final filter = ref.watch(complaintFilterProvider);
  final now = ref.watch(complaintClockProvider);

  return ref
      .watch(complaintsProvider)
      .whenData((all) => filter.apply(all, now: now()));
});

/// Whether the inbox is a flat list or grouped by the kind of offence.
///
/// ---------------------------------------------------------------------------
/// THE WEBSITE'S BOARD, IN A SHAPE A PHONE CAN READ
///
/// The console has a board view: eight columns, one per category, complaints as
/// cards inside them. It is the right shape for a desktop, where all eight are
/// visible at once and the comparison between columns *is* the information.
///
/// Eight columns on a 390-point screen are not eight columns; they are one
/// column and a horizontal scrollbar, and a board nobody can see across is a
/// board with none of the advantage a board has. So the same grouping is drawn
/// vertically: every category that has complaints, in the website's own order,
/// each with a heading and a count. An officer scrolls one axis and sees the
/// same division.
///
/// Newest-first ordering survives inside each group, because the server's order
/// is the only ordering the list has.
/// ---------------------------------------------------------------------------
enum ComplaintView {
  /// Newest first, ungrouped. What triage actually is most of the time.
  list,

  /// Divided by [ComplaintCategory], the way the website's board divides it.
  grouped;

  bool get isGrouped => this == ComplaintView.grouped;
}

/// Which of the two the inbox is showing. Not persisted: it is a way of looking
/// at the list right now, not a setting.
final complaintViewProvider =
    NotifierProvider.autoDispose<ComplaintViewController, ComplaintView>(
  ComplaintViewController.new,
);

class ComplaintViewController extends AutoDisposeNotifier<ComplaintView> {
  @override
  ComplaintView build() => ComplaintView.list;

  void toggle() => state =
      state.isGrouped ? ComplaintView.list : ComplaintView.grouped;
}
