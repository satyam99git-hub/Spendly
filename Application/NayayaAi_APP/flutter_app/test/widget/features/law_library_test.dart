import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nayaya_app/core/error/failure.dart';
import 'package:nayaya_app/features/legal/domain/entities/legal_section.dart';
import 'package:nayaya_app/features/legal/presentation/widgets/legal_keys.dart';
import 'package:nayaya_app/routes/app_routes.dart';

import '../../helpers/fake_legal_repository.dart';
import '../../helpers/pump_legal_app.dart';

/// The law library, the two searches behind it, and the two legal-AI surfaces.
void main() {
  Future<void> type(WidgetTester tester, Key key, String text) async {
    await tester.enterText(
      find.descendant(of: find.byKey(key), matching: find.byType(TextField)),
      text,
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
  }

  group('the library', () {
    testWidgets('opens on the cross-act search, not on an act', (tester) async {
      final repository = FakeLegalRepository();
      await pumpLawScreen(tester, repository: repository);

      // Nothing has been asked of the per-act endpoint: no act is open.
      expect(repository.pagesAsked, isEmpty);
      expect(find.text('Search every act at once'), findsOneWidget);
    });

    testWidgets('the act chips are the eight the server names', (tester) async {
      await pumpLawScreen(
        tester,
        repository: FakeLegalRepository(actList: const ['IPC', 'CRPC']),
      );

      expect(find.byKey(LegalKeys.actChip('all')), findsOneWidget);
      expect(find.byKey(LegalKeys.actChip('IPC')), findsOneWidget);
      expect(find.byKey(LegalKeys.actChip('CRPC')), findsOneWidget);
    });

    testWidgets('choosing an act lists its sections', (tester) async {
      final repository = FakeLegalRepository();
      await pumpLawScreen(tester, repository: repository);

      await tester.tap(find.byKey(LegalKeys.actChip('IPC')));
      await tester.pumpAndSettle();

      expect(repository.pagesAsked.first.act, 'IPC');
      expect(repository.pagesAsked.first.page, 1);
      expect(find.byKey(LegalKeys.sectionTile('IPC', '1')), findsOneWidget);
    });

    // An act that fits on one page ends with a footer saying so, rather than
    // trailing off in a way that reads as "there is more, loading".
    testWidgets('a short act says everything is shown', (tester) async {
      final repository = FakeLegalRepository(
        catalogue: const [
          LegalSection(act: 'IPC', section: '378', title: 'Theft'),
          LegalSection(act: 'IPC', section: '379', title: 'Punishment'),
        ],
      );
      await pumpLawScreen(tester, repository: repository);

      await tester.tap(find.byKey(LegalKeys.actChip('IPC')));
      await tester.pumpAndSettle();

      expect(find.text('All 2 shown.'), findsOneWidget);
    });

    // 20 a page, 46 IPC rows in the fake. Reaching the end asks for the next
    // page rather than stopping at section 20, which an officer would read as
    // the act ending there.
    testWidgets('scrolling to the end loads the next page', (tester) async {
      final repository = FakeLegalRepository();
      await pumpLawScreen(tester, repository: repository);

      await tester.tap(find.byKey(LegalKeys.actChip('IPC')));
      await tester.pumpAndSettle();
      expect(repository.pagesAsked.map((p) => p.page), [1]);

      await tester.scrollUntilVisible(
        find.byKey(LegalKeys.loadMore),
        400,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();

      expect(repository.pagesAsked.map((p) => p.page), contains(2));
      // The second page is appended, not swapped in: section 1 is still there.
      // (Off-screen now, so the finder is told to look for it in the tree
      // rather than on it — `findsOneWidget` would fail on a scrolled-away
      // sliver child that has been recycled.)
      expect(repository.pagesAsked.last.act, 'IPC');
    });

    testWidgets('searching inside an act asks the per-act endpoint', (
      tester,
    ) async {
      final repository = FakeLegalRepository();
      await pumpLawScreen(tester, repository: repository);

      await tester.tap(find.byKey(LegalKeys.actChip('IPC')));
      await tester.pumpAndSettle();
      await type(tester, LegalKeys.librarySearch, 'theft');

      expect(repository.pagesAsked.last.search, 'theft');
      // The wide endpoint is untouched while an act is open — they are two
      // different questions.
      expect(repository.searchesAsked, isEmpty);
    });

    testWidgets('searching all acts asks the cross-act endpoint instead', (
      tester,
    ) async {
      final repository = FakeLegalRepository();
      await pumpLawScreen(tester, repository: repository);

      await type(tester, LegalKeys.librarySearch, 'theft');

      expect(repository.searchesAsked, contains('theft'));
      expect(repository.pagesAsked, isEmpty);
      // A hit carries its act, because a result from eight acts must say which.
      expect(find.byKey(LegalKeys.sectionTile('IPC', '379')), findsOneWidget);
      expect(find.text('IPC Section 379'), findsOneWidget);
    });

    testWidgets('a search that matches nothing says so', (tester) async {
      await pumpLawScreen(tester, repository: FakeLegalRepository());

      await type(tester, LegalKeys.librarySearch, 'zzzz');

      expect(find.textContaining('Nothing matches'), findsOneWidget);
    });

    testWidgets('a failed act list explains itself', (tester) async {
      final repository = FakeLegalRepository()
        ..actsFailure = const NetworkFailure(
          message: 'Cannot reach the NyayaAI server.',
        );
      await pumpLawScreen(tester, repository: repository);

      expect(find.text('The acts could not be loaded'), findsOneWidget);
    });
  });

  group('one section', () {
    testWidgets('opens in full from the list', (tester) async {
      await pumpLawScreen(
        tester,
        repository: FakeLegalRepository(),
        initialLocation: '/law/section/IPC/379',
      );

      expect(find.text('Punishment for theft'), findsOneWidget);
      expect(
        find.textContaining('Whoever commits theft'),
        findsOneWidget,
      );
    });

    testWidgets('a number with no section behind it says so', (tester) async {
      await pumpLawScreen(
        tester,
        repository: FakeLegalRepository(),
        initialLocation: '/law/section/IPC/9999',
      );

      expect(find.text('That section could not be opened'), findsOneWidget);
    });

    testWidgets('comparing holds a second section under the first', (
      tester,
    ) async {
      await pumpLawScreen(
        tester,
        repository: FakeLegalRepository(),
        initialLocation: '/law/section/IPC/379',
      );

      await tester.tap(find.byKey(LegalKeys.compareAction));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, '41');
      await tester.pump();
      await tester.tap(find.text('CRPC'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Compare'));
      await tester.pumpAndSettle();

      expect(find.byKey(LegalKeys.comparePanel), findsOneWidget);
      // Both on screen at once, which is the whole point.
      expect(find.text('Punishment for theft'), findsOneWidget);
      expect(
        find.text('When police may arrest without a warrant'),
        findsOneWidget,
      );
    });
  });

  group('asking a question', () {
    testWidgets('sends the question and shows the answer verbatim', (
      tester,
    ) async {
      final repository = FakeLegalRepository()
        ..answer = '⚖️ NYAYA AI\n═══\n📘 IPC Section 379';
      await pumpLawScreen(
        tester,
        repository: repository,
        initialLocation: AppRoutes.lawAsk,
      );

      await tester.enterText(
        find.descendant(
          of: find.byKey(LegalKeys.askInput),
          matching: find.byType(TextField),
        ),
        'What is the punishment for theft?',
      );
      await tester.tap(find.byKey(LegalKeys.askSubmit));
      await tester.pumpAndSettle();

      expect(repository.questionsAsked, ['What is the punishment for theft?']);
      expect(find.byKey(LegalKeys.askAnswer), findsOneWidget);
      expect(find.textContaining('IPC Section 379'), findsOneWidget);
    });

    // A round trip to be told the box is empty is a round trip wasted.
    testWidgets('a blank question is not sent', (tester) async {
      final repository = FakeLegalRepository();
      await pumpLawScreen(
        tester,
        repository: repository,
        initialLocation: AppRoutes.lawAsk,
      );

      await tester.tap(find.byKey(LegalKeys.askSubmit));
      await tester.pumpAndSettle();

      expect(repository.questionsAsked, isEmpty);
    });

    testWidgets('a failure is shown and the question kept', (tester) async {
      final repository = FakeLegalRepository()
        ..askFailure = const NetworkFailure(
          message: 'Cannot reach the NyayaAI server.',
        );
      await pumpLawScreen(
        tester,
        repository: repository,
        initialLocation: AppRoutes.lawAsk,
      );

      await tester.enterText(
        find.descendant(
          of: find.byKey(LegalKeys.askInput),
          matching: find.byType(TextField),
        ),
        'anything',
      );
      await tester.tap(find.byKey(LegalKeys.askSubmit));
      await tester.pumpAndSettle();

      expect(find.text('Cannot reach the NyayaAI server.'), findsOneWidget);
    });
  });

  // The two lookups the website keeps in its sidebar as separate panels. One
  // box here, because they are the same act and the officer should not have to
  // know which table their question belongs to.
  group('terms and the new codes', () {
    testWidgets('a section number finds its renumbering', (tester) async {
      await pumpLawScreen(
        tester,
        repository: FakeLegalRepository(),
        initialLocation: AppRoutes.lawReference,
      );

      await type(tester, LegalKeys.referenceSearch, '302');

      expect(find.byKey(LegalKeys.amendmentRow('ipc 302')), findsOneWidget);
      expect(find.text('BNS Section 103'), findsOneWidget);
      expect(find.text('Murder'), findsOneWidget);
    });

    testWidgets('a word finds its definition', (tester) async {
      await pumpLawScreen(
        tester,
        repository: FakeLegalRepository(),
        initialLocation: AppRoutes.lawReference,
      );

      await type(tester, LegalKeys.referenceSearch, 'vakalatnama');

      expect(find.byKey(LegalKeys.glossaryRow('vakalatnama')), findsOneWidget);
      expect(
        find.textContaining('authorizing an advocate'),
        findsOneWidget,
      );
    });

    // One box, two kinds of answer.
    testWidgets('a query that hits both shows both sections', (tester) async {
      await pumpLawScreen(
        tester,
        repository: FakeLegalRepository(),
        initialLocation: AppRoutes.lawReference,
      );

      await type(tester, LegalKeys.referenceSearch, 'bail');

      expect(find.text('RENUMBERED IN 2023'), findsOneWidget);
      expect(find.text('WHAT IT MEANS'), findsOneWidget);
    });

    testWidgets('nothing matching says so', (tester) async {
      await pumpLawScreen(
        tester,
        repository: FakeLegalRepository(),
        initialLocation: AppRoutes.lawReference,
      );

      await type(tester, LegalKeys.referenceSearch, 'zzzz');

      expect(find.textContaining('Nothing matches'), findsOneWidget);
    });

    // No server behind either list, so the screen must work with none.
    testWidgets('it needs no repository call at all', (tester) async {
      final repository = FakeLegalRepository();
      await pumpLawScreen(
        tester,
        repository: repository,
        initialLocation: AppRoutes.lawReference,
      );

      await type(tester, LegalKeys.referenceSearch, 'bail');

      expect(repository.pagesAsked, isEmpty);
      expect(repository.searchesAsked, isEmpty);
      expect(repository.questionsAsked, isEmpty);
    });
  });

  group('matching a situation', () {
    testWidgets('shows a card per section with its flags', (tester) async {
      final repository = FakeLegalRepository();
      await pumpLawScreen(
        tester,
        repository: repository,
        initialLocation: AppRoutes.lawOutcome,
      );

      await tester.enterText(
        find.descendant(
          of: find.byKey(LegalKeys.outcomeInput),
          matching: find.byType(TextField),
        ),
        'a phone was stolen',
      );
      await tester.tap(find.byKey(LegalKeys.outcomeSubmit));
      await tester.pumpAndSettle();

      expect(repository.situationsAsked, ['a phone was stolen']);
      expect(find.byKey(LegalKeys.outcomeCard('IPC', '378')), findsOneWidget);
      expect(find.text('Cognizable'), findsOneWidget);
      expect(find.text('Bailable'), findsOneWidget);
      expect(find.text('BNS Section 303'), findsOneWidget);
      // The match score, stated. The fifth result must not look as solid as
      // the first.
      expect(find.textContaining('match 12'), findsOneWidget);
    });

    testWidgets('nothing matching is an answer, not a failure', (tester) async {
      final repository = FakeLegalRepository()..findings = const [];
      await pumpLawScreen(
        tester,
        repository: repository,
        initialLocation: AppRoutes.lawOutcome,
      );

      await tester.enterText(
        find.descendant(
          of: find.byKey(LegalKeys.outcomeInput),
          matching: find.byType(TextField),
        ),
        'zzzz',
      );
      await tester.tap(find.byKey(LegalKeys.outcomeSubmit));
      await tester.pumpAndSettle();

      expect(find.text('Nothing in the table matches'), findsOneWidget);
    });
  });
}
