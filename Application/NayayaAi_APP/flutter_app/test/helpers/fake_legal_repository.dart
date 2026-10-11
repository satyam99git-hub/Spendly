import 'package:nayaya_app/core/error/failure.dart';
import 'package:nayaya_app/features/legal/domain/entities/legal_section.dart';
import 'package:nayaya_app/features/legal/domain/entities/outcome_finding.dart';
import 'package:nayaya_app/features/legal/domain/repositories/legal_repository.dart';

/// Scriptable [LegalRepository].
///
/// Hand-written rather than mocked, like the others here. It pages for real —
/// [sections] slices its own list — because the library's whole behaviour is
/// paging, and a fake that returned everything on page one would let a broken
/// `loadMore` pass.
class FakeLegalRepository implements LegalRepository {
  FakeLegalRepository({
    this.actList = const ['IPC', 'CRPC', 'NIA', 'IEA'],
    List<LegalSection>? catalogue,
  }) : catalogue = catalogue ?? _defaultCatalogue();

  List<String> actList;

  /// Every section the fake server holds, across every act.
  List<LegalSection> catalogue;

  Failure? actsFailure;
  Failure? sectionsFailure;
  Failure? searchFailure;
  Failure? askFailure;
  Failure? outcomeFailure;

  /// What [ask] returns.
  String answer = 'IPC Section 379 — Punishment for theft.';

  /// What [predictOutcome] returns.
  List<OutcomeFinding> findings = const [
    OutcomeFinding(
      act: 'IPC',
      section: '378',
      title: 'Theft',
      punishment: 'Imprisonment up to 3 years',
      cognizable: 'Yes',
      bailable: 'Yes',
      bnsEquivalent: 'BNS Section 303',
      score: 12,
    ),
  ];

  /// Artificial latency, so a test can observe an in-flight state.
  Duration delay = Duration.zero;

  // ---- call log -------------------------------------------------------------

  final List<({String act, String search, int page})> pagesAsked = [];
  final List<String> searchesAsked = [];
  final List<String> questionsAsked = [];
  final List<String> situationsAsked = [];

  static List<LegalSection> _defaultCatalogue() => [
        for (var i = 1; i <= 45; i++)
          LegalSection(
            act: 'IPC',
            section: '$i',
            title: i == 379 ? 'Punishment for theft' : 'IPC section $i',
            description: 'The text of IPC section $i.',
          ),
        const LegalSection(
          act: 'IPC',
          section: '379',
          title: 'Punishment for theft',
          description: 'Whoever commits theft shall be punished…',
        ),
        const LegalSection(
          act: 'CRPC',
          section: '41',
          title: 'When police may arrest without a warrant',
          description: 'Any police officer may without an order…',
        ),
      ];

  Future<void> _wait() async {
    if (delay > Duration.zero) await Future<void>.delayed(delay);
  }

  @override
  Future<List<String>> acts() async {
    await _wait();
    if (actsFailure != null) throw actsFailure!;
    return actList;
  }

  @override
  Future<LegalSectionPage> sections(
    String act, {
    String search = '',
    int page = 1,
    int limit = 20,
  }) async {
    pagesAsked.add((act: act, search: search, page: page));
    await _wait();
    if (sectionsFailure != null) throw sectionsFailure!;

    final needle = search.trim().toLowerCase();
    final matching = catalogue
        .where((s) => s.act == act)
        .where(
          (s) =>
              needle.isEmpty ||
              s.section.toLowerCase().contains(needle) ||
              s.title.toLowerCase().contains(needle) ||
              s.description.toLowerCase().contains(needle),
        )
        .toList();

    final start = (page - 1) * limit;
    final slice = start >= matching.length
        ? <LegalSection>[]
        : matching.sublist(start, (start + limit).clamp(0, matching.length));

    return LegalSectionPage(
      act: act,
      sections: slice,
      page: page,
      pages: matching.isEmpty ? 1 : ((matching.length + limit - 1) ~/ limit),
      total: matching.length,
    );
  }

  @override
  Future<LegalSection> section(String act, String sectionNo) async {
    await _wait();
    if (sectionsFailure != null) throw sectionsFailure!;
    return catalogue.firstWhere(
      (s) => s.act == act && s.section == sectionNo,
      orElse: () => throw const ValidationFailure('Section not found'),
    );
  }

  @override
  Future<List<LegalSection>> search(String query) async {
    searchesAsked.add(query);
    await _wait();
    if (searchFailure != null) throw searchFailure!;

    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return const [];
    return catalogue
        .where(
          (s) =>
              s.title.toLowerCase().contains(needle) ||
              s.section.toLowerCase().contains(needle),
        )
        // A real hit carries no description — see LegalSection.isSummary.
        .map(
          (s) => LegalSection(act: s.act, section: s.section, title: s.title),
        )
        .toList();
  }

  @override
  Future<String> ask(String question) async {
    questionsAsked.add(question);
    await _wait();
    if (askFailure != null) throw askFailure!;
    return answer;
  }

  @override
  Future<List<OutcomeFinding>> predictOutcome(String situation) async {
    situationsAsked.add(situation);
    await _wait();
    if (outcomeFailure != null) throw outcomeFailure!;
    return findings;
  }
}
