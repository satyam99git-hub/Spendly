import '../../../../core/utils/fir_pdf.dart';

/// What the server hands back once an FIR is on record.
///
/// A deliberately small slice of the response. `POST /generate_fir` echoes the
/// whole stored document — all 27 entries plus its own metadata — but the app
/// already holds every entry it just sent, and re-reading them from the reply
/// would create a second copy that could drift from the draft on screen. Only
/// the four things the client could *not* know are kept: the ID the server
/// minted, the sections it filed, the PDF it wrote, and when.
class FirReceipt {
  const FirReceipt({
    required this.firNo,
    required this.firId,
    this.actSections = '',
    this.pdfFile = '',
    this.pdfUrl = '',
    this.createdAt = '',
    this.status = '',
    this.message = '',
  });

  /// The station's FIR number, echoed back. This is what the officer quotes,
  /// what evidence is filed against (F10) and what the PDF is named after.
  final String firNo;

  /// The server's own identifier — a UTC timestamp with the dot stripped. Not
  /// shown as a headline; kept because it is the only value that distinguishes
  /// two records if an FIR number is ever reused across stations.
  final String firId;

  /// The sections as stored. Echoed rather than assumed: the handler substitutes
  /// its own suggestions when the request omits them, so reading them back is
  /// how the success screen can state what was actually filed instead of what
  /// was typed.
  final String actSections;

  /// Filename of the generated PDF, e.g. `FIR_FIR001.pdf`, as servers that
  /// still write the PDF to their own `generated_firs/` directory report it.
  ///
  /// Empty against a current server. The column was replaced by [pdfUrl] when
  /// PDF storage moved to Supabase, and only [hasPdf] and [pdfLabel] should be
  /// read in preference to either — a record filed before the move has this and
  /// no URL, one filed after has the URL and not this.
  final String pdfFile;

  /// Where the generated PDF actually lives now: the Supabase object URL the
  /// server stores as `pdf_url` and `GET /fir/download/<fir_no>` redirects to.
  ///
  /// Not fetched directly. The app asks the server for the file by FIR number
  /// exactly as the website's console does, so a moved bucket or a rotated
  /// signing scheme is the server's problem rather than a client that has
  /// memorised a storage layout.
  final String pdfUrl;

  /// The server's UTC timestamp, stringified. Displayed as-is; parsing it into
  /// a local time would imply a precision the format does not carry.
  final String createdAt;

  /// `Saved to Police Records` — the only value the handler writes.
  final String status;

  /// The server's own confirmation line, shown verbatim.
  final String message;

  /// Whether the record claims a PDF at all, under either spelling.
  bool get hasPdf => pdfLabel.isNotEmpty;

  /// The PDF's filename, whichever column carried it.
  ///
  /// A `pdf_url` is a Supabase URL a hundred characters long, and showing one
  /// on a receipt tells an officer nothing they can act on. Its last path
  /// segment is the filename, which is the part that was being shown before the
  /// storage move and the part that still means something.
  String get pdfLabel => FirPdf.label(pdfUrl: pdfUrl, pdfFile: pdfFile);

  @override
  String toString() => 'FirReceipt($firNo)';
}
