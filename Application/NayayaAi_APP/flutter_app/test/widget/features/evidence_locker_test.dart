import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nayaya_app/core/error/failure.dart';
import 'package:nayaya_app/features/evidence/data/datasources/evidence_file_picker.dart';
import 'package:nayaya_app/features/evidence/presentation/controllers/evidence_lock_controller.dart';
import 'package:nayaya_app/features/evidence/domain/entities/evidence_category.dart';
import 'package:nayaya_app/features/evidence/domain/entities/evidence_file.dart';
import 'package:nayaya_app/features/evidence/domain/entities/evidence_item.dart';
import 'package:nayaya_app/features/evidence/presentation/widgets/evidence_keys.dart';

import '../../helpers/fake_evidence_repository.dart';
import '../../helpers/fake_fir_repository.dart';
import '../../helpers/fir_records.dart';
import '../../helpers/pump_evidence_app.dart';

/// The locker's flow, end to end: gate → list → add → detail.
void main() {
  const photo = EvidenceFile(
    path: '/tmp/scene.jpg',
    name: 'scene.jpg',
    sizeInBytes: 2048,
  );

  group('the PIN gate', () {
    testWidgets('the locker is not built until the PIN is right', (
      tester,
    ) async {
      final repository = FakeEvidenceRepository();
      await pumpEvidenceLocker(tester, repository: repository);

      expect(find.byKey(EvidenceKeys.pinField), findsOneWidget);
      expect(find.byKey(EvidenceKeys.list), findsNothing);
      // Not merely hidden — nothing has been fetched.
      expect(find.text('scene.jpg'), findsNothing);
    });

    testWidgets('a wrong PIN says so and keeps the locker shut', (
      tester,
    ) async {
      await pumpEvidenceLocker(tester, repository: FakeEvidenceRepository());

      await enterPin(tester, 'not-the-pin');

      expect(find.text('Wrong PIN.'), findsOneWidget);
      expect(find.byKey(EvidenceKeys.list), findsNothing);
    });

    // The PIN is the server's to judge, not the app's. It used to be compared
    // in Dart against a constant of the app's own, so the handset and the
    // website's console opened the same locker with two different strings.
    testWidgets('the PIN is sent to the server, exactly as typed', (
      tester,
    ) async {
      final repository = FakeEvidenceRepository();
      await pumpEvidenceLocker(tester, repository: repository);

      await enterPin(tester, ' Secure@123 ');

      expect(repository.pinAttempts, [' Secure@123 ']);
      expect(find.byKey(EvidenceKeys.list), findsNothing);
    });

    // A PIN the server never saw is not a wrong PIN. Saying "Wrong PIN" here
    // sends an officer to the station in-charge over a dropped connection.
    testWidgets('an unreachable server says so instead of blaming the PIN', (
      tester,
    ) async {
      final repository = FakeEvidenceRepository()
        ..verifyFailure =
            const NetworkFailure(message: 'Cannot reach the NyayaAI server.');
      await pumpEvidenceLocker(tester, repository: repository);

      await enterPin(tester, lockerPin);

      expect(find.text('Cannot reach the NyayaAI server.'), findsOneWidget);
      expect(find.textContaining('Wrong PIN'), findsNothing);
      // Failing closed: no answer is not an answer of yes.
      expect(find.byKey(EvidenceKeys.list), findsNothing);
    });

    // The rejected-value clear below is for a PIN the server turned down.
    // Retyping one that never left the handset is work with no reason behind it.
    testWidgets('a PIN that could not be sent is left in the box', (
      tester,
    ) async {
      final repository = FakeEvidenceRepository()
        ..verifyFailure =
            const NetworkFailure(message: 'Cannot reach the NyayaAI server.');
      await pumpEvidenceLocker(tester, repository: repository);

      await enterPin(tester, lockerPin);

      final field = tester.widget<TextField>(
        find.descendant(
          of: find.byKey(EvidenceKeys.pinField),
          matching: find.byType(TextField),
        ),
      );
      expect(field.controller!.text, lockerPin);
    });

    // On a shared station handset, two failures in a row usually means the PIN
    // was changed and nobody said so.
    testWidgets('the second failure names the count', (tester) async {
      await pumpEvidenceLocker(tester, repository: FakeEvidenceRepository());

      await enterPin(tester, 'nope');
      await enterPin(tester, 'nope');

      expect(find.textContaining('2 failed attempts'), findsOneWidget);
    });

    testWidgets('the rejected value is cleared, not left to be deleted', (
      tester,
    ) async {
      await pumpEvidenceLocker(tester, repository: FakeEvidenceRepository());

      await enterPin(tester, 'nope');

      final field = tester.widget<TextField>(
        find.descendant(
          of: find.byKey(EvidenceKeys.pinField),
          matching: find.byType(TextField),
        ),
      );
      expect(field.controller!.text, isEmpty);
    });

    testWidgets('the right PIN opens the locker', (tester) async {
      await pumpEvidenceLocker(tester, repository: FakeEvidenceRepository());

      await unlockLocker(tester);

      expect(find.byKey(EvidenceKeys.pinField), findsNothing);
      expect(find.byKey(EvidenceKeys.list), findsOneWidget);
    });

    // Not trimmed, not case-folded. The server compares strictly, so quietly
    // fixing up a near-miss here would teach a value the website rejects.
    testWidgets('is compared exactly', (tester) async {
      await pumpEvidenceLocker(tester, repository: FakeEvidenceRepository());

      await enterPin(tester, 'SECURE@123');
      expect(find.byKey(EvidenceKeys.list), findsNothing);

      await enterPin(tester, ' secure@123 ');
      expect(find.byKey(EvidenceKeys.list), findsNothing);
    });
  });

  group('the list', () {
    testWidgets('groups the locker by FIR', (tester) async {
      await pumpEvidenceLocker(tester, repository: FakeEvidenceRepository());
      await unlockLocker(tester);

      // Labelled by FirNumber.label, which does not prefix a number that
      // already says FIR — the locker and the FIR history must write the same
      // record the same way.
      expect(find.text('FIR001'), findsOneWidget);
      expect(find.text('2 files'), findsOneWidget);
      expect(find.text('FIR002'), findsOneWidget);
      expect(find.text('1 file'), findsOneWidget);

      expect(find.text('scene.jpg'), findsOneWidget);
      expect(find.text('statement.pdf'), findsOneWidget);
      expect(find.text('cctv.mp4'), findsOneWidget);
    });

    testWidgets('search filters on the FIR number and on the file name', (
      tester,
    ) async {
      await pumpEvidenceLocker(tester, repository: FakeEvidenceRepository());
      await unlockLocker(tester);

      await tester.enterText(
        find.descendant(
          of: find.byKey(EvidenceKeys.search),
          matching: find.byType(TextField),
        ),
        'FIR002',
      );
      await tester.pumpAndSettle();

      expect(find.text('cctv.mp4'), findsOneWidget);
      expect(find.text('scene.jpg'), findsNothing);

      await tester.enterText(
        find.descendant(
          of: find.byKey(EvidenceKeys.search),
          matching: find.byType(TextField),
        ),
        'statement',
      );
      await tester.pumpAndSettle();

      expect(find.text('statement.pdf'), findsOneWidget);
      expect(find.text('cctv.mp4'), findsNothing);
    });

    // The website's console filters the locker by kind through a dropdown. The
    // app had search and nothing else, so an officer looking for the one video
    // in a locker of photographs had to know its filename.
    testWidgets('the chips narrow the locker to one kind of file', (
      tester,
    ) async {
      await pumpEvidenceLocker(tester, repository: FakeEvidenceRepository());
      await unlockLocker(tester);

      await tester.tap(find.byKey(EvidenceKeys.categoryChip('video')));
      await tester.pumpAndSettle();

      expect(find.text('cctv.mp4'), findsOneWidget);
      expect(find.text('scene.jpg'), findsNothing);
      expect(find.text('statement.pdf'), findsNothing);
    });

    testWidgets('tapping the chosen kind clears back to all', (tester) async {
      await pumpEvidenceLocker(tester, repository: FakeEvidenceRepository());
      await unlockLocker(tester);

      await tester.tap(find.byKey(EvidenceKeys.categoryChip('video')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(EvidenceKeys.categoryChip('video')));
      await tester.pumpAndSettle();

      expect(find.text('scene.jpg'), findsOneWidget);
      expect(find.text('cctv.mp4'), findsOneWidget);
    });

    testWidgets('the kind and the search box narrow together', (tester) async {
      await pumpEvidenceLocker(tester, repository: FakeEvidenceRepository());
      await unlockLocker(tester);

      await tester.tap(find.byKey(EvidenceKeys.categoryChip('image')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byKey(EvidenceKeys.search),
          matching: find.byType(TextField),
        ),
        'FIR002',
      );
      await tester.pumpAndSettle();

      // FIR002 holds only a video, so an image filter over it matches nothing.
      expect(find.text('scene.jpg'), findsNothing);
      expect(find.text('cctv.mp4'), findsNothing);
    });

    testWidgets('says so when nothing matches', (tester) async {
      await pumpEvidenceLocker(tester, repository: FakeEvidenceRepository());
      await unlockLocker(tester);

      await tester.enterText(
        find.descendant(
          of: find.byKey(EvidenceKeys.search),
          matching: find.byType(TextField),
        ),
        'zzz',
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Nothing matches'), findsOneWidget);
    });

    testWidgets('an empty locker explains itself', (tester) async {
      await pumpEvidenceLocker(
        tester,
        repository: FakeEvidenceRepository(items: []),
      );
      await unlockLocker(tester);

      expect(find.text('The locker is empty'), findsOneWidget);
    });

    testWidgets('a failed fetch shows the failure\'s own wording', (
      tester,
    ) async {
      final repository = FakeEvidenceRepository()
        ..listFailure = const NetworkFailure();
      await pumpEvidenceLocker(tester, repository: repository);
      await unlockLocker(tester);

      expect(find.text('The locker could not be loaded'), findsOneWidget);
      expect(
        find.text(
          'Cannot reach the NyayaAI server. Check your connection and try '
          'again.',
        ),
        findsOneWidget,
      );
    });
  });

  group('adding', () {
    testWidgets(
        'refuses an upload with nothing chosen, and names what is '
        'missing', (tester) async {
      final repository = FakeEvidenceRepository();
      await pumpEvidenceLocker(tester, repository: repository);
      await unlockLocker(tester);

      await tester.tap(find.byKey(EvidenceKeys.addButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(EvidenceKeys.addSubmit));
      await tester.pumpAndSettle();

      // FIR number and file.
      expect(find.text('Required'), findsNWidgets(2));
      expect(repository.uploads, isEmpty);
    });

    testWidgets('sends the chosen file against the typed FIR', (tester) async {
      final repository = FakeEvidenceRepository();
      final picker = FakeEvidenceFilePicker(result: photo);
      await pumpEvidenceLocker(
        tester,
        repository: repository,
        picker: picker,
      );
      await unlockLocker(tester);

      await tester.tap(find.byKey(EvidenceKeys.addButton));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.descendant(
          of: find.byKey(EvidenceKeys.addFirNo),
          matching: find.byType(TextField),
        ),
        'FIR001',
      );
      await tester.pump();

      await tester.tap(find.text('Attach a file'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(EvidenceSource.camera.label));
      await tester.pumpAndSettle();

      // The chosen file is described before it is sent.
      expect(find.text('scene.jpg'), findsOneWidget);
      expect(find.text('2.0 KB'), findsOneWidget);

      await tester.tap(find.byKey(EvidenceKeys.addSubmit));
      await tester.pumpAndSettle();

      expect(repository.uploads, hasLength(1));
      expect(repository.uploads.single.firNo, 'FIR001');
      expect(repository.uploads.single.file.name, 'scene.jpg');
      expect(picker.asked, [EvidenceSource.camera]);
    });

    testWidgets('returns to the list and confirms with the stored name', (
      tester,
    ) async {
      final repository = FakeEvidenceRepository();
      await pumpEvidenceLocker(
        tester,
        repository: repository,
        picker: FakeEvidenceFilePicker(result: photo),
      );
      await unlockLocker(tester);

      await tester.tap(find.byKey(EvidenceKeys.addButton));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byKey(EvidenceKeys.addFirNo),
          matching: find.byType(TextField),
        ),
        'FIR009',
      );
      await tester.tap(find.text('Attach a file'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(EvidenceSource.files.label));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(EvidenceKeys.addSubmit));
      await tester.pumpAndSettle();

      expect(find.byKey(EvidenceKeys.list), findsOneWidget);
      expect(
        find.text('scene.jpg filed against FIR009.'),
        findsOneWidget,
      );
    });

    testWidgets('the list picks up the new file without a manual refresh', (
      tester,
    ) async {
      final repository = FakeEvidenceRepository();
      await pumpEvidenceLocker(
        tester,
        repository: repository,
        picker: FakeEvidenceFilePicker(result: photo),
      );
      await unlockLocker(tester);
      expect(find.text('FIR FIR009'), findsNothing);

      await tester.tap(find.byKey(EvidenceKeys.addButton));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byKey(EvidenceKeys.addFirNo),
          matching: find.byType(TextField),
        ),
        'FIR009',
      );
      await tester.tap(find.text('Attach a file'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(EvidenceSource.gallery.label));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(EvidenceKeys.addSubmit));
      await tester.pumpAndSettle();

      expect(find.text('FIR009'), findsOneWidget);
    });

    // The server refuses an upload whose FIR does not exist, and its wording is
    // already written for a person.
    testWidgets('an unknown FIR keeps the officer on the form', (tester) async {
      final repository = FakeEvidenceRepository()
        ..uploadFailure = const ValidationFailure(
          'FIR number does not exist. Please enter a valid FIR.',
        );
      await pumpEvidenceLocker(
        tester,
        repository: repository,
        picker: FakeEvidenceFilePicker(result: photo),
      );
      await unlockLocker(tester);

      await tester.tap(find.byKey(EvidenceKeys.addButton));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byKey(EvidenceKeys.addFirNo),
          matching: find.byType(TextField),
        ),
        'NOPE',
      );
      await tester.tap(find.text('Attach a file'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(EvidenceSource.files.label));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(EvidenceKeys.addSubmit));
      await tester.pumpAndSettle();

      expect(
        find.text('FIR number does not exist. Please enter a valid FIR.'),
        findsOneWidget,
      );
      expect(find.byKey(EvidenceKeys.addSubmit), findsOneWidget);
    });

    testWidgets('one press uploads one file', (tester) async {
      final repository = FakeEvidenceRepository()
        ..delay = const Duration(milliseconds: 300);
      await pumpEvidenceLocker(
        tester,
        repository: repository,
        picker: FakeEvidenceFilePicker(result: photo),
      );
      await unlockLocker(tester);

      await tester.tap(find.byKey(EvidenceKeys.addButton));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byKey(EvidenceKeys.addFirNo),
          matching: find.byType(TextField),
        ),
        'FIR001',
      );
      await tester.tap(find.text('Attach a file'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(EvidenceSource.files.label));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(EvidenceKeys.addSubmit));
      await tester.pump();
      await tester.tap(find.byKey(EvidenceKeys.addSubmit), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(repository.uploads, hasLength(1));
    });

    // A dismissed chooser is not an error, and must not throw away a file that
    // was already picked.
    testWidgets('cancelling the chooser changes nothing', (tester) async {
      await pumpEvidenceLocker(
        tester,
        repository: FakeEvidenceRepository(),
        picker: FakeEvidenceFilePicker(),
      );
      await unlockLocker(tester);

      await tester.tap(find.byKey(EvidenceKeys.addButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Attach a file'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(EvidenceSource.camera.label));
      await tester.pumpAndSettle();

      expect(find.text('scene.jpg'), findsNothing);
      expect(find.textContaining('Could not open'), findsNothing);
    });

    // A denied camera permission is the officer's to fix in system settings, so
    // it has to be said out loud rather than logged.
    testWidgets('a refused chooser explains what to do', (tester) async {
      await pumpEvidenceLocker(
        tester,
        repository: FakeEvidenceRepository(),
        picker: FakeEvidenceFilePicker(error: Exception('permission denied')),
      );
      await unlockLocker(tester);

      await tester.tap(find.byKey(EvidenceKeys.addButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Attach a file'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(EvidenceSource.camera.label));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('allowed to use the camera and storage'),
        findsOneWidget,
      );
    });
  });

  /// The FIR number was typed only, until F9 gave the app a way to list records.
  /// Both paths exist now, and the tests below are mostly about the boundary
  /// between them: picking must not break typing, and typing must not require
  /// the picker to work.
  group('choosing the FIR from history', () {
    Future<void> openAddScreen(
      WidgetTester tester, {
      required FakeEvidenceRepository repository,
      required FakeFirRepository firRepository,
      FakeEvidenceFilePicker? picker,
    }) async {
      await pumpEvidenceLocker(
        tester,
        repository: repository,
        firRepository: firRepository,
        picker: picker,
      );
      await unlockLocker(tester);
      await tester.tap(find.byKey(EvidenceKeys.addButton));
      await tester.pumpAndSettle();
    }

    Future<void> openPicker(WidgetTester tester) async {
      await tester.tap(find.byKey(EvidenceKeys.addFirPicker));
      await tester.pumpAndSettle();
    }

    // An officer with the number in front of them — most of them — must not wait
    // for every FIR in the station to download before they can type it.
    testWidgets('the history is not fetched until the sheet is opened',
        (tester) async {
      final firRepository = FakeFirRepository()..records = [aFirRecord()];

      await openAddScreen(
        tester,
        repository: FakeEvidenceRepository(),
        firRepository: firRepository,
      );

      expect(firRepository.historyCalls, 0);

      await openPicker(tester);
      expect(firRepository.historyCalls, 1);
    });

    testWidgets('a chosen record fills the field and is what gets uploaded',
        (tester) async {
      final repository = FakeEvidenceRepository();
      final firRepository = FakeFirRepository()
        ..records = [
          aFirRecord(firNo: 'FIR001', complainantName: 'A. Sharma'),
          aFirRecord(firNo: 'FIR002', complainantName: 'R. Iyer'),
        ];

      await openAddScreen(
        tester,
        repository: repository,
        firRepository: firRepository,
        picker: FakeEvidenceFilePicker(result: photo),
      );

      await openPicker(tester);
      // Chosen by the complainant, which is the point of listing records rather
      // than numbers: it is what an officer remembers about a case.
      await tester.tap(find.text('R. Iyer · North Delhi PS'));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<TextField>(
              find.descendant(
                of: find.byKey(EvidenceKeys.addFirNo),
                matching: find.byType(TextField),
              ),
            )
            .controller
            ?.text,
        'FIR002',
      );

      await tester.tap(find.text('Attach a file'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(EvidenceSource.camera.label));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(EvidenceKeys.addSubmit));
      await tester.pumpAndSettle();

      // The controller and the visible field agreed, which is the failure this
      // is really guarding: a picked number that reached only one of them files
      // the evidence against whatever was typed before.
      expect(repository.uploads.single.firNo, 'FIR002');
    });

    // Dismissal is not a clear — the same contract showOptionPicker has.
    testWidgets('dismissing the sheet leaves a typed number alone',
        (tester) async {
      final firRepository = FakeFirRepository()..records = [aFirRecord()];

      await openAddScreen(
        tester,
        repository: FakeEvidenceRepository(),
        firRepository: firRepository,
      );

      await tester.enterText(
        find.descendant(
          of: find.byKey(EvidenceKeys.addFirNo),
          matching: find.byType(TextField),
        ),
        'FIR777',
      );
      await tester.pump();

      await openPicker(tester);
      // Back out of the sheet without choosing.
      await tester.tapAt(const Offset(200, 20));
      await tester.pumpAndSettle();

      expect(find.text('FIR777'), findsOneWidget);
    });

    // A picker that cannot load is a convenience that is unavailable, not a
    // blocked upload.
    testWidgets('a history that will not load still lets the number be typed',
        (tester) async {
      final repository = FakeEvidenceRepository();
      final firRepository = FakeFirRepository()
        ..historyFailure = const NetworkFailure(
          message: 'Cannot reach the NyayaAI server.',
        );

      await openAddScreen(
        tester,
        repository: repository,
        firRepository: firRepository,
        picker: FakeEvidenceFilePicker(result: photo),
      );

      await openPicker(tester);
      expect(find.text('Police records could not be loaded'), findsOneWidget);
      expect(
        find.textContaining('type the FIR number instead'),
        findsOneWidget,
      );

      await tester.tapAt(const Offset(200, 20));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.descendant(
          of: find.byKey(EvidenceKeys.addFirNo),
          matching: find.byType(TextField),
        ),
        'FIR001',
      );
      await tester.pump();
      await tester.tap(find.text('Attach a file'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(EvidenceSource.camera.label));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(EvidenceKeys.addSubmit));
      await tester.pumpAndSettle();

      expect(repository.uploads.single.firNo, 'FIR001');
    });

    testWidgets('an empty station explains itself rather than showing nothing',
        (tester) async {
      await openAddScreen(
        tester,
        repository: FakeEvidenceRepository(),
        firRepository: FakeFirRepository(),
      );

      await openPicker(tester);

      expect(find.text('No FIRs on record'), findsOneWidget);
    });
  });

  group('the detail', () {
    testWidgets('opens the file the row names, with its metadata', (
      tester,
    ) async {
      final repository = FakeEvidenceRepository(
        perFir: {
          'FIR001': const [
            EvidenceItem(
              firNo: 'FIR001',
              filename: 'statement.pdf',
              category: EvidenceCategory.pdf,
              uploadedAt: '2026-08-09 10:11:12.345678',
            ),
          ],
        },
      );
      await pumpEvidenceLocker(tester, repository: repository);
      await unlockLocker(tester);

      await tester.tap(find.text('statement.pdf'));
      await tester.pumpAndSettle();

      // "Filed against", labelled the same way the list and the FIR history
      // label it.
      expect(find.text('FIR001'), findsOneWidget);
      expect(find.text('PDF'), findsOneWidget);
      expect(find.text('2026-08-09 10:11:12.345678'), findsOneWidget);
    });

    testWidgets('says so when the timestamp is not known', (tester) async {
      final repository = FakeEvidenceRepository(
        perFir: {
          'FIR001': const [
            EvidenceItem(
              firNo: 'FIR001',
              filename: 'statement.pdf',
              category: EvidenceCategory.pdf,
            ),
          ],
        },
      );
      await pumpEvidenceLocker(tester, repository: repository);
      await unlockLocker(tester);

      await tester.tap(find.text('statement.pdf'));
      await tester.pumpAndSettle();

      expect(find.text('Not recorded'), findsOneWidget);
    });

    testWidgets('records that the file was looked at', (tester) async {
      final repository = FakeEvidenceRepository();
      await pumpEvidenceLocker(tester, repository: repository);
      await unlockLocker(tester);

      await tester.tap(find.text('statement.pdf'));
      await tester.pumpAndSettle();

      expect(repository.accessLog, hasLength(1));
      expect(repository.accessLog.single.firNo, 'FIR001');
      expect(repository.accessLog.single.filename, 'statement.pdf');
      expect(repository.accessLog.single.action, 'view');
    });

    // The server overwrites a file of the same name without saying so, so a link
    // built from one list and resolved against another can miss.
    testWidgets('a file that has gone says so rather than showing nothing', (
      tester,
    ) async {
      final repository = FakeEvidenceRepository(
        perFir: const {'FIR001': []},
      );
      await pumpEvidenceLocker(tester, repository: repository);
      await unlockLocker(tester);

      await tester.tap(find.text('statement.pdf'));
      await tester.pumpAndSettle();

      expect(
        find.text('This file is no longer in the locker'),
        findsOneWidget,
      );
    });
  });

  group('locking again', () {
    testWidgets('nothing survives being locked', (tester) async {
      await pumpEvidenceLocker(tester, repository: FakeEvidenceRepository());
      await unlockLocker(tester);
      expect(find.byKey(EvidenceKeys.list), findsOneWidget);

      // The dashboard's padlock calls this; the locker itself has no button, so
      // the controller is driven directly.
      final element = tester.element(find.byKey(EvidenceKeys.list));
      final container = ProviderScope.containerOf(element);
      container.read(evidenceLockControllerProvider.notifier).lock();
      await tester.pumpAndSettle();

      expect(find.byKey(EvidenceKeys.pinField), findsOneWidget);
      expect(find.byKey(EvidenceKeys.list), findsNothing);
    });
  });
}
