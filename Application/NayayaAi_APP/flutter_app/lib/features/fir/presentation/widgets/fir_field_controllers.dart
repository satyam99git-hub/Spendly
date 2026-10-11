import 'package:flutter/widgets.dart';

import '../../domain/entities/fir_draft.dart';

/// Every typed entry's [TextEditingController], in one object owned by the form
/// screen.
///
/// The draft, not this bag, is the source of truth: every field reports its
/// keystrokes into `FirFormController.edit` on the same frame. These exist
/// because a text box needs a controller, not because the form needs a second
/// copy of its own contents — which is why they are seeded once, from a draft
/// that has finished restoring, and never written to again.
///
/// Owned by the wizard shell rather than by the four step widgets, and that is
/// load-bearing: a step is unmounted the moment the officer taps Next, so a
/// controller created inside one would be disposed with it and the text would be
/// rebuilt from the draft on every visit — losing the cursor position, and
/// losing an in-flight IME composition outright.
///
/// The date and time entries have no controller. They are pickers that render
/// straight from the draft, so there is nothing to hold.
class FirFieldControllers {
  FirFieldControllers(FirDraft draft)
      : firNo = TextEditingController(text: draft.firNo),
        gdrEntryNo = TextEditingController(text: draft.gdrEntryNo),
        typeOfInformation =
            TextEditingController(text: draft.typeOfInformation),
        placeOfOccurrence =
            TextEditingController(text: draft.placeOfOccurrence),
        complainantName = TextEditingController(text: draft.complainantName),
        fatherHusbandName =
            TextEditingController(text: draft.fatherHusbandName),
        nationality = TextEditingController(text: draft.nationality),
        passportNo = TextEditingController(text: draft.passportNo),
        placeOfIssue = TextEditingController(text: draft.placeOfIssue),
        occupation = TextEditingController(text: draft.occupation),
        address = TextEditingController(text: draft.address),
        detailsOfAccused = TextEditingController(text: draft.detailsOfAccused),
        reasonsForDelay = TextEditingController(text: draft.reasonsForDelay),
        propertyParticulars =
            TextEditingController(text: draft.propertyParticulars),
        statement = TextEditingController(text: draft.statement);

  // ---- step 1 ---------------------------------------------------------------
  final TextEditingController firNo;

  // ---- step 2 ---------------------------------------------------------------
  final TextEditingController gdrEntryNo;
  final TextEditingController typeOfInformation;
  final TextEditingController placeOfOccurrence;

  // ---- step 3 ---------------------------------------------------------------
  final TextEditingController complainantName;
  final TextEditingController fatherHusbandName;
  final TextEditingController nationality;
  final TextEditingController passportNo;
  final TextEditingController placeOfIssue;
  final TextEditingController occupation;
  final TextEditingController address;

  // ---- step 4 ---------------------------------------------------------------
  final TextEditingController detailsOfAccused;
  final TextEditingController reasonsForDelay;
  final TextEditingController propertyParticulars;
  final TextEditingController statement;

  List<TextEditingController> get _all => [
        firNo,
        gdrEntryNo,
        typeOfInformation,
        placeOfOccurrence,
        complainantName,
        fatherHusbandName,
        nationality,
        passportNo,
        placeOfIssue,
        occupation,
        address,
        detailsOfAccused,
        reasonsForDelay,
        propertyParticulars,
        statement,
      ];

  void dispose() {
    for (final controller in _all) {
      controller.dispose();
    }
  }
}
