import 'package:flutter/widgets.dart';

/// Widget keys the complaints tests drive the screens by.
///
/// Named rather than found by text, for the same reason the FIR and evidence
/// suites have their own: a test that taps `find.text('Escalate')` breaks when
/// the copy is improved, which trains people to change tests to match whatever
/// the code now does. These are a contract; the words on screen are not.
abstract final class ComplaintKeys {
  const ComplaintKeys._();

  // ---- the inbox ------------------------------------------------------------

  static const search = Key('complaints-search');
  static const list = Key('complaints-list');
  static const filterButton = Key('complaints-filter-button');
  static const clearFilters = Key('complaints-clear-filters');

  /// The row of stage chips. Each chip is [stageChip].
  static const stageChips = Key('complaints-stage-chips');

  static const stats = Key('complaints-stats');

  static Key stat(String stageName) => Key('complaints-stat-$stageName');

  static const viewToggle = Key('complaints-view-toggle');

  static Key stageChip(String stageName) => Key('complaints-stage-$stageName');

  /// One row, keyed by tracking ID so a test can tap a specific complaint
  /// rather than "the third one", which changes whenever a fixture does.
  static Key tile(String trackingId) => Key('complaint-tile-$trackingId');

  // ---- the filter sheet -----------------------------------------------------

  static const filterSheet = Key('complaints-filter-sheet');
  static const filterApply = Key('complaints-filter-apply');

  static Key datePreset(String presetName) =>
      Key('complaints-date-$presetName');

  static Key categoryChoice(String filterName) =>
      Key('complaints-category-$filterName');

  // ---- the detail screen ----------------------------------------------------

  static const detail = Key('complaint-detail');
  static const respondAction = Key('complaint-respond');
  static const escalateAction = Key('complaint-escalate');
  static const convertAction = Key('complaint-convert');
  static const openFirAction = Key('complaint-open-fir');
  static const notes = Key('complaint-notes');

  // ---- the respond sheet ----------------------------------------------------

  static const respondSheet = Key('complaint-respond-sheet');
  static const respondNote = Key('complaint-respond-note');
  static const respondFirNo = Key('complaint-respond-fir-no');
  static const respondSubmit = Key('complaint-respond-submit');

  static Key respondStatus(String statusName) =>
      Key('complaint-respond-status-$statusName');

  // ---- the escalate sheet ---------------------------------------------------

  static const escalateSheet = Key('complaint-escalate-sheet');
  static const escalateReason = Key('complaint-escalate-reason');
  static const escalateSubmit = Key('complaint-escalate-submit');

  static Key escalateDesk(String deskName) =>
      Key('complaint-escalate-desk-$deskName');
}
