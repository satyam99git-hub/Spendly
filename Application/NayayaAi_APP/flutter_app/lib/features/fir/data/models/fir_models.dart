/// Wire models for `POST /generate_fir`.
///
/// Hand-written for the same reason as the auth models: two shapes, and adding
/// build_runner for them would cost more than it saves.
library;

import '../../domain/entities/fir_draft.dart';
import '../../domain/entities/fir_receipt.dart';
import '../../domain/entities/fir_record.dart';
import '../../domain/entities/section_suggestion.dart';

/// The 27-key request body.
///
/// A wrapper around [FirDraft] rather than a method on it, so the entity owes
/// nothing to the server's column names. Those names are not tidy — `dist`,
/// `ps`, `gdr_entry_no`, `dob` — and they are the *server's* spelling of the
/// form, not the form's.
class FirSubmission {
  const FirSubmission(this.draft);

  final FirDraft draft;

  /// Every key IF-1 has, including the eighteen the short form never asks for.
  ///
  /// **Sending the blanks is deliberate.** The handler builds a fixed-shape
  /// document and reads each key with `data.get(key, "")`, so omitting one would
  /// store the same `""` — but the document it writes is the one the website's
  /// console, the generated PDF and F9's history all read back, and a record
  /// filed from the phone should be indistinguishable in shape from one filed at
  /// the desk. Listing all 27 here is also what makes the contract test
  /// meaningful: a key that silently disappears is a column that silently
  /// empties, and nobody finds out until the record is needed.
  ///
  /// Three keys are composed rather than copied, because the app's form and the
  /// server's columns do not line up one-to-one:
  ///
  /// - `act_sections` joins the picked pairs into the server's single string.
  /// - `year` is derived from the FIR date, not typed.
  /// - `occurrence_day` is derived from the occurrence date. See [FirDraft].
  ///
  /// `act_sections` is never empty, and that is load-bearing: when it is, the
  /// server runs the narrative through `analyze_complaint_for_sections` and
  /// files whatever sections it suggests. Charging decisions are not the app's
  /// to make, and AI is out of scope for this build, so the form requires
  /// sections and that branch is never reached.
  Map<String, dynamic> toJson() => {
        // ---- step 1: registration, entries 1-3 -------------------------------
        'fir_no': draft.firNo.trim(),
        'dist': draft.district.trim(),
        'ps': draft.policeStation.trim(),
        'year': draft.year,
        'fir_date': draft.firDate.trim(),
        'act_sections': draft.actSectionsWire,

        // ---- step 2: occurrence, entries 4-7 ---------------------------------
        'occurrence_day': draft.occurrenceDay,
        'occurrence_date': draft.occurrenceDate.trim(),
        'occurrence_time': draft.occurrenceTime.trim(),
        'info_received_date': draft.infoReceivedDate.trim(),
        'info_received_time': draft.infoReceivedTime.trim(),
        'gdr_entry_no': draft.gdrEntryNo.trim(),
        'type_of_information': draft.typeOfInformation.trim(),
        'place_of_occurrence': draft.placeOfOccurrence.trim(),

        // ---- step 3: the complainant, entry 7 --------------------------------
        'complainant_name': draft.complainantName.trim(),
        'father_husband_name': draft.fatherHusbandName.trim(),
        'dob': draft.dob.trim(),
        'nationality': draft.nationality.trim(),
        'passport_no': draft.passportNo.trim(),
        'date_of_issue': draft.dateOfIssue.trim(),
        'place_of_issue': draft.placeOfIssue.trim(),
        'occupation': draft.occupation.trim(),
        'address': draft.address.trim(),

        // ---- step 4: the complaint, entries 8-12 -----------------------------
        'details_of_accused': draft.detailsOfAccused.trim(),
        'reasons_for_delay': draft.reasonsForDelay.trim(),
        'property_particulars': draft.propertyParticulars.trim(),
        'statement': draft.statement.trim(),
      };
}

/// The 200 response.
///
/// The handler replies with the entire stored document plus `formatted_fir`,
/// `message` and the PDF column. Only the fields the client could not already
/// know are read — see [FirReceipt].
///
/// Both PDF spellings are read. The server writes `pdf_url` (a Supabase object
/// URL) and used to write `pdf_file` (a filename on its own disk); records from
/// before the move are still in the collection, so the reader that ignores
/// either shows half the history with no PDF.
///
/// Defensive about types throughout: `created_at` is a `datetime` stringified
/// by hand in Python, and the FIR number is echoed from the request, so both
/// can arrive as something other than a String without a schema change to warn
/// anyone.
class FirReceiptResponse {
  const FirReceiptResponse._();

  static FirReceipt fromJson(Map<String, dynamic> json) {
    String text(String key) => _text(json, key);

    return FirReceipt(
      firNo: text('fir_no'),
      firId: text('fir_id'),
      actSections: text('act_sections'),
      pdfFile: text('pdf_file'),
      pdfUrl: text('pdf_url'),
      createdAt: text('created_at'),
      status: text('status'),
      message: text('message'),
    );
  }
}

/// One stored FIR, as `GET /api/fir-records` and `GET /api/fir-records/<no>`
/// return it.
///
/// The inverse of [FirSubmission], and it has to stay that way: every key the
/// submission writes is read back here, under the same server spelling. A pair
/// that drifts apart shows up as a viewer with a permanently blank entry, which
/// looks exactly like an FIR that was filed incomplete — the one confusion this
/// screen must never cause. There is a unit test holding the two key sets
/// against each other.
///
/// Three columns exist only on the way back, because only the server can write
/// them: `pdf_url` (with `pdf_file` behind it for records filed before PDF
/// storage moved to Supabase) and `created_at`. `status` is a third — the
/// handler sets it to a constant and nothing has ever changed it.
class FirRecordResponse {
  const FirRecordResponse._();

  static FirRecord fromJson(Map<String, dynamic> json) {
    String text(String key) => _text(json, key);

    return FirRecord(
      firNo: text('fir_no'),
      firId: text('fir_id'),
      district: text('dist'),
      policeStation: text('ps'),
      year: text('year'),
      firDate: text('fir_date'),
      actSections: text('act_sections'),
      occurrenceDay: text('occurrence_day'),
      occurrenceDate: text('occurrence_date'),
      occurrenceTime: text('occurrence_time'),
      infoReceivedDate: text('info_received_date'),
      infoReceivedTime: text('info_received_time'),
      gdrEntryNo: text('gdr_entry_no'),
      typeOfInformation: text('type_of_information'),
      placeOfOccurrence: text('place_of_occurrence'),
      complainantName: text('complainant_name'),
      fatherHusbandName: text('father_husband_name'),
      dob: text('dob'),
      nationality: text('nationality'),
      passportNo: text('passport_no'),
      dateOfIssue: text('date_of_issue'),
      placeOfIssue: text('place_of_issue'),
      occupation: text('occupation'),
      address: text('address'),
      detailsOfAccused: text('details_of_accused'),
      reasonsForDelay: text('reasons_for_delay'),
      propertyParticulars: text('property_particulars'),
      statement: text('statement'),
      pdfFile: text('pdf_file'),
      pdfUrl: text('pdf_url'),
      createdAt: text('created_at'),
      status: text('status'),
    );
  }
}

/// Reads one column as text, whatever it arrives as.
///
/// Nothing here is guaranteed to be a String. `year` is typed into a number box
/// on the website and posts as one, the app derives it and sends a string, and
/// `created_at` is a `datetime` two handlers stringify differently — all into the
/// same schemaless collection. A cast would throw on a record filed by the other
/// client; `toString()` reads it.
String _text(Map<String, dynamic> json, String key) {
  final value = json[key];
  return value == null ? '' : value.toString().trim();
}

/// Reads `POST /api/suggest-sections`.
///
/// Every field is optional on the wire and every one has a floor here. This
/// endpoint answers from a language model, and the one thing that is certain
/// about a model's output is that it will one day be shaped differently from
/// the last time it was looked at. A missing `reason` costs the officer a line
/// of explanation; it must not cost them the suggestion.
extension SectionSuggestionsResponse on SectionSuggestions {
  static SectionSuggestions fromJson(Map<String, dynamic> json) {
    final rows = json['suggestions'];

    return SectionSuggestions(
      suggestions: rows is! List
          ? const []
          : rows
              .whereType<Map>()
              .map(
                (row) => _suggestion(Map<String, dynamic>.from(row)),
              )
              // A row with no act or no section cannot become a chip on an FIR.
              // Dropped rather than shown as a suggestion that does nothing when
              // tapped.
              .where((s) => !s.isEmpty)
              .toList(),
      source: SuggestionSource.fromWire(_text(json, 'source')),
      note: _text(json, 'note'),
      message: _text(json, 'message'),
    );
  }

  static SectionSuggestion _suggestion(Map<String, dynamic> json) =>
      SectionSuggestion(
        // Upper-cased because the act picker's options are, and a chip reading
        // `ipc Section 379` beside one reading `IPC Section 420` is the same
        // inconsistency in the stored column that `ActSection` exists to stop.
        act: _text(json, 'act').toUpperCase(),
        section: _text(json, 'section'),
        title: _text(json, 'title'),
        reason: _text(json, 'reason'),
        confidence: SuggestionConfidence.fromWire(_text(json, 'confidence')),
      );
}
