import 'package:flutter/widgets.dart';

import '../../domain/entities/fir_draft.dart';

/// A [Key] for every control on the FIR form.
///
/// Not decoration and not a Flutter requirement — these exist so tests can name
/// an entry the way the form does. Without them a test reaches its target by
/// position ("the fourth TextField") or by hint text, and both break the moment
/// a field is reordered or its wording is improved, which turns every copy edit
/// into a test failure that says nothing about what actually broke.
///
/// The names mirror [FirDraft]'s fields exactly. When one gets renamed, the
/// other should too.
abstract final class FirFieldKeys {
  const FirFieldKeys._();

  // ---- step 1: registration -------------------------------------------------

  static const firNo = Key('fir.firNo');
  static const district = Key('fir.district');
  static const policeStation = Key('fir.policeStation');
  static const firDate = Key('fir.firDate');
  static const sections = Key('fir.sections');

  // ---- step 2: occurrence ---------------------------------------------------

  static const occurrenceDate = Key('fir.occurrenceDate');
  static const occurrenceTime = Key('fir.occurrenceTime');
  static const infoReceivedDate = Key('fir.infoReceivedDate');
  static const infoReceivedTime = Key('fir.infoReceivedTime');
  static const gdrEntryNo = Key('fir.gdrEntryNo');
  static const typeOfInformation = Key('fir.typeOfInformation');
  static const placeOfOccurrence = Key('fir.placeOfOccurrence');

  // ---- step 3: the complainant ----------------------------------------------

  static const complainantName = Key('fir.complainantName');
  static const fatherHusbandName = Key('fir.fatherHusbandName');
  static const dob = Key('fir.dob');
  static const nationality = Key('fir.nationality');
  static const passportNo = Key('fir.passportNo');
  static const dateOfIssue = Key('fir.dateOfIssue');
  static const placeOfIssue = Key('fir.placeOfIssue');
  static const occupation = Key('fir.occupation');
  static const address = Key('fir.address');

  // ---- step 4: the complaint ------------------------------------------------

  static const detailsOfAccused = Key('fir.detailsOfAccused');
  static const reasonsForDelay = Key('fir.reasonsForDelay');
  static const propertyParticulars = Key('fir.propertyParticulars');
  static const statement = Key('fir.statement');

  // ---- the wizard itself ----------------------------------------------------

  /// The scrolling body of whichever step is on screen. Keyed by the step, so a
  /// test asserting "we are on step 3" names the step rather than counting
  /// widgets — and so the [ListView] is rebuilt from scratch on a step change
  /// instead of keeping the previous page's scroll offset.
  static Key step(FirFormStep step) => Key('fir.step.${step.name}');

  // ---- the section suggestion sheet -----------------------------------------

  /// The button under the narrative that opens the sheet.
  static const suggestOpen = Key('fir.suggest.open');

  /// The sheet's scrolling body.
  static const suggestSheet = Key('fir.suggest.sheet');

  /// One suggested section, keyed by the pair so a test can name the section it
  /// expects rather than indexing into a list whose order the server decides.
  static Key suggestion(String act, String section) =>
      Key('fir.suggest.$act.$section');

  /// Commits the selected suggestions to the draft.
  static const suggestAdd = Key('fir.suggest.add');

  static const back = Key('fir.back');
  static const next = Key('fir.next');
  static const submit = Key('fir.submit');

  /// The review's "Edit" link into one step.
  static Key reviewEdit(FirFormStep step) =>
      Key('fir.review.edit.${step.name}');
}
