import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';

import '../../domain/entities/evidence_file.dart';

/// Where a piece of evidence comes from.
///
/// Three sources rather than one "attach" button, because on a handset they are
/// three different physical acts and the officer knows which one they are about
/// to perform before they tap anything. Collapsing them into a single picker
/// costs a round of "no, the other one" every time.
enum EvidenceSource {
  /// Straight from the camera. The common case at a scene, and the only one
  /// where the file does not exist yet.
  camera('Take a photo'),

  /// A photo or video already on the device.
  gallery('Choose a photo or video'),

  /// Anything else — a PDF statement, a recorded call, a scanned document. The
  /// locker holds all of these and the gallery cannot reach them.
  files('Choose a file');

  const EvidenceSource(this.label);

  final String label;
}

/// Turns a user's choice into a file the uploader can send.
///
/// An interface rather than a bare function so the upload controller can be
/// driven in tests without a plugin: `image_picker` and `file_picker` both
/// require a platform channel, which a widget test has none of.
abstract interface class EvidenceFilePicker {
  /// Returns null when the officer backed out of the picker. That is a
  /// dismissal, never an error — a cancelled camera must not produce a message.
  Future<EvidenceFile?> pick(EvidenceSource source);
}

/// The real one, over `image_picker` and `file_picker`.
class PlatformEvidenceFilePicker implements EvidenceFilePicker {
  PlatformEvidenceFilePicker([ImagePicker? imagePicker])
      : _images = imagePicker ?? ImagePicker();

  final ImagePicker _images;

  @override
  Future<EvidenceFile?> pick(EvidenceSource source) async {
    switch (source) {
      case EvidenceSource.camera:
        final shot = await _images.pickImage(source: ImageSource.camera);
        return shot == null ? null : _fromXFile(shot);

      case EvidenceSource.gallery:
        // `pickMedia` rather than `pickImage`, so a phone video of the scene is
        // one tap and not a second menu item nobody finds.
        final media = await _images.pickMedia();
        return media == null ? null : _fromXFile(media);

      case EvidenceSource.files:
        final result = await FilePicker.platform.pickFiles();
        final picked = result?.files.singleOrNull;
        final path = picked?.path;
        if (picked == null || path == null) return null;
        return EvidenceFile(
          path: path,
          name: picked.name,
          sizeInBytes: picked.size,
        );
    }
  }

  /// `XFile.length()` rather than `File.statSync()`: a camera capture on Android
  /// may still be being written when the picker returns, and the async length is
  /// the one that waits for it.
  Future<EvidenceFile> _fromXFile(XFile file) async {
    final length = await file.length();
    return EvidenceFile(
      path: file.path,
      // `XFile.name` is the last path segment, which for a camera capture is a
      // generated name like `image_picker_1234.jpg`. Kept as-is: renaming it
      // client-side would invent a filename that means nothing at the station,
      // and the FIR number is what actually files it.
      name: file.name.isNotEmpty ? file.name : _basename(file.path),
      sizeInBytes: length,
    );
  }

  String _basename(String path) => path.split(Platform.pathSeparator).last;
}
