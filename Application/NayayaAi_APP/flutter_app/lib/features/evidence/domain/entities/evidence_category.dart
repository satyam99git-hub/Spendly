/// What kind of file a piece of evidence is.
///
/// The server derives this from the extension and returns it as `file_type` on
/// `GET /api/evidence` — but only there. `GET /get-all-evidence`, which the list
/// screen is built on, returns bare filenames, so the app has to be able to
/// reach the same answer on its own.
///
/// [fromExtension] is therefore a deliberate copy of the server's table, not an
/// accident. The two must stay in step: a category the app calls `other` and the
/// server calls `image` shows a document icon on the list and a photo on the
/// detail page, for the same file.
enum EvidenceCategory {
  image('image', 'Photo'),
  video('video', 'Video'),
  audio('audio', 'Audio'),
  pdf('pdf', 'PDF'),
  other('other', 'File');

  const EvidenceCategory(this.wireValue, this.label);

  /// What `file_type` holds on `GET /api/evidence`.
  final String wireValue;

  /// Human-readable, for a chip beside the filename.
  final String label;

  /// True when the file can be shown in place rather than described.
  bool get isPreviewable => this == image;

  /// The server's own extension table, from `api_get_evidence`.
  static const _byExtension = <String, EvidenceCategory>{
    'jpg': image, 'jpeg': image, 'png': image, 'gif': image,
    'webp': image, 'bmp': image, //
    'mp4': video, 'mov': video, 'avi': video, 'mkv': video, 'webm': video,
    'mp3': audio, 'wav': audio, 'ogg': audio, 'aac': audio, 'flac': audio,
    'm4a': audio,
    'pdf': pdf,
  };

  /// Categorises a filename the way the server would.
  ///
  /// Anything unrecognised — and anything with no extension at all — is
  /// [other], which is what the server does too. Case-insensitive: Android
  /// cameras write `.JPG` about as often as `.jpg`, and a photo filed under
  /// "File" because of a capital letter is a photo nobody previews.
  static EvidenceCategory fromExtension(String filename) {
    final dot = filename.lastIndexOf('.');
    if (dot < 0 || dot == filename.length - 1) return other;
    return _byExtension[filename.substring(dot + 1).toLowerCase()] ?? other;
  }

  /// Parses the server's `file_type`. Falls back to [fromExtension] rather than
  /// to [other], so an unrecognised value still produces the right icon instead
  /// of flattening every file on the page to a generic one.
  static EvidenceCategory fromWire(String? value, {required String filename}) {
    final v = value?.trim().toLowerCase();
    for (final category in EvidenceCategory.values) {
      if (category.wireValue == v) return category;
    }
    return fromExtension(filename);
  }
}
