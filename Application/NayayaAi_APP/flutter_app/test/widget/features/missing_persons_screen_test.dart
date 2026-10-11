import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nayaya_app/core/error/failure.dart';
import 'package:nayaya_app/features/evidence/domain/entities/evidence_file.dart';
import 'package:nayaya_app/features/missing_persons/domain/entities/confirmed_match.dart';
import 'package:nayaya_app/features/missing_persons/domain/entities/missing_person.dart';
import 'package:nayaya_app/features/missing_persons/domain/entities/sighting.dart';
import 'package:nayaya_app/features/missing_persons/presentation/widgets/missing_person_keys.dart';
import 'package:nayaya_app/features/missing_persons/presentation/widgets/person_photo.dart';

import '../../helpers/fake_evidence_repository.dart';
import '../../helpers/fake_missing_person_repository.dart';
import '../../helpers/pump_missing_persons_app.dart';

void main() {
  EvidenceFile aPhoto([String name = 'face.jpg']) =>
      EvidenceFile(path: '/tmp/$name', name: name, sizeInBytes: 4096);

  Future<void> type(WidgetTester tester, Key key, String text) async {
    await tester.enterText(
      find.descendant(of: find.byKey(key), matching: find.byType(TextField)),
      text,
    );
    await tester.pump();
  }

  group('the register', () {
    testWidgets('lists the open cases', (tester) async {
      await pumpMissingPersons(
        tester,
        repository: FakeMissingPersonRepository(),
      );

      expect(find.byKey(MissingPersonKeys.tile('MP_1')), findsOneWidget);
      expect(find.byKey(MissingPersonKeys.tile('MP_2')), findsOneWidget);
      expect(find.text('satyam gupta'), findsOneWidget);
      expect(find.text('18 · Male'), findsOneWidget);
    });

    testWidgets('the search reads the name and the place last seen', (
      tester,
    ) async {
      await pumpMissingPersons(
        tester,
        repository: FakeMissingPersonRepository(),
      );

      await type(tester, MissingPersonKeys.search, 'virar');

      expect(find.byKey(MissingPersonKeys.tile('MP_2')), findsOneWidget);
      expect(find.byKey(MissingPersonKeys.tile('MP_1')), findsNothing);
    });

    testWidgets('an empty register explains why a case might be absent', (
      tester,
    ) async {
      await pumpMissingPersons(
        tester,
        repository: FakeMissingPersonRepository(people: []),
      );

      expect(find.text('No open cases'), findsOneWidget);
      expect(find.textContaining('marked Found or Closed'), findsOneWidget);
    });

    testWidgets('a failed register explains itself', (tester) async {
      await pumpMissingPersons(
        tester,
        repository: FakeMissingPersonRepository()
          ..listFailure = const NetworkFailure(
            message: 'Cannot reach the NyayaAI server.',
          ),
      );

      expect(find.text('The register could not be loaded'), findsOneWidget);
    });
  });

  group('the confirmed matches', () {
    testWidgets('sit above the register when there are any', (tester) async {
      await pumpMissingPersons(
        tester,
        repository: FakeMissingPersonRepository(
          matches: const [
            ConfirmedMatch(
              personId: 'MP_1',
              name: 'satyam gupta',
              personPhotoPath: '/static/uploads/missing_persons/MP_1.jpg',
              sightings: [
                Sighting(
                  sightingId: 'SG_1',
                  location: 'Nalasopara station',
                  matchPercent: 72.4,
                  isConfirmed: true,
                ),
                Sighting(
                  sightingId: 'SG_2',
                  location: 'Virar market',
                  matchPercent: 61.2,
                  isConfirmed: true,
                ),
              ],
            ),
          ],
        ),
      );

      expect(find.byKey(MissingPersonKeys.matchesBanner), findsOneWidget);
      expect(find.text('ONE POSSIBLE MATCH'), findsOneWidget);
      expect(find.textContaining('72% match'), findsOneWidget);
      expect(find.text('1 more sighting'), findsOneWidget);
    });

    testWidgets('are absent entirely when there are none', (tester) async {
      await pumpMissingPersons(
        tester,
        repository: FakeMissingPersonRepository(),
      );

      expect(find.byKey(MissingPersonKeys.matchesBanner), findsNothing);
    });

    // These endpoints really are police-only. A lapsed session must not take
    // the register down with it — the register has no session check.
    testWidgets('a 403 hides the panel without breaking the register', (
      tester,
    ) async {
      await pumpMissingPersons(
        tester,
        repository: FakeMissingPersonRepository()
          ..policeOnlyFailure =
              const AuthFailure(message: 'Police login required.'),
      );

      expect(find.byKey(MissingPersonKeys.matchesBanner), findsNothing);
      expect(find.byKey(MissingPersonKeys.tile('MP_1')), findsOneWidget);
    });
  });

  group('registering a case', () {
    testWidgets('cannot be submitted without a photograph', (tester) async {
      final repository = FakeMissingPersonRepository();
      await pumpMissingPersons(
        tester,
        repository: repository,
        initialLocation: '/missing-persons/new',
      );

      await type(tester, MissingPersonKeys.name, 'A. Sharma');
      await tester.tap(find.byKey(MissingPersonKeys.submit));
      await tester.pumpAndSettle();

      expect(repository.registered, isEmpty);
    });

    testWidgets('sends every field the officer filled', (tester) async {
      final repository = FakeMissingPersonRepository();
      await pumpMissingPersons(
        tester,
        repository: repository,
        picker: FakeEvidenceFilePicker(result: aPhoto()),
        initialLocation: '/missing-persons/new',
      );

      await tester.tap(find.text('Choose a photograph'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Take a photo'));
      await tester.pumpAndSettle();

      await type(tester, MissingPersonKeys.name, 'A. Sharma');
      await type(tester, MissingPersonKeys.age, '14');
      await type(tester, MissingPersonKeys.gender, 'Female');
      await type(tester, MissingPersonKeys.lastSeenLocation, 'Sector 14');
      await type(tester, MissingPersonKeys.description, 'Blue school uniform');

      await tester.tap(find.byKey(MissingPersonKeys.submit));
      await tester.pumpAndSettle();

      expect(repository.registered, hasLength(1));
      final draft = repository.registered.single;
      expect(draft.name, 'A. Sharma');
      expect(draft.age, '14');
      expect(draft.gender, 'Female');
      expect(draft.lastSeenLocation, 'Sector 14');
      expect(draft.description, 'Blue school uniform');
      expect(draft.photoName, 'face.jpg');
    });

    testWidgets('a blank name is refused before anything is sent', (
      tester,
    ) async {
      final repository = FakeMissingPersonRepository();
      await pumpMissingPersons(
        tester,
        repository: repository,
        picker: FakeEvidenceFilePicker(result: aPhoto()),
        initialLocation: '/missing-persons/new',
      );

      await tester.tap(find.text('Choose a photograph'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Take a photo'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(MissingPersonKeys.submit));
      await tester.pumpAndSettle();

      expect(repository.registered, isEmpty);
      expect(find.text('Required'), findsOneWidget);
    });

    // The server deletes the upload and refuses when it finds no face. Its own
    // sentence is the instruction; "Registration failed" is not.
    testWidgets('the server\'s refusal is shown in its own words', (
      tester,
    ) async {
      final repository = FakeMissingPersonRepository()
        ..registerFailure = const ValidationFailure(
          'No face detected in the photo. Please upload a clear frontal image.',
        );
      await pumpMissingPersons(
        tester,
        repository: repository,
        picker: FakeEvidenceFilePicker(result: aPhoto()),
        initialLocation: '/missing-persons/new',
      );

      await tester.tap(find.text('Choose a photograph'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Take a photo'));
      await tester.pumpAndSettle();
      await type(tester, MissingPersonKeys.name, 'A. Sharma');
      await tester.tap(find.byKey(MissingPersonKeys.submit));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('No face detected in the photo.'),
        findsOneWidget,
      );
    });
  });

  group('one case', () {
    testWidgets('shows the details and the sightings', (tester) async {
      await pumpMissingPersons(
        tester,
        repository: FakeMissingPersonRepository(
          sightingsByPerson: const {
            'MP_1': [
              Sighting(
                sightingId: 'SG_1',
                location: 'Nalasopara station',
                sightingDate: '2026-08-20',
                matchPercent: 72.4,
                isConfirmed: true,
              ),
            ],
          },
        ),
        initialLocation: '/missing-persons/MP_1',
      );

      expect(find.text('satyam gupta'), findsOneWidget);
      expect(find.text('nalasopara'), findsOneWidget);
      expect(find.byKey(MissingPersonKeys.sighting('SG_1')), findsOneWidget);
      expect(find.text('72% match'), findsOneWidget);
    });

    // The photograph people take of a missing person is full-body and portrait.
    // A square centre crop kept the torso and cut the head off — on the one
    // screen where the face is the whole point, and for a feature whose entire
    // premise is comparing faces.
    testWidgets('the photograph is shown whole, not cropped to a square', (
      tester,
    ) async {
      await pumpMissingPersons(
        tester,
        repository: FakeMissingPersonRepository(),
        initialLocation: '/missing-persons/MP_1',
      );

      final image = tester.widget<Image>(
        find
            .descendant(
              of: find.byType(PersonPhoto),
              matching: find.byType(Image),
            )
            .first,
      );

      expect(image.fit, BoxFit.contain);
    });

    // The thumbnails in a list stay square — a list of mixed aspect ratios is a
    // ragged list — but crop from the top, so a portrait keeps its head.
    testWidgets('list thumbnails crop from the top, not the middle', (
      tester,
    ) async {
      await pumpMissingPersons(
        tester,
        repository: FakeMissingPersonRepository(),
      );

      final image = tester.widget<Image>(
        find
            .descendant(
              of: find.byType(PersonPhoto),
              matching: find.byType(Image),
            )
            .first,
      );

      expect(image.fit, BoxFit.cover);
      expect(image.alignment, Alignment.topCenter);
    });

    testWidgets('a case that has left the register says so', (tester) async {
      await pumpMissingPersons(
        tester,
        repository: FakeMissingPersonRepository(),
        initialLocation: '/missing-persons/MP_GONE',
      );

      expect(find.text('This case is no longer open'), findsOneWidget);
    });

    testWidgets('reporting a sighting sends the photograph and the place', (
      tester,
    ) async {
      final repository = FakeMissingPersonRepository();
      await pumpMissingPersons(
        tester,
        repository: repository,
        picker: FakeEvidenceFilePicker(result: aPhoto('seen.jpg')),
        initialLocation: '/missing-persons/MP_1',
      );

      await tester.tap(find.byKey(MissingPersonKeys.reportSighting));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add the photograph'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Take a photo'));
      await tester.pumpAndSettle();
      await type(tester, MissingPersonKeys.sightingLocation, 'Bus stand');
      await tester.tap(find.byKey(MissingPersonKeys.sightingSubmit));
      await tester.pumpAndSettle();

      expect(repository.sightingsFiled, hasLength(1));
      expect(repository.sightingsFiled.single.personId, 'MP_1');
      expect(repository.sightingsFiled.single.location, 'Bus stand');
      expect(repository.sightingsFiled.single.photoName, 'seen.jpg');
      // The server's own sentence, which already names the confidence.
      expect(find.textContaining('Match confirmed'), findsOneWidget);
    });

    testWidgets('a sighting with no place is refused before it is sent', (
      tester,
    ) async {
      final repository = FakeMissingPersonRepository();
      await pumpMissingPersons(
        tester,
        repository: repository,
        picker: FakeEvidenceFilePicker(result: aPhoto()),
        initialLocation: '/missing-persons/MP_1',
      );

      await tester.tap(find.byKey(MissingPersonKeys.reportSighting));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add the photograph'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Take a photo'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(MissingPersonKeys.sightingSubmit));
      await tester.pumpAndSettle();

      expect(repository.sightingsFiled, isEmpty);
      expect(
        find.text('Where they were seen is required.'),
        findsOneWidget,
      );
    });

    // It cannot be undone from the app, so it is confirmed, and the dialog says
    // what "cannot be undone" actually means here.
    testWidgets('marking found asks first, and says it is one-way', (
      tester,
    ) async {
      final repository = FakeMissingPersonRepository();
      await pumpMissingPersons(
        tester,
        repository: repository,
        initialLocation: '/missing-persons/MP_1',
      );

      await tester.tap(find.byKey(MissingPersonKeys.markFound));
      await tester.pumpAndSettle();

      expect(find.text('Mark as found?'), findsOneWidget);
      expect(
        find.textContaining('Nothing in the app can reopen it'),
        findsOneWidget,
      );

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(repository.statuses, isEmpty);
    });

    testWidgets('confirming marks the case found', (tester) async {
      final repository = FakeMissingPersonRepository();
      await pumpMissingPersons(
        tester,
        repository: repository,
        initialLocation: '/missing-persons/MP_1',
      );

      await tester.tap(find.byKey(MissingPersonKeys.markFound));
      await tester.pumpAndSettle();
      // The dialog's own button, not the screen's — they carry the same label,
      // which is the point: the dialog confirms the action it was opened by.
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(FilledButton, 'Mark as found'),
        ),
      );
      await tester.pumpAndSettle();

      expect(repository.statuses, hasLength(1));
      expect(repository.statuses.single.personId, 'MP_1');
      expect(repository.statuses.single.status, MissingPersonStatus.found);
    });
  });
}
