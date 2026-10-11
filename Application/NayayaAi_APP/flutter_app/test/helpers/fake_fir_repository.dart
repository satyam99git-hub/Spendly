import 'dart:io';

import 'package:nayaya_app/core/error/failure.dart';
import 'package:nayaya_app/features/fir/domain/entities/fir_draft.dart';
import 'package:nayaya_app/features/fir/domain/entities/fir_receipt.dart';
import 'package:nayaya_app/features/fir/domain/entities/fir_record.dart';
import 'package:nayaya_app/features/fir/domain/entities/section_suggestion.dart';
import 'package:nayaya_app/features/fir/domain/repositories/fir_repository.dart';

/// Scriptable [FirRepository] for widget and controller tests.
///
/// Hand-written rather than mocked, for the same reason as
/// `FakeAuthRepository`: four methods, and a fake that records what it was
/// handed reads better in a failing test than a mock's verification syntax.
///
/// [registered] is the part that matters. Most of what is worth asserting about
/// this feature is "did the right 27 values reach the server", and that is only
/// answerable by keeping the draft the repository was called with.
class FakeFirRepository implements FirRepository {
  FakeFirRepository({
    this.receipt,
    this.registerFailure,
    this.districtList = const ['Delhi', 'Maharashtra', 'Karnataka'],
    this.stationList = const ['North Delhi PS', 'South Delhi PS'],
    this.actList = const ['IPC', 'CRPC', 'NIA', 'IEA'],
  });

  /// Returned by [register] when [registerFailure] is null.
  FirReceipt? receipt;

  /// Thrown by [register] when set. Takes precedence over [receipt].
  Failure? registerFailure;

  List<String> districtList;
  List<String> stationList;
  List<String> actList;

  /// Set to make a lookup fail, so the field's typed-entry fallback can be
  /// exercised.
  Failure? lookupFailure;

  /// Artificial latency, so a test can observe the in-flight state.
  Duration delay = Duration.zero;

  // ---- call log -------------------------------------------------------------

  /// Every draft [register] was called with, in order. Length is the assertion
  /// that a double-tap did not file two FIRs.
  final List<FirDraft> registered = [];

  final List<String> stationLookups = [];

  /// Every `(firNo, savePath)` [downloadPdf] was asked for. The path is the
  /// half worth keeping: it is what proves the controller asked the store where
  /// to write before asking the server for bytes.
  final List<({String firNo, String savePath})> downloads = [];

  final List<String> recordLookups = [];

  // ---- the read side --------------------------------------------------------

  /// Returned by [history], in the order given. The repository under test sorts;
  /// this fake deliberately does not, so a test can hand it records out of order
  /// and assert on what the screen shows.
  List<FirRecord> records = const [];

  /// Thrown by [history] when set.
  Failure? historyFailure;

  /// How many times the collection has been asked for. The assertion that the
  /// evidence form does not download every FIR in the station before an officer
  /// can type four characters into it.
  int historyCalls = 0;

  /// Thrown by [record] when set. Otherwise [record] answers from [records], and
  /// a number that is not there fails the way the server does.
  Failure? recordFailure;

  /// Thrown by [downloadPdf] when set. Otherwise a placeholder file is written
  /// to the path it was given, so a test can assert the bytes landed somewhere.
  Failure? downloadFailure;

  /// Returned by [suggestSections]. Empty by default, so every test that does
  /// not care about suggestions gets the "nothing matched" branch rather than a
  /// surprise sheet full of sections.
  SectionSuggestions suggestions = const SectionSuggestions();

  /// Thrown by [suggestSections] when set — the 403 a non-police account gets
  /// is a real state the sheet has to render.
  Failure? suggestFailure;

  /// Every narrative [suggestSections] was asked about. Length is the assertion
  /// that reopening the sheet does not spend a second call for the same text.
  final List<String> suggestCalls = [];

  @override
  Future<SectionSuggestions> suggestSections(String narrative) async {
    suggestCalls.add(narrative);
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    final failure = suggestFailure;
    if (failure != null) throw failure;
    return suggestions;
  }

  @override
  Future<List<FirRecord>> history() async {
    historyCalls++;
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    final failure = historyFailure;
    if (failure != null) throw failure;
    return records;
  }

  @override
  Future<FirRecord> record(String firNo) async {
    recordLookups.add(firNo);
    if (delay > Duration.zero) await Future<void>.delayed(delay);

    final failure = recordFailure;
    if (failure != null) throw failure;

    for (final record in records) {
      if (record.firNo == firNo) return record;
    }
    // The server's own 404 wording, so a test of the "no such FIR" state is
    // asserting against the string an officer would really see.
    throw ValidationFailure('FIR record $firNo not found');
  }

  @override
  Future<void> downloadPdf({
    required String firNo,
    required String savePath,
  }) async {
    downloads.add((firNo: firNo, savePath: savePath));
    if (delay > Duration.zero) await Future<void>.delayed(delay);

    final failure = downloadFailure;
    if (failure != null) throw failure;

    // Synchronously, and that is not a style choice: a widget test runs in a
    // fake-async zone, so a real `dart:io` future never completes unless the
    // test wraps the pump in `runAsync`. An async write here hangs the download
    // controller mid-flight and the spinner never stops.
    File(savePath).writeAsStringSync('%PDF-1.4 fake');
  }

  @override
  Future<FirReceipt> register(FirDraft draft) async {
    registered.add(draft);
    if (delay > Duration.zero) await Future<void>.delayed(delay);

    final failure = registerFailure;
    if (failure != null) throw failure;

    return receipt ??
        FirReceipt(
          firNo: draft.firNo,
          firId: '17549023114567',
          actSections: draft.actSectionsWire,
          pdfFile: 'FIR_${draft.firNo}.pdf',
          createdAt: '2026-08-09 10:11:12.345678',
          status: 'Saved to Police Records',
          message: 'FIR has been successfully registered and saved to police '
              'records.',
        );
  }

  @override
  Future<List<String>> districts() async {
    final failure = lookupFailure;
    if (failure != null) throw failure;
    return districtList;
  }

  @override
  Future<List<String>> policeStations(String district) async {
    stationLookups.add(district);
    final failure = lookupFailure;
    if (failure != null) throw failure;
    return stationList;
  }

  @override
  Future<List<String>> acts() async {
    final failure = lookupFailure;
    if (failure != null) throw failure;
    return actList;
  }
}
