import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/error_mapper.dart';
import '../../../../core/error/failure.dart';
import '../../data/datasources/fir_pdf_store.dart';
import 'fir_providers.dart';

/// What the viewer's Download button is doing.
enum FirDownloadStatus { idle, downloading, finished }

class FirDownloadState {
  const FirDownloadState({
    this.status = FirDownloadStatus.idle,
    this.path,
    this.outcome,
    this.failure,
  });

  final FirDownloadStatus status;

  /// Where the PDF was written, once it has been. Read by [notice], which names
  /// the file when nothing on the handset could open it — "saved" with no name
  /// is a claim the officer cannot check.
  final String? path;

  /// Null until the handset has been asked to open the file.
  final FirPdfOpenOutcome? outcome;

  final Failure? failure;

  bool get isDownloading => status == FirDownloadStatus.downloading;

  /// The one line worth putting in front of the officer, or null when there is
  /// nothing to say.
  ///
  /// Silence is the right answer for the common case. When the PDF opens, the
  /// viewer is already on screen and a message behind it is either invisible or
  /// stale by the time they come back. Every other outcome needs words, because
  /// each one leaves the officer with a different next move.
  String? get notice {
    final error = failure;
    if (error != null) return error.message;

    return switch (outcome) {
      FirPdfOpenOutcome.opened => null,
      FirPdfOpenOutcome.noViewer =>
        'Saved as $_filename, but this handset has no app that opens PDFs.',
      FirPdfOpenOutcome.failed =>
        'Saved as $_filename, but it could not be opened here.',
      null => null,
    };
  }

  /// The name the file was saved under, for the messages above. Not the whole
  /// path: an app-private directory is forty characters of nothing an officer
  /// can act on, while the filename is what they will look for.
  String get _filename {
    final saved = path;
    if (saved == null) return 'a PDF';
    return saved.split('/').last;
  }
}

/// Fetching one FIR's generated PDF and handing it to the handset.
///
/// `.family` on the FIR number, so two viewers opened in a row do not share a
/// spinner, and `autoDispose` so leaving the record clears the outcome — a
/// notice about a download that happened before is not about the screen it would
/// reappear on.
final firDownloadControllerProvider = NotifierProvider.autoDispose
    .family<FirDownloadController, FirDownloadState, String>(
  FirDownloadController.new,
);

class FirDownloadController
    extends AutoDisposeFamilyNotifier<FirDownloadState, String> {
  /// Whether the viewer this controller belongs to has gone.
  ///
  /// A download is the one thing here that outlives its screen: nothing stops an
  /// officer pressing back while it runs, and nothing should — a record they no
  /// longer want to look at must not trap them. This provider is `autoDispose`,
  /// so the pop tears the notifier down with the fetch still in flight, and what
  /// comes back has nowhere to go.
  ///
  /// Riverpod 2.6 tolerates the late assignment rather than throwing — the
  /// widget test that backs out mid-download passes either way, and it is kept
  /// as a regression guard on the behaviour, not on this flag. The flag is here
  /// because writing to a disposed notifier is a thing to stop doing on purpose:
  /// it is unspecified, Riverpod 3 makes it an error, and the state it writes is
  /// read by nobody.
  bool _gone = false;

  @override
  FirDownloadState build(String arg) {
    _gone = false;
    ref.onDispose(() => _gone = true);
    return const FirDownloadState();
  }

  /// Downloads the PDF, then opens it.
  ///
  /// Three steps that fail differently, which is why they are three: choosing a
  /// path can fail on a full device, the fetch can fail at the server, and the
  /// open can fail because nothing on the handset reads PDFs. Only the first two
  /// are errors — see [FirDownloadState.notice].
  ///
  /// Re-entrant taps are dropped rather than queued. The button is a spinner
  /// while this runs, but a fast double-tap arrives before the first frame of
  /// it, and two downloads writing the same path is a corrupt file.
  Future<void> download() async {
    if (state.isDownloading) return;

    state = const FirDownloadState(status: FirDownloadStatus.downloading);

    final store = ref.read(firPdfStoreProvider);

    try {
      final path = await store.pathFor(arg);
      await ref.read(firRepositoryProvider).downloadPdf(
            firNo: arg,
            savePath: path,
          );

      // Deliberately after the file is on disk and deliberately awaited: the
      // outcome is what the notice above is built from. Opening is the last
      // thing that can go wrong and the only one that is not a failed download.
      final outcome = await store.open(path);
      if (_gone) return;

      state = FirDownloadState(
        status: FirDownloadStatus.finished,
        path: path,
        outcome: outcome,
      );
    } catch (error) {
      if (_gone) return;
      state = FirDownloadState(
        status: FirDownloadStatus.finished,
        failure: ErrorMapper.map(error, context: 'fir/download'),
      );
    }
  }

  /// Drops the notice once its screen has shown it, so a rebuild does not put
  /// the same snackbar up twice.
  void clearNotice() {
    if (state.notice == null) return;
    state = FirDownloadState(
      status: state.status,
      path: state.path,
      outcome: state.outcome == FirPdfOpenOutcome.opened ? state.outcome : null,
    );
  }
}
