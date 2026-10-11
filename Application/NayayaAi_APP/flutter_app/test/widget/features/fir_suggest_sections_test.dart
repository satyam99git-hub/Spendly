import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nayaya_app/core/error/failure.dart';
import 'package:nayaya_app/features/fir/domain/entities/fir_draft.dart';
import 'package:nayaya_app/features/fir/domain/entities/section_suggestion.dart';
import 'package:nayaya_app/features/fir/presentation/widgets/fir_field_keys.dart';

import '../../helpers/fake_fir_repository.dart';
import '../../helpers/pump_fir_app.dart';

/// A narrative long enough that the button unlocks — the form waits for the
/// same 20 characters the server does.
const _narrative =
    'Two men on a motorcycle snatched a gold chain and pushed my mother down.';

SectionSuggestions _answer({
  SuggestionSource source = SuggestionSource.groq,
  String note = '',
}) =>
    SectionSuggestions(
      source: source,
      note: note,
      suggestions: const [
        SectionSuggestion(
          act: 'IPC',
          section: '390',
          title: 'Robbery',
          reason: 'Chain snatched with force',
          confidence: SuggestionConfidence.high,
        ),
        SectionSuggestion(
          act: 'IPC',
          section: '323',
          title: 'Punishment for voluntarily causing hurt',
          reason: 'The complainant was pushed down',
          confidence: SuggestionConfidence.medium,
        ),
      ],
    );

/// Walks to step 4, types a narrative, and opens the suggestion sheet.
Future<void> _openSheet(WidgetTester tester, {String text = _narrative}) async {
  await goToComplaintStep(tester);
  await enterFir(tester, FirFieldKeys.statement, text);
  await tester.tap(find.byKey(FirFieldKeys.suggestOpen));
  await tester.pumpAndSettle();
}

void main() {
  group('suggesting sections', () {
    testWidgets('the button waits for a narrative worth reading',
        (tester) async {
      final repository = FakeFirRepository();
      await pumpFirForm(tester, repository: repository);
      await goToComplaintStep(tester);

      expect(
        tester
            .widget<OutlinedButton>(find.byKey(FirFieldKeys.suggestOpen))
            .onPressed,
        isNull,
        reason: 'nothing has been written to read yet',
      );

      await enterFir(tester, FirFieldKeys.statement, 'stolen');
      await tester.pump();
      expect(
        tester
            .widget<OutlinedButton>(find.byKey(FirFieldKeys.suggestOpen))
            .onPressed,
        isNull,
        reason: 'six characters is not a narrative',
      );

      await enterFir(tester, FirFieldKeys.statement, _narrative);
      await tester.pump();
      expect(
        tester
            .widget<OutlinedButton>(find.byKey(FirFieldKeys.suggestOpen))
            .onPressed,
        isNotNull,
      );

      // Not asked until it is opened. A form that queried the model on every
      // keystroke would spend the station's quota on a half-typed sentence.
      expect(repository.suggestCalls, isEmpty);
    });

    testWidgets('shows each section with its reason and confidence',
        (tester) async {
      final repository = FakeFirRepository()..suggestions = _answer();
      await pumpFirForm(tester, repository: repository);
      await _openSheet(tester);

      expect(repository.suggestCalls, [_narrative]);

      expect(find.text('IPC Section 390'), findsOneWidget);
      expect(find.text('Robbery'), findsOneWidget);
      expect(find.text('Chain snatched with force'), findsOneWidget);
      expect(find.text('High'), findsOneWidget);

      expect(find.text('IPC Section 323'), findsOneWidget);
      expect(find.text('Medium'), findsOneWidget);

      // The caveat is above the list, where it is read before the decision.
      expect(find.textContaining('Suggestions, not charges'), findsOneWidget);
    });

    testWidgets('nothing is added until Add is tapped', (tester) async {
      final repository = FakeFirRepository()..suggestions = _answer();
      await pumpFirForm(tester, repository: repository);
      await _openSheet(tester);

      // No selection, so no way to commit one.
      expect(find.byKey(FirFieldKeys.suggestAdd), findsNothing);

      await tester.tap(find.byKey(FirFieldKeys.suggestion('IPC', '390')));
      await tester.pumpAndSettle();
      expect(find.text('Add 1 section'), findsOneWidget);

      await tester.tap(find.byKey(FirFieldKeys.suggestion('IPC', '323')));
      await tester.pumpAndSettle();
      expect(find.text('Add 2 sections'), findsOneWidget);
    });

    testWidgets('accepted sections become chips on step 1', (tester) async {
      final repository = FakeFirRepository()..suggestions = _answer();
      await pumpFirForm(tester, repository: repository);
      await _openSheet(tester);

      await tester.tap(find.byKey(FirFieldKeys.suggestion('IPC', '390')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(FirFieldKeys.suggestAdd));
      await tester.pumpAndSettle();

      // Back to where the sections live.
      await firBack(tester);
      await firBack(tester);
      await firBack(tester);
      expect(firStep(FirFormStep.registration), findsOneWidget);
      expect(find.text('IPC Section 390'), findsOneWidget);
      expect(
        find.text('IPC Section 323'),
        findsNothing,
        reason: 'it was never selected',
      );
    });

    testWidgets('a section already on the FIR is shown, not offered again',
        (tester) async {
      final repository = FakeFirRepository()..suggestions = _answer();
      await pumpFirForm(tester, repository: repository);

      await enterFir(tester, FirFieldKeys.firNo, 'FIR001');
      await chooseOption(tester, FirFieldKeys.district, 'Delhi');
      await chooseOption(tester, FirFieldKeys.policeStation, 'North Delhi PS');
      await addSection(tester, act: 'IPC', section: '390');
      await firNext(tester);
      await firNext(tester);
      await enterFir(tester, FirFieldKeys.complainantName, 'A. Sharma');
      await firNext(tester);

      await enterFir(tester, FirFieldKeys.statement, _narrative);
      await tester.tap(find.byKey(FirFieldKeys.suggestOpen));
      await tester.pumpAndSettle();

      expect(find.text('Already on this FIR'), findsOneWidget);

      // Tapping it does nothing, so it cannot be double-added.
      await tester.tap(find.byKey(FirFieldKeys.suggestion('IPC', '390')));
      await tester.pumpAndSettle();
      expect(find.byKey(FirFieldKeys.suggestAdd), findsNothing);
    });

    testWidgets('says so when the keyword matcher answered instead',
        (tester) async {
      final repository = FakeFirRepository()
        ..suggestions = _answer(source: SuggestionSource.keyword);
      await pumpFirForm(tester, repository: repository);
      await _openSheet(tester);

      expect(
        find.textContaining('The assistant was unreachable'),
        findsOneWidget,
      );
    });

    testWidgets('shows the server note without making it selectable',
        (tester) async {
      final repository = FakeFirRepository()
        ..suggestions = _answer(note: 'This may also attract the IT Act.');
      await pumpFirForm(tester, repository: repository);
      await _openSheet(tester);

      expect(find.text('This may also attract the IT Act.'), findsOneWidget);
      // It is prose, not a section: nothing verified it, so it must not sit in
      // the list looking as solid as the rows that were.
      expect(find.byKey(FirFieldKeys.suggestion('IT Act', '67')), findsNothing);
    });

    testWidgets('an empty answer is a sentence, not a dead end',
        (tester) async {
      final repository = FakeFirRepository()
        ..suggestions = const SectionSuggestions(source: SuggestionSource.none);
      await pumpFirForm(tester, repository: repository);
      await _openSheet(tester);

      expect(find.text('No sections matched'), findsOneWidget);
      expect(find.byKey(FirFieldKeys.suggestAdd), findsNothing);
    });

    testWidgets('a refusal is shown, and says filing is not blocked',
        (tester) async {
      final repository = FakeFirRepository()
        ..suggestFailure = const ValidationFailure('Police login required.');
      await pumpFirForm(tester, repository: repository);
      await _openSheet(tester);

      expect(find.text('Police login required.'), findsOneWidget);
      expect(find.textContaining('Filing is not blocked'), findsOneWidget);
    });
  });
}
