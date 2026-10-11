/// A file chosen on the handset, on its way to the locker.
///
/// Deliberately not `dart:io`'s `File`, and deliberately not `XFile` either.
/// Both would put the plugin (or the filesystem) in the signature of everything
/// that touches an upload, which means the upload controller could not be tested
/// without one. This carries the three things the upload actually needs and
/// nothing else.
class EvidenceFile {
  const EvidenceFile({
    required this.path,
    required this.name,
    required this.sizeInBytes,
  });

  /// Absolute path on the device. Read once, by the data source, when the
  /// multipart body is built.
  final String path;

  /// The name the file will be stored under.
  ///
  /// The server runs this through `secure_filename`, which strips directory
  /// separators and non-ASCII — so the stored name can differ from this one, and
  /// the app must read the name back from the response rather than assume it.
  final String name;

  final int sizeInBytes;

  /// `2.4 MB`. Binary units, because that is what a file manager on the same
  /// handset will say, and two figures disagreeing about the same file is worse
  /// than either being wrong.
  String get displaySize {
    if (sizeInBytes < 1024) return '$sizeInBytes B';
    const units = ['KB', 'MB', 'GB'];
    var value = sizeInBytes / 1024;
    var unit = 0;
    while (value >= 1024 && unit < units.length - 1) {
      value /= 1024;
      unit++;
    }
    return '${value.toStringAsFixed(value >= 10 ? 0 : 1)} ${units[unit]}';
  }

  @override
  String toString() => 'EvidenceFile($name, $displaySize)';
}
