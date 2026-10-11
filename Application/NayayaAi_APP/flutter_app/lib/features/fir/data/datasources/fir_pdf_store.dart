import 'dart:io';

import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

/// What happened when the handset was asked to open a downloaded PDF.
///
/// Three outcomes rather than a bool, because the middle one is not a failure
/// and must not be reported as one: the file downloaded correctly and is sitting
/// on the device — there is simply nothing installed that reads PDFs. Telling an
/// officer "the download failed" in that case sends them to try again at a
/// station with a flaky connection, when what they need is a viewer.
enum FirPdfOpenOutcome { opened, noViewer, failed }

/// Where a downloaded FIR PDF goes, and how it is handed to the handset.
///
/// An interface with one real implementation, for the same reason as
/// `EvidenceFilePicker`: both sides of this need a platform channel — the
/// documents directory comes from `path_provider`, opening goes out through an
/// Android intent — and a widget test cannot have either. Tests override
/// `firPdfStoreProvider` with a fake that answers from a temp directory.
abstract interface class FirPdfStore {
  /// The absolute path this FIR's PDF should be written to. Creates the
  /// directory if it is not there yet.
  Future<String> pathFor(String firNo);

  /// Hands [path] to whatever the handset uses for PDFs.
  Future<FirPdfOpenOutcome> open(String path);
}

class PlatformFirPdfStore implements FirPdfStore {
  const PlatformFirPdfStore();

  /// Under the app's documents directory, beside `.cookies`.
  ///
  /// **Not the device's Downloads folder, and that is a decision.** Writing
  /// there needs `MediaStore` on Android 10+ or a storage permission below it,
  /// and the permission prompt an officer would see says "allow NyayaAI to
  /// access photos and files on your device" — a large thing to ask for a copy
  /// of a record they can already read on screen. App-private storage needs no
  /// permission at all, is wiped when the app is uninstalled, and is reachable
  /// by every PDF viewer through the intent below.
  ///
  /// The trade is real and worth stating: the file is *not* browsable in a file
  /// manager afterwards. Opening it again means opening it from here.
  static const _folder = 'fir_pdfs';

  @override
  Future<String> pathFor(String firNo) async {
    final documents = await getApplicationDocumentsDirectory();
    final dir = Directory('${documents.path}/$_folder');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return '${dir.path}/${_filename(firNo)}';
  }

  /// `FIR_<no>.pdf`, matching what the server named it — so an officer who
  /// shares the file from the viewer sends something a colleague recognises.
  ///
  /// Every character that is not a letter, a digit, a dash or a dot is replaced.
  /// FIR numbers in the field are written `41/2026`, and a slash in a filename is
  /// a directory that does not exist: unsanitised, the download would fail on
  /// exactly the numbering scheme most stations use.
  static String _filename(String firNo) {
    final safe = firNo
        .trim()
        .replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_');
    return 'FIR_${safe.isEmpty ? 'record' : safe}.pdf';
  }

  @override
  Future<FirPdfOpenOutcome> open(String path) async {
    try {
      final result = await OpenFilex.open(path);
      return switch (result.type) {
        ResultType.done => FirPdfOpenOutcome.opened,
        ResultType.noAppToOpen => FirPdfOpenOutcome.noViewer,
        _ => FirPdfOpenOutcome.failed,
      };
    } catch (_) {
      // A missing FileProvider or a device with no intent handler throws rather
      // than answering. The file is still downloaded, so the caller says where
      // it is instead of claiming the download failed.
      return FirPdfOpenOutcome.failed;
    }
  }
}
