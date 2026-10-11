import 'dart:io';

import 'package:nayaya_app/features/fir/data/datasources/fir_pdf_store.dart';

/// A [FirPdfStore] that writes to a temp directory and never leaves the test.
///
/// The real one cannot be used here at all: `path_provider` and the intent that
/// opens a PDF are both platform channels, and neither answers under
/// `flutter test`. Overridden into `firPdfStoreProvider` the same way
/// `EvidenceFilePicker` is faked for the locker's tests.
///
/// [outcome] is the interesting knob. "Downloaded but nothing on the handset
/// can open it" is a real state with its own message, and it is unreachable in
/// a test any other way.
class FakeFirPdfStore implements FirPdfStore {
  FakeFirPdfStore({
    Directory? directory,
    this.outcome = FirPdfOpenOutcome.opened,
  }) : directory = directory ??
            Directory.systemTemp.createTempSync('nayaya_fir_pdf_test');

  final Directory directory;

  /// What [open] reports. Change it between calls to script the failure paths.
  FirPdfOpenOutcome outcome;

  /// Set to make choosing a path fail — a full disk, an unwritable directory.
  Object? pathFailure;

  /// Every path [pathFor] handed out, and every path [open] was called with.
  /// Their lengths are the assertion that a download that failed did not go on
  /// to open anything.
  final List<String> paths = [];
  final List<String> opens = [];

  @override
  Future<String> pathFor(String firNo) async {
    final failure = pathFailure;
    if (failure != null) throw failure;

    final path = '${directory.path}/FIR_$firNo.pdf';
    paths.add(path);
    return path;
  }

  @override
  Future<FirPdfOpenOutcome> open(String path) async {
    opens.add(path);
    return outcome;
  }

  /// Deletes the temp directory. Call from `addTearDown`.
  void dispose() {
    if (directory.existsSync()) directory.deleteSync(recursive: true);
  }
}
