/// Reading the two columns the server has used for an FIR's generated PDF.
///
/// There have been two, and records written under both are in the same
/// collection:
///
///   - `pdf_file` — `FIR_FIR001.pdf`, a filename under the server's own
///     `generated_firs/` directory. What every record filed before PDF storage
///     moved to Supabase carries.
///   - `pdf_url` — the Supabase object URL, which is what the server writes
///     now and what `GET /fir/download/<fir_no>` redirects to.
///
/// A viewer that understood only the first showed nothing at all for every FIR
/// filed since the move, including the one the officer had just filed. Reading
/// both is not backwards compatibility for its own sake: the history list is a
/// single list mixing records from both eras.
abstract final class FirPdf {
  const FirPdf._();

  /// The PDF's filename, from whichever column carried it, or `''` when the
  /// record claims no PDF.
  ///
  /// A URL is reduced to its last path segment. Showing a hundred-character
  /// Supabase URL on a record screen tells an officer nothing they can act on,
  /// and the filename is what the screen showed before the move.
  ///
  /// Presence is a claim, not a promise: only `GET /fir/download/<fir_no>` can
  /// say whether the object is still there, which is why the download button is
  /// offered either way.
  static String label({required String pdfUrl, required String pdfFile}) {
    final url = pdfUrl.trim();
    if (url.isNotEmpty) {
      final name = _lastSegment(url);
      // A URL that is all host and no path has no filename to show; the record
      // still has a PDF, so say so rather than reporting none.
      return name.isEmpty ? 'FIR PDF' : name;
    }
    return pdfFile.trim();
  }

  /// The last non-empty path segment, with any query string and fragment
  /// dropped. Parsed by hand rather than with [Uri.parse] because the column is
  /// whatever the storage client returned and does not have to be a valid URI.
  static String _lastSegment(String url) {
    var path = url;
    for (final cut in ['#', '?']) {
      final i = path.indexOf(cut);
      if (i != -1) path = path.substring(0, i);
    }
    final segments = path.split('/').where((s) => s.isNotEmpty);
    return segments.isEmpty ? '' : Uri.decodeComponent(segments.last);
  }
}
