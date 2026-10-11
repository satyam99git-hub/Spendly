import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nayaya_app/core/constants/storage_keys.dart';
import 'package:nayaya_app/core/error/failure.dart';
import 'package:nayaya_app/core/utils/form_dates.dart';
import 'package:nayaya_app/features/evidence/data/datasources/evidence_file_picker.dart';
import 'package:nayaya_app/features/evidence/domain/entities/evidence_file.dart';
import 'package:nayaya_app/features/fir/domain/entities/act_section.dart';
import 'package:nayaya_app/features/fir/domain/entities/fir_draft.dart';
import 'package:nayaya_app/features/fir/presentation/widgets/fir_field_keys.dart';
import 'package:nayaya_app/features/fir/presentation/widgets/fir_proofs_field.dart';

import '../../helpers/fake_evidence_repository.dart';
import '../../helpers/fake_fir_repository.dart';
import '../../helpers/in_memory_secure_storage.dart';
import '../../helpers/pump_fir_app.dart';

/// Behavioural coverage for the FIR wizard: what it lets through, what it
/// refuses, what it sends, and what it does with the answer.
///
/// Nothing here asserts layout — that is the goldens' job. What is asserted are
/// the promises the four-step format makes: that a blank is raised on the page
/// that can fix it, that the review shows what is about to be filed, that all
/// twenty-seven entries reach the server, and that one press of File means one
/// FIR.
void main() {
  group('the wizard', () {
    testWidgets('opens on step 1, with the registration entries', (
      tester,
    ) async {
      await pumpFirForm(tester, repository: FakeFirRepository());

      expect(firStep(FirFormStep.registration), findsOneWidget);
      for (final key in const [
        FirFieldKeys.firNo,
        FirFieldKeys.district,
        FirFieldKeys.policeStation,
        FirFieldKeys.firDate,
        FirFieldKeys.sections,
      ]) {
        expect(find.byKey(key), findsOneWidget, reason: '$key');
      }
      // Step 1 has nothing behind it, so there is no Back in the footer.
      expect(find.byKey(FirFieldKeys.back), findsNothing);
    });

    testWidgets('walks all four steps and ends on the review', (tester) async {
      await pumpFirForm(tester, repository: FakeFirRepository());
      await fillMinimalFir(tester);

      expect(firStep(FirFormStep.review), findsOneWidget);
      expect(find.byKey(FirFieldKeys.submit), findsOneWidget);
      // File appears only here; the four entry steps offer Next.
      expect(find.byKey(FirFieldKeys.next), findsNothing);
    });

    testWidgets('each step carries the IF-1 entries it is named for', (
      tester,
    ) async {
      await pumpFirForm(tester, repository: FakeFirRepository());

      await enterFir(tester, FirFieldKeys.firNo, 'FIR001');
      await chooseOption(tester, FirFieldKeys.district, 'Delhi');
      await chooseOption(tester, FirFieldKeys.policeStation, 'North Delhi PS');
      await addSection(tester, act: 'IPC', section: '379');
      await firNext(tester);

      expect(firStep(FirFormStep.occurrence), findsOneWidget);
      for (final key in const [
        FirFieldKeys.occurrenceDate,
        FirFieldKeys.occurrenceTime,
        FirFieldKeys.infoReceivedDate,
        FirFieldKeys.infoReceivedTime,
        FirFieldKeys.gdrEntryNo,
        FirFieldKeys.typeOfInformation,
        FirFieldKeys.placeOfOccurrence,
      ]) {
        expect(find.byKey(key), findsOneWidget, reason: '$key');
      }

      await firNext(tester);
      expect(firStep(FirFormStep.complainant), findsOneWidget);
      for (final key in const [
        FirFieldKeys.complainantName,
        FirFieldKeys.fatherHusbandName,
        FirFieldKeys.dob,
        FirFieldKeys.nationality,
        FirFieldKeys.occupation,
        FirFieldKeys.address,
        FirFieldKeys.passportNo,
        FirFieldKeys.dateOfIssue,
        FirFieldKeys.placeOfIssue,
      ]) {
        expect(find.byKey(key), findsOneWidget, reason: '$key');
      }

      await enterFir(tester, FirFieldKeys.complainantName, 'A. Sharma');
      await firNext(tester);
      expect(firStep(FirFormStep.complaint), findsOneWidget);
      for (final key in const [
        FirFieldKeys.detailsOfAccused,
        FirFieldKeys.propertyParticulars,
        FirFieldKeys.reasonsForDelay,
        FirFieldKeys.statement,
      ]) {
        expect(find.byKey(key), findsOneWidget, reason: '$key');
      }
    });

    testWidgets('Back returns to the step before, keeping what was typed', (
      tester,
    ) async {
      await pumpFirForm(tester, repository: FakeFirRepository());

      await enterFir(tester, FirFieldKeys.firNo, 'FIR001');
      await chooseOption(tester, FirFieldKeys.district, 'Delhi');
      await chooseOption(tester, FirFieldKeys.policeStation, 'North Delhi PS');
      await addSection(tester, act: 'IPC', section: '379');
      await firNext(tester);
      await firBack(tester);

      expect(firStep(FirFormStep.registration), findsOneWidget);
      expect(
        tester.widget<TextField>(firInput(FirFieldKeys.firNo)).controller!.text,
        'FIR001',
      );
    });

    // An FIR is registered when it is written; that is a fact, not a guess.
    testWidgets('seeds the FIR date with today and nothing else', (
      tester,
    ) async {
      await pumpFirForm(tester, repository: FakeFirRepository());

      expect(
        find.text(FormDates.displayDate(FormDates.toWireDate(DateTime.now()))),
        findsOneWidget,
      );
      expect(
        tester.widget<TextField>(firInput(FirFieldKeys.firNo)).controller!.text,
        isEmpty,
      );
    });

    testWidgets('shows no errors before anything has been attempted', (
      tester,
    ) async {
      await pumpFirForm(tester, repository: FakeFirRepository());

      expect(find.text('Required'), findsNothing);
    });
  });

  // The website picks proof files during the FIR form and uploads them the line
  // after `/generate_fir` answers (`uploadProofsForFIR` in script.js). The app
  // could not do it at all: an officer had to file the FIR, remember the
  // number, leave the form, open the locker and type the number back in.
  group('proof attachments', () {
    EvidenceFile aFile([String name = 'scene.jpg']) => EvidenceFile(
          path: '/tmp/$name',
          name: name,
          sizeInBytes: 2048,
        );

    Future<void> attach(WidgetTester tester) async {
      await tester.tap(find.byKey(FirProofKeys.attach));
      await tester.pumpAndSettle();
      await tester.tap(find.text(EvidenceSource.camera.label));
      await tester.pumpAndSettle();
    }

    testWidgets('a picked file is listed but not yet uploaded', (tester) async {
      final evidence = FakeEvidenceRepository();
      await pumpFirForm(
        tester,
        repository: FakeFirRepository(),
        evidence: evidence,
        picker: FakeEvidenceFilePicker(result: aFile()),
      );

      await goToComplaintStep(tester);
      await attach(tester);

      expect(find.byKey(FirProofKeys.row('scene.jpg')), findsOneWidget);
      // Nothing can go up yet: /upload-evidence refuses an FIR that is not in
      // the register, which is the whole reason these are held.
      expect(evidence.uploads, isEmpty);
    });

    testWidgets('the same file twice is one attachment', (tester) async {
      await pumpFirForm(
        tester,
        repository: FakeFirRepository(),
        picker: FakeEvidenceFilePicker(result: aFile()),
      );

      await goToComplaintStep(tester);
      await attach(tester);
      await attach(tester);

      expect(find.byKey(FirProofKeys.row('scene.jpg')), findsOneWidget);
    });

    testWidgets('a dismissed picker attaches nothing', (tester) async {
      await pumpFirForm(
        tester,
        repository: FakeFirRepository(),
        picker: FakeEvidenceFilePicker(),
      );

      await goToComplaintStep(tester);
      await attach(tester);

      expect(find.byKey(FirProofKeys.row('scene.jpg')), findsNothing);
    });

    testWidgets('filing the FIR files the attachments against its number', (
      tester,
    ) async {
      final evidence = FakeEvidenceRepository();
      await pumpFirForm(
        tester,
        repository: FakeFirRepository(),
        evidence: evidence,
        picker: FakeEvidenceFilePicker(result: aFile()),
      );

      await fillMinimalFirWithProof(tester);
      await tapFile(tester);

      expect(evidence.uploads, hasLength(1));
      expect(evidence.uploads.single.firNo, 'FIR001');
      expect(evidence.uploads.single.file.name, 'scene.jpg');
      expect(
        find.textContaining('1 file filed against this FIR.'),
        findsOneWidget,
      );
    });

    // The record is written by the time the uploads run. Reporting the filing
    // as failed would be wrong, and retrying it would put a second FIR in the
    // register.
    testWidgets('an upload that fails does not fail the filing', (
      tester,
    ) async {
      final evidence = FakeEvidenceRepository()
        ..uploadFailure = const NetworkFailure(
          message: 'Cannot reach the NyayaAI server.',
        );
      await pumpFirForm(
        tester,
        repository: FakeFirRepository(),
        evidence: evidence,
        picker: FakeEvidenceFilePicker(result: aFile()),
      );

      await fillMinimalFirWithProof(tester);
      await tapFile(tester);

      // On the receipt, not back on the form.
      expect(find.text('FIR001'), findsOneWidget);
      expect(
        find.textContaining('The FIR is registered.'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Cannot reach the NyayaAI server.'),
        findsOneWidget,
      );
    });
  });

  group('validation', () {
    // The whole reason for validating per step: the message lands on the page
    // that can fix it, not four pages later at Submit.
    testWidgets('a refused Next stays put and marks that step\'s blanks', (
      tester,
    ) async {
      await pumpFirForm(tester, repository: FakeFirRepository());

      await firNext(tester);

      expect(firStep(FirFormStep.registration), findsOneWidget);
      // Three of step 1's four: the FIR date is already seeded. Acts and
      // sections are not among them — the server fills those from the
      // narrative, so the form no longer demands them.
      expect(find.text('Required'), findsNWidgets(3));
    });

    testWidgets('the error clears as soon as the entry is filled', (
      tester,
    ) async {
      await pumpFirForm(tester, repository: FakeFirRepository());

      await firNext(tester);
      expect(find.text('Required'), findsNWidgets(3));

      await enterFir(tester, FirFieldKeys.firNo, 'FIR001');
      await tester.pump();

      expect(find.text('Required'), findsNWidgets(2));
    });

    // Nothing on step 2 is required — an informant unsure which day it happened
    // is still entitled to have the complaint registered.
    testWidgets('step 2 lets everything through blank', (tester) async {
      await pumpFirForm(tester, repository: FakeFirRepository());

      await enterFir(tester, FirFieldKeys.firNo, 'FIR001');
      await chooseOption(tester, FirFieldKeys.district, 'Delhi');
      await chooseOption(tester, FirFieldKeys.policeStation, 'North Delhi PS');
      await addSection(tester, act: 'IPC', section: '379');
      await firNext(tester);

      await firNext(tester);

      expect(firStep(FirFormStep.complainant), findsOneWidget);
      expect(find.text('Required'), findsNothing);
    });

    // Reachable only by editing a step empty from the review, since Next guards
    // every step on the way through. The backstop has to land the officer on
    // the page that is wrong rather than flag a box nobody is looking at.
    testWidgets('a refused File returns to the step that is missing something',
        (tester) async {
      final repository = FakeFirRepository();
      await pumpFirForm(tester, repository: repository);
      await fillMinimalFir(tester);

      await tapReviewEdit(tester, FirFormStep.complaint);
      await enterFir(tester, FirFieldKeys.statement, '');
      await firNext(tester);

      // Refused on the way out, which is the first line of defence.
      expect(firStep(FirFormStep.complaint), findsOneWidget);
      expect(find.text('Required'), findsOneWidget);
      expect(repository.registered, isEmpty);
    });
  });

  group('the review', () {
    testWidgets('shows what was entered and marks what was not', (
      tester,
    ) async {
      await pumpFirForm(tester, repository: FakeFirRepository());
      await fillMinimalFir(tester);

      expect(find.text('FIR001'), findsOneWidget);
      expect(find.text('A. Sharma'), findsOneWidget);
      expect(find.text('IPC Section 379'), findsOneWidget);
      // Step 2 was skipped entirely, and the review says so rather than hiding
      // the entries — this is the last moment anything can be added.
      expect(find.text('Not recorded'), findsWidgets);
    });

    testWidgets('Edit jumps back into the step that owns the entry', (
      tester,
    ) async {
      await pumpFirForm(tester, repository: FakeFirRepository());
      await fillMinimalFir(tester);

      await tapReviewEdit(tester, FirFormStep.complainant);

      expect(firStep(FirFormStep.complainant), findsOneWidget);
      expect(
        tester
            .widget<TextField>(firInput(FirFieldKeys.complainantName))
            .controller!
            .text,
        'A. Sharma',
      );
    });
  });

  group('district and station', () {
    testWidgets('the station cannot be chosen before a district', (
      tester,
    ) async {
      await pumpFirForm(tester, repository: FakeFirRepository());

      expect(find.text('Choose a district first'), findsOneWidget);
    });

    // A station belongs to exactly one district. Keeping the old one would file
    // the FIR against a station that is not in the district named beside it.
    testWidgets('changing the district clears the station', (tester) async {
      await pumpFirForm(tester, repository: FakeFirRepository());

      await chooseOption(tester, FirFieldKeys.district, 'Delhi');
      await chooseOption(tester, FirFieldKeys.policeStation, 'North Delhi PS');
      expect(find.text('North Delhi PS'), findsOneWidget);

      await chooseOption(tester, FirFieldKeys.district, 'Maharashtra');
      expect(find.text('North Delhi PS'), findsNothing);
    });

    // Registering an FIR is a legal duty with a clock on it; the district list
    // is a convenience.
    testWidgets('a failed lookup offers typed entry instead of blocking', (
      tester,
    ) async {
      final repository = FakeFirRepository()
        ..lookupFailure = const NetworkFailure();
      await pumpFirForm(tester, repository: repository);

      expect(
        find.text(
          'Cannot reach the NyayaAI server. Check your connection and try '
          'again.',
        ),
        findsWidgets,
      );
      expect(find.text('Retry'), findsWidgets);

      await tapPicker(tester, FirFieldKeys.district);
      await tester.enterText(find.byType(TextField).last, 'Goa');
      await tester.tap(find.text('Use this'));
      await tester.pumpAndSettle();

      expect(find.text('Goa'), findsOneWidget);
    });
  });

  group('acts and sections', () {
    testWidgets('builds the stored spelling from the pair that was picked', (
      tester,
    ) async {
      await pumpFirForm(tester, repository: FakeFirRepository());
      await addSection(tester, act: 'IPC', section: '379');

      expect(find.text('IPC Section 379'), findsOneWidget);
    });

    testWidgets('a second pair joins the first rather than replacing it', (
      tester,
    ) async {
      await pumpFirForm(tester, repository: FakeFirRepository());
      await addSection(tester, act: 'IPC', section: '379');
      await addSection(tester, act: 'CRPC', section: '41');

      expect(find.text('IPC Section 379'), findsOneWidget);
      expect(find.text('CRPC Section 41'), findsOneWidget);
    });
  });

  group('filing', () {
    testWidgets('sends what the officer entered and lands on the receipt', (
      tester,
    ) async {
      final repository = FakeFirRepository();
      await pumpFirForm(tester, repository: repository);
      await fillMinimalFir(tester);

      await tapFile(tester);

      expect(repository.registered, hasLength(1));
      final sent = repository.registered.single;
      expect(sent.firNo, 'FIR001');
      expect(sent.district, 'Delhi');
      expect(sent.policeStation, 'North Delhi PS');
      expect(sent.complainantName, 'A. Sharma');
      expect(sent.actSectionsWire, 'IPC Section 379');
      expect(sent.statement, contains('Two-wheeler'));
      // Derived, not typed.
      expect(sent.year, DateTime.now().year.toString());

      expect(find.text('FIR registered'), findsOneWidget);
      expect(find.text('FIR001'), findsOneWidget);
      expect(find.text('Give this number to the complainant.'), findsOneWidget);
    });

    // The optional entries, which nothing else asserts on. This is the test
    // that fails if one of them ever stops reaching the server.
    testWidgets('carries the optional entries the paper form asks for', (
      tester,
    ) async {
      final repository = FakeFirRepository();
      await pumpFirForm(tester, repository: repository);

      await enterFir(tester, FirFieldKeys.firNo, 'FIR001');
      await chooseOption(tester, FirFieldKeys.district, 'Delhi');
      await chooseOption(tester, FirFieldKeys.policeStation, 'North Delhi PS');
      await addSection(tester, act: 'IPC', section: '379');
      await firNext(tester);

      await enterFir(tester, FirFieldKeys.gdrEntryNo, 'GD 114/2026');
      await enterFir(tester, FirFieldKeys.typeOfInformation, 'Oral');
      await enterFir(
        tester,
        FirFieldKeys.placeOfOccurrence,
        'Sector 14 market',
      );
      await firNext(tester);

      await enterFir(tester, FirFieldKeys.complainantName, 'A. Sharma');
      await enterFir(tester, FirFieldKeys.fatherHusbandName, 'S. Sharma');
      await enterFir(tester, FirFieldKeys.nationality, 'Indian');
      await enterFir(tester, FirFieldKeys.occupation, 'Shopkeeper');
      await enterFir(tester, FirFieldKeys.address, '14/2, Sector 14');
      await enterFir(tester, FirFieldKeys.passportNo, 'Z1234567');
      await enterFir(tester, FirFieldKeys.placeOfIssue, 'Delhi');
      await firNext(tester);

      await enterFir(tester, FirFieldKeys.detailsOfAccused, 'Two men, unknown');
      await enterFir(
        tester,
        FirFieldKeys.propertyParticulars,
        'Scooter, 60,000',
      );
      await enterFir(tester, FirFieldKeys.reasonsForDelay, 'Reported next day');
      await enterFir(tester, FirFieldKeys.statement, 'Scooter taken at noon.');
      await firNext(tester);
      await tapFile(tester);

      final sent = repository.registered.single;
      expect(sent.gdrEntryNo, 'GD 114/2026');
      expect(sent.typeOfInformation, 'Oral');
      expect(sent.placeOfOccurrence, 'Sector 14 market');
      expect(sent.fatherHusbandName, 'S. Sharma');
      expect(sent.nationality, 'Indian');
      expect(sent.occupation, 'Shopkeeper');
      expect(sent.address, '14/2, Sector 14');
      expect(sent.passportNo, 'Z1234567');
      expect(sent.placeOfIssue, 'Delhi');
      expect(sent.detailsOfAccused, 'Two men, unknown');
      expect(sent.propertyParticulars, 'Scooter, 60,000');
      expect(sent.reasonsForDelay, 'Reported next day');
    });

    testWidgets('one press files one FIR, however fast the second is', (
      tester,
    ) async {
      final repository = FakeFirRepository()
        ..delay = const Duration(milliseconds: 300);
      await pumpFirForm(tester, repository: repository);
      await fillMinimalFir(tester);

      await tester.tap(find.byKey(FirFieldKeys.submit));
      await tester.pump();
      // Mid-flight the button is a spinner, so a second tap has nothing to hit.
      // Tap where it was anyway.
      await tester.tap(find.byKey(FirFieldKeys.submit), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(repository.registered, hasLength(1));
    });

    testWidgets('a rejected FIR number stays on the review and says why', (
      tester,
    ) async {
      final repository = FakeFirRepository()
        ..registerFailure =
            const ValidationFailure('FIR number FIR001 already exists');
      await pumpFirForm(tester, repository: repository);
      await fillMinimalFir(tester);

      await tapFile(tester);

      // The server's own wording, verbatim — it knows which numbers are taken.
      expect(find.text('FIR number FIR001 already exists'), findsOneWidget);
      expect(find.text('FIR registered'), findsNothing);
      expect(firStep(FirFormStep.review), findsOneWidget);
    });

    testWidgets('the receipt offers a fresh form, not the filed one', (
      tester,
    ) async {
      await pumpFirForm(tester, repository: FakeFirRepository());
      await fillMinimalFir(tester);
      await tapFile(tester);

      await tester.tap(find.text('File another FIR'));
      await tester.pumpAndSettle();

      // Back at step 1 of an empty wizard, not on the review of a filed one.
      expect(firStep(FirFormStep.registration), findsOneWidget);
      expect(
        tester.widget<TextField>(firInput(FirFieldKeys.firNo)).controller!.text,
        isEmpty,
      );
    });
  });

  group('the draft', () {
    testWidgets('is saved as the officer types', (tester) async {
      final storage = InMemorySecureStorage();
      await pumpFirForm(
        tester,
        repository: FakeFirRepository(),
        storage: storage,
      );

      await enterFir(tester, FirFieldKeys.firNo, 'FIR007');
      // Past the autosave debounce.
      await tester.pump(const Duration(seconds: 2));

      final saved = jsonDecode(storage.values[StorageKeys.firDraft]!)
          as Map<String, dynamic>;
      expect(saved['fir_no'], 'FIR007');
    });

    testWidgets('is restored into the boxes it was typed into', (tester) async {
      final storage = InMemorySecureStorage({
        StorageKeys.firDraft: jsonEncode(
          const FirDraft(
            firNo: 'FIR007',
            district: 'Delhi',
            policeStation: 'North Delhi PS',
            firDate: '2026-08-09',
            // Present so step 1 is complete and Next lets the assertion below
            // reach step 2. A half-finished draft is the realistic case, but it
            // is not what this test is about.
            sections: [ActSection(act: 'IPC', section: '379')],
            placeOfOccurrence: 'Bus stand',
            complainantName: 'R. Iyer',
          ).toJson(),
        ),
      });

      await pumpFirForm(
        tester,
        repository: FakeFirRepository(),
        storage: storage,
      );

      expect(
        tester.widget<TextField>(firInput(FirFieldKeys.firNo)).controller!.text,
        'FIR007',
      );
      expect(
        find.textContaining('Picked up where you left off'),
        findsOneWidget,
      );

      // The entries on later steps come back too — the controllers are seeded
      // once, by the shell, from a draft that has finished restoring.
      await firNext(tester);
      expect(
        tester
            .widget<TextField>(firInput(FirFieldKeys.placeOfOccurrence))
            .controller!
            .text,
        'Bus stand',
      );
    });

    testWidgets('is cleared once the FIR is on record', (tester) async {
      final storage = InMemorySecureStorage();
      await pumpFirForm(
        tester,
        repository: FakeFirRepository(),
        storage: storage,
      );
      await fillMinimalFir(tester);

      await tapFile(tester);

      // A filed FIR left in storage would be offered back as unfinished work.
      expect(storage.values.containsKey(StorageKeys.firDraft), isFalse);
    });

    testWidgets('discard empties both the storage and the boxes', (
      tester,
    ) async {
      final storage = InMemorySecureStorage({
        StorageKeys.firDraft: jsonEncode(
          const FirDraft(
            firNo: 'FIR007',
            sections: [ActSection(act: 'IPC', section: '379')],
          ).toJson(),
        ),
      });

      await pumpFirForm(
        tester,
        repository: FakeFirRepository(),
        storage: storage,
      );
      expect(
        tester.widget<TextField>(firInput(FirFieldKeys.firNo)).controller!.text,
        'FIR007',
      );

      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard draft'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();

      expect(storage.values.containsKey(StorageKeys.firDraft), isFalse);
      expect(find.text('HOME'), findsOneWidget);
    });

    // The form seeds itself with today's FIR date, so it is never quite empty.
    // Saving that would greet the next visit with "picked up where you left
    // off" over a page nobody wrote on.
    testWidgets('opening and leaving without typing saves nothing', (
      tester,
    ) async {
      final storage = InMemorySecureStorage();
      await pumpFirForm(
        tester,
        repository: FakeFirRepository(),
        storage: storage,
      );

      // The header's arrow, which on step 1 leaves the form.
      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 2));

      expect(storage.values.containsKey(StorageKeys.firDraft), isFalse);
    });
  });
}
