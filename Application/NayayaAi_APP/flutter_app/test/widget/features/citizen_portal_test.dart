import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nayaya_app/core/error/failure.dart';
import 'package:nayaya_app/features/citizen/data/models/case_client_status.dart';
import 'package:nayaya_app/features/citizen/presentation/screens/case_status_screen.dart';
import 'package:nayaya_app/features/citizen/presentation/screens/citizen_missing_person_detail_screen.dart';
import 'package:nayaya_app/features/citizen/presentation/screens/file_complaint_screen.dart';
import 'package:nayaya_app/features/citizen/presentation/screens/rights_chat_screen.dart';
import 'package:nayaya_app/features/citizen/presentation/screens/track_complaint_screen.dart';
import 'package:nayaya_app/features/evidence/domain/entities/evidence_file.dart';
import 'package:nayaya_app/features/missing_persons/domain/entities/missing_person.dart';
import 'package:nayaya_app/features/missing_persons/domain/entities/sighting.dart';

import '../../helpers/fake_citizen_repositories.dart';
import '../../helpers/fake_evidence_repository.dart';
import '../../helpers/fake_missing_person_repository.dart';
import '../../helpers/pump_citizen_app.dart';

/// The Citizen Portal against `templates/citizen_dashboard.html`: every string
/// asserted here is the website's, and every behaviour is one the website has.
void main() {
  Finder fieldsIn(Type screen) => find.descendant(
        of: find.byType(screen),
        matching: find.byType(TextField),
      );

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.ensureVisible(find.text(text).first);
    await tester.tap(find.text(text).first);
    await tester.pumpAndSettle();
  }

  group('the shell', () {
    testWidgets('opens on Home, as showSection("home") does', (tester) async {
      await pumpCitizenApp(tester);

      expect(find.text('Powered by NyayaAI · Citizen Portal'), findsOneWidget);
      expect(find.text('Quick Actions'), findsOneWidget);
      expect(find.text('Available 24×7'), findsOneWidget);
      for (final label in [
        'Police 100',
        'Women 1091',
        'Emergency 112',
        'Cyber 1930',
        'Child 1098',
        'Legal Aid 15100',
      ]) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      // The website's home shows nothing about the citizen.
      expect(find.text('CIT001'), findsNothing);
    });

    testWidgets('the drawer is the sidebar: seven sections and Sign Out', (
      tester,
    ) async {
      await pumpCitizenApp(tester);
      await tester.tap(find.byTooltip('Open navigation menu'));
      await tester.pumpAndSettle();

      final drawer = find.byType(Drawer);
      expect(
        find.descendant(of: drawer, matching: find.text('Citizen Portal')),
        findsOneWidget,
      );
      for (final label in [
        'Home',
        'File a Complaint',
        'Track Complaint',
        'My Case Status',
        'Know Your Rights',
        'Missing Persons',
        'Emergency Contacts',
        'Sign Out',
      ]) {
        expect(
          find.descendant(of: drawer, matching: find.text(label)),
          findsOneWidget,
          reason: label,
        );
      }
    });

    // Decision D-4a: the website's /logout link asks nothing.
    testWidgets('signs out at once, with no confirmation', (tester) async {
      final h = await pumpCitizenApp(tester);

      await tester.tap(find.byTooltip('Sign out'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      // The auth controller is first read on this tap; let its start-up
      // restore (and the splash floor it waits on) finish.
      await tester.pump(const Duration(seconds: 4));
      expect(h.auth.logoutCount, 1);
    });
  });

  // The rights topic cards overflowed by 11 px on a real handset: two lines of
  // subtitle did not fit the fixed cell height a GridView gave them. Nothing in
  // the suite noticed, because the default test text scale keeps them to one
  // line. Every section is now laid out at a larger scale as well, where an
  // overflow throws.
  group('layout holds at a larger text size', () {
    for (final section in [
      'Know Your Rights',
      'File a Complaint',
      'Track Complaint',
      'My Case Status',
      'Missing Persons',
      'Emergency Contacts',
    ]) {
      testWidgets('$section at 1.4x', (tester) async {
        await pumpCitizenApp(
          tester,
          size: const Size(360, 2600),
          textScale: 1.4,
        );
        await openCitizenSection(tester, section);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('Home at 1.4x', (tester) async {
      await pumpCitizenApp(
        tester,
        size: const Size(360, 2600),
        textScale: 1.4,
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('File a Complaint', () {
    testWidgets('refuses empty fields with the website alert', (tester) async {
      final h = await pumpCitizenApp(tester);
      await openCitizenSection(tester, 'File a Complaint');

      await tapText(tester, 'Submit Complaint');

      expect(
        find.text('Name and incident description are required.'),
        findsOneWidget,
      );
      expect(h.complaints.filed, isEmpty);
    });

    testWidgets('refuses a short phone number', (tester) async {
      final h = await pumpCitizenApp(tester);
      await openCitizenSection(tester, 'File a Complaint');

      final fields = fieldsIn(FileComplaintScreen);
      await tester.enterText(fields.at(0), 'Asha Rao');
      await tester.enterText(fields.at(1), '98765');
      await tester.enterText(fields.at(3), 'My phone was stolen.');
      await tapText(tester, 'Submit Complaint');

      expect(
        find.text('Phone number must be exactly 10 digits.'),
        findsOneWidget,
      );
      expect(h.complaints.filed, isEmpty);
    });

    testWidgets('the name box drops anything but letters and spaces', (
      tester,
    ) async {
      await pumpCitizenApp(tester);
      await openCitizenSection(tester, 'File a Complaint');

      await tester.enterText(
        fieldsIn(FileComplaintScreen).at(0),
        'Asha 99 Rao!',
      );
      await tester.pump();

      expect(find.text('Asha  Rao'), findsOneWidget);
    });

    testWidgets('files it and shows the tracking ID in place of the form', (
      tester,
    ) async {
      final h = await pumpCitizenApp(tester);
      await openCitizenSection(tester, 'File a Complaint');

      final fields = fieldsIn(FileComplaintScreen);
      await tester.enterText(fields.at(0), 'Asha Rao');
      await tester.enterText(fields.at(1), '9876543210');
      await tester.enterText(fields.at(2), 'Andheri');
      await tester.enterText(fields.at(3), 'My phone was stolen.');
      await tapText(tester, 'Submit Complaint');

      expect(h.complaints.filed.single.toJson(), {
        'full_name': 'Asha Rao',
        'phone': '9876543210',
        'incident_date': '',
        'location': 'Andheri',
        'incident_description': 'My phone was stolen.',
      });
      expect(find.text('Complaint Filed Successfully!'), findsOneWidget);
      expect(find.text('CMP-1A2B3C4D'), findsOneWidget);
      expect(
        find.text('Save this ID to track your complaint status'),
        findsOneWidget,
      );
      expect(find.text('Submit Complaint'), findsNothing);
    });

    testWidgets('"Track My Complaint →" opens Track without filling the ID', (
      tester,
    ) async {
      await pumpCitizenApp(tester);
      await openCitizenSection(tester, 'File a Complaint');
      final fields = fieldsIn(FileComplaintScreen);
      await tester.enterText(fields.at(0), 'Asha');
      await tester.enterText(fields.at(3), 'Stolen.');
      await tapText(tester, 'Submit Complaint');

      await tapText(tester, 'Track My Complaint →');

      expect(find.text('Track Your Complaint'), findsOneWidget);
      final box =
          tester.widget<TextField>(fieldsIn(TrackComplaintScreen).first);
      expect(box.controller?.text, isEmpty);
    });

    testWidgets("a server refusal is alerted in the server's words", (
      tester,
    ) async {
      final h = CitizenHarness(
        complaints: FakeCitizenComplaintRepository(
          fileFailure: const ValidationFailure('Submission failed.'),
        ),
      );
      await pumpCitizenApp(tester, harness: h);
      await openCitizenSection(tester, 'File a Complaint');
      final fields = fieldsIn(FileComplaintScreen);
      await tester.enterText(fields.at(0), 'Asha');
      await tester.enterText(fields.at(3), 'Stolen.');
      await tapText(tester, 'Submit Complaint');

      expect(find.text('Submission failed.'), findsOneWidget);
      expect(find.text('Complaint Filed Successfully!'), findsNothing);
    });
  });

  group('Track Complaint', () {
    testWidgets('an empty ID is alerted', (tester) async {
      await pumpCitizenApp(tester);
      await openCitizenSection(tester, 'Track Complaint');

      await tapText(tester, 'Track');

      expect(find.text('Please enter your tracking ID.'), findsOneWidget);
    });

    testWidgets('shows what the website shows, and the timeline', (
      tester,
    ) async {
      final h = CitizenHarness(
        complaints: FakeCitizenComplaintRepository(
          complaints: {
            'CMP-1A2B3C4D': trackedComplaint(
              status: 'Under Review',
              officerNotes: 'Called the complainant.',
            ),
          },
        ),
      );
      await pumpCitizenApp(tester, harness: h);
      await openCitizenSection(tester, 'Track Complaint');

      await tester.enterText(
        fieldsIn(TrackComplaintScreen).first,
        'cmp-1a2b3c4d',
      );
      await tapText(tester, 'Track');

      expect(h.complaints.tracked.single, 'CMP-1A2B3C4D');
      expect(find.text('Under Review'), findsWidgets);
      expect(find.text('Asha Rao'), findsOneWidget);
      expect(find.text('Andheri'), findsOneWidget);
      expect(find.text('Called the complainant.'), findsOneWidget);
      expect(find.text('Officer reviewing details'), findsOneWidget);
      expect(find.text('Case closed'), findsOneWidget);
      // Only when there is one.
      expect(find.text('FIR NUMBER'), findsNothing);
      // The website does not show the description or the category.
      expect(find.text('My phone was stolen at the station.'), findsNothing);
      expect(find.text('Theft / Robbery'), findsNothing);
    });

    testWidgets('an FIR number appears once one is recorded', (tester) async {
      final h = CitizenHarness(
        complaints: FakeCitizenComplaintRepository(
          complaints: {
            'CMP-1A2B3C4D':
                trackedComplaint(status: 'FIR Filed', firNo: 'FIR-2026-041'),
          },
        ),
      );
      await pumpCitizenApp(tester, harness: h);
      await openCitizenSection(tester, 'Track Complaint');
      await tester.enterText(
        fieldsIn(TrackComplaintScreen).first,
        'CMP-1A2B3C4D',
      );
      await tapText(tester, 'Track');

      expect(find.text('FIR NUMBER'), findsOneWidget);
      expect(find.text('FIR-2026-041'), findsOneWidget);
    });

    testWidgets("an unknown ID shows the server's sentence", (tester) async {
      await pumpCitizenApp(tester);
      await openCitizenSection(tester, 'Track Complaint');
      await tester.enterText(fieldsIn(TrackComplaintScreen).first, 'CMP-NOPE');
      await tapText(tester, 'Track');

      expect(
        find.text('Complaint not found. Check your tracking ID.'),
        findsOneWidget,
      );
    });
  });

  group('Know Your Rights', () {
    testWidgets('greets, and a topic sends its exact question', (tester) async {
      final h = await pumpCitizenApp(tester);
      await openCitizenSection(tester, 'Know Your Rights');

      expect(
        find.textContaining("Hello! I'm here to help you understand"),
        findsOneWidget,
      );

      await tapText(tester, 'Right to Bail');

      expect(
        h.rights.asked.single,
        'What is my right to bail under Indian law?',
      );
      expect(
        find.text('What is my right to bail under Indian law?'),
        findsOneWidget,
      );
      expect(find.textContaining('right', findRichText: true), findsWidgets);
    });

    testWidgets('a failure reads "Could not connect…"', (tester) async {
      final h = CitizenHarness(
        rights: FakeRightsChatRepository()
          ..failure = const NetworkFailure(
            message:
                'Could not connect. Check your server is running and try again.',
          ),
      );
      await pumpCitizenApp(tester, harness: h);
      await openCitizenSection(tester, 'Know Your Rights');

      await tester.enterText(fieldsIn(RightsChatScreen).first, 'Something odd');
      await tapText(tester, 'Ask');

      expect(
        find.text(
          'Could not connect. Check your server is running and try again.',
        ),
        findsOneWidget,
      );
    });

    // askRightsQuestion(q); showSection('know-rights') — lines 328-345.
    testWidgets('a home Quick Action asks and opens the section', (
      tester,
    ) async {
      final h = await pumpCitizenApp(tester);

      await tapText(tester, 'Arrest Rights');

      expect(h.rights.asked.single, 'What are my rights when I am arrested?');
      expect(find.byType(RightsChatScreen), findsOneWidget);
      expect(
        find.text('What are my rights when I am arrested?'),
        findsOneWidget,
      );
    });
  });

  group('My Case Status', () {
    testWidgets('shows the shared status, hearing and note', (tester) async {
      final h = CitizenHarness(
        cases: FakeCaseStatusRepository(
          statuses: {
            'FIR0009': const CaseClientStatus(
              firNo: 'FIR0009',
              status: 'Trial',
              clientNote: 'Bring your ID on the day.',
            ),
          },
        ),
      );
      await pumpCitizenApp(tester, harness: h);
      await openCitizenSection(tester, 'My Case Status');

      await tester.enterText(fieldsIn(CaseStatusScreen).first, 'FIR0009');
      await tapText(tester, 'Check');

      expect(find.text('Trial'), findsOneWidget);
      expect(find.text('Not scheduled'), findsOneWidget);
      expect(find.text('NOTE FROM YOUR LAWYER'), findsOneWidget);
      expect(find.text('Bring your ID on the day.'), findsOneWidget);
    });

    testWidgets('an unshared FIR shows the server sentence', (tester) async {
      await pumpCitizenApp(tester);
      await openCitizenSection(tester, 'My Case Status');
      await tester.enterText(fieldsIn(CaseStatusScreen).first, 'FIR0001');
      await tapText(tester, 'Check');

      expect(find.text('Status not available for this FIR'), findsOneWidget);
    });

    testWidgets('an empty FIR number does nothing', (tester) async {
      final h = await pumpCitizenApp(tester);
      await openCitizenSection(tester, 'My Case Status');
      await tapText(tester, 'Check');

      expect(h.cases.looked, isEmpty);
    });
  });

  group('Missing Persons', () {
    testWidgets('is not fetched until the section is opened', (tester) async {
      final missing = _CountingMissingPersons();
      await pumpCitizenApp(tester, harness: CitizenHarness(missing: missing));
      expect(missing.listCalls, 0);

      await openCitizenSection(tester, 'Missing Persons');

      expect(missing.listCalls, 1);
    });

    testWidgets('shows the citizen cards and the banner', (tester) async {
      await pumpCitizenApp(tester);
      await openCitizenSection(tester, 'Missing Persons');

      expect(
        find.text(
          'AI face recognition · Community sightings · Real-time matching',
        ),
        findsOneWidget,
      );
      expect(find.text('How it works'), findsOneWidget);
      expect(find.text('MISSING'), findsNWidgets(2));
      expect(find.text('satyam gupta'), findsOneWidget);
      expect(find.text('Age: 18 · Male'), findsOneWidget);
      expect(find.text('Last seen 2026-07-16'), findsOneWidget);
      expect(find.text('Report Sighting'), findsNWidgets(2));
      // Police-only views are not offered.
      expect(find.text('Confirmed Matches'), findsNothing);
    });

    testWidgets('an empty register reads "All clear"', (tester) async {
      await pumpCitizenApp(
        tester,
        harness: CitizenHarness(
          missing: FakeMissingPersonRepository(people: const []),
        ),
      );
      await openCitizenSection(tester, 'Missing Persons');

      expect(find.text('All clear — no active cases'), findsOneWidget);
      expect(
        find.text('Thank you for checking. Every visit matters.'),
        findsOneWidget,
      );
    });

    testWidgets('a failed load reads "Error loading data."', (tester) async {
      await pumpCitizenApp(
        tester,
        harness: CitizenHarness(
          missing: FakeMissingPersonRepository()
            ..listFailure = const NetworkFailure(),
        ),
      );
      await openCitizenSection(tester, 'Missing Persons');

      expect(find.text('Error loading data.'), findsOneWidget);
    });

    testWidgets('a card opens the same information on its own page', (
      tester,
    ) async {
      await pumpCitizenApp(tester);
      await openCitizenSection(tester, 'Missing Persons');

      await tapText(tester, 'satyam gupta');

      expect(find.byType(CitizenMissingPersonDetailScreen), findsOneWidget);
      expect(find.text('green shirt'), findsOneWidget);
      expect(find.text('Report Sighting'), findsOneWidget);
    });
  });

  group('Report Sighting', () {
    Future<CitizenHarness> openSheet(
      WidgetTester tester, {
      FakeMissingPersonRepository? missing,
      EvidenceFile? photo,
    }) async {
      final h = CitizenHarness(
        missing: missing,
        picker: FakeEvidenceFilePicker(result: photo),
      );
      await pumpCitizenApp(tester, harness: h);
      await openCitizenSection(tester, 'Missing Persons');
      await tapText(tester, 'Report Sighting');
      return h;
    }

    Finder sheetField() => find.descendant(
          of: find.byType(BottomSheet),
          matching: find.byType(TextField),
        );

    testWidgets('checks location, then photo, in the website order', (
      tester,
    ) async {
      final h = await openSheet(tester);

      expect(find.text('For: satyam gupta'), findsOneWidget);
      await tapText(tester, 'Submit Sighting');
      expect(find.text('Please enter a location.'), findsOneWidget);
      await tapText(tester, 'OK');

      await tester.enterText(sheetField().first, 'Virar station');
      await tapText(tester, 'Submit Sighting');
      expect(find.text('Please upload a photo.'), findsOneWidget);
      expect(h.missing.sightingsFiled, isEmpty);
    });

    testWidgets('a match reads "✓ Match Confirmed!" and closes', (
      tester,
    ) async {
      final h = await openSheet(
        tester,
        photo: const EvidenceFile(
          path: '/tmp/seen.jpg',
          name: 'seen.jpg',
          sizeInBytes: 1,
        ),
      );
      await tester.enterText(sheetField().first, 'Virar station');
      await tapText(tester, 'Click to upload photo');
      await tapText(tester, 'Choose a photo');
      await tapText(tester, 'Submit Sighting');

      expect(h.missing.sightingsFiled.single.location, 'Virar station');
      expect(find.text('✓ Match Confirmed!'), findsOneWidget);
      expect(find.text('Confidence: 72%', findRichText: true), findsOneWidget);
      expect(
        find.text('This sighting is now logged in Confirmed Matches.'),
        findsOneWidget,
      );

      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
    });

    testWidgets('a non-match reads "Sighting Recorded" and stays open', (
      tester,
    ) async {
      final missing = FakeMissingPersonRepository()
        ..sightingResult = const SightingResult(
          sightingId: 'SG_1',
          matchPercent: 41,
        );
      await openSheet(
        tester,
        missing: missing,
        photo: const EvidenceFile(
          path: '/tmp/seen.png',
          name: 'seen.png',
          sizeInBytes: 1,
        ),
      );
      await tester.enterText(sheetField().first, 'Virar station');
      await tapText(tester, 'Click to upload photo');
      await tapText(tester, 'Choose a photo');
      await tapText(tester, 'Submit Sighting');

      expect(find.text('Sighting Recorded'), findsOneWidget);
      expect(
        find.text('Thank you for reporting. Every sighting helps.'),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 3));
      expect(find.byType(BottomSheet), findsOneWidget);
    });

    testWidgets('a non-image file is refused before upload', (tester) async {
      final h = await openSheet(
        tester,
        photo: const EvidenceFile(
          path: '/tmp/clip.mp4',
          name: 'clip.mp4',
          sizeInBytes: 1,
        ),
      );
      await tapText(tester, 'Click to upload photo');
      await tapText(tester, 'Choose a photo');

      expect(find.text('Only image files accepted.'), findsOneWidget);
      expect(h.missing.sightingsFiled, isEmpty);
    });
  });

  group('Emergency Contacts', () {
    testWidgets('nine cards and the safety tips', (tester) async {
      await pumpCitizenApp(tester);
      await openCitizenSection(tester, 'Emergency Contacts');

      expect(
        find.text('One tap to call. Available 24×7 across India.'),
        findsOneWidget,
      );
      for (final number in [
        '100',
        '112',
        '108',
        '101',
        '1091',
        '1930',
        '1098',
        '14567',
        '15100',
      ]) {
        expect(find.text(number), findsOneWidget, reason: number);
      }
      expect(find.text('Tap to call'), findsNWidgets(9));
      expect(find.text('Safety Tips'), findsOneWidget);
      expect(
        find.text('Save these numbers in your phone now, before an emergency.'),
        findsOneWidget,
      );
    });
  });
}

class _CountingMissingPersons extends FakeMissingPersonRepository {
  int listCalls = 0;

  @override
  Future<List<MissingPerson>> all() {
    listCalls++;
    return super.all();
  }
}
