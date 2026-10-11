import 'package:flutter_test/flutter_test.dart';
import 'package:nayaya_app/core/constants/api_endpoints.dart';
import 'package:nayaya_app/features/evidence/data/models/evidence_models.dart';
import 'package:nayaya_app/features/evidence/domain/entities/evidence_category.dart';
import 'package:nayaya_app/features/evidence/domain/entities/evidence_file.dart';

/// Pins the locker's contract with the four evidence endpoints, and the one
/// piece of server logic the app is obliged to duplicate.
void main() {
  group('EvidenceCategory', () {
    // A copy of the server's own table in `api_get_evidence`. The two must agree
    // or the same file gets a photo icon on one screen and a document icon on
    // the other.
    test('matches the server\'s extension table', () {
      const expected = {
        'a.jpg': EvidenceCategory.image,
        'a.jpeg': EvidenceCategory.image,
        'a.png': EvidenceCategory.image,
        'a.gif': EvidenceCategory.image,
        'a.webp': EvidenceCategory.image,
        'a.bmp': EvidenceCategory.image,
        'a.mp4': EvidenceCategory.video,
        'a.mov': EvidenceCategory.video,
        'a.avi': EvidenceCategory.video,
        'a.mkv': EvidenceCategory.video,
        'a.webm': EvidenceCategory.video,
        'a.mp3': EvidenceCategory.audio,
        'a.wav': EvidenceCategory.audio,
        'a.ogg': EvidenceCategory.audio,
        'a.aac': EvidenceCategory.audio,
        'a.flac': EvidenceCategory.audio,
        'a.m4a': EvidenceCategory.audio,
        'a.pdf': EvidenceCategory.pdf,
        'a.docx': EvidenceCategory.other,
        'a.zip': EvidenceCategory.other,
      };

      expected.forEach((filename, category) {
        expect(
          EvidenceCategory.fromExtension(filename),
          category,
          reason: filename,
        );
      });
    });

    // Android cameras write .JPG about as often as .jpg, and a photo filed under
    // "File" because of a capital letter is a photo nobody previews.
    test('is case-insensitive about the extension', () {
      expect(
        EvidenceCategory.fromExtension('SCENE.JPG'),
        EvidenceCategory.image,
      );
      expect(
        EvidenceCategory.fromExtension('CCTV.MP4'),
        EvidenceCategory.video,
      );
    });

    test('a name with no usable extension is just a file', () {
      expect(EvidenceCategory.fromExtension('notes'), EvidenceCategory.other);
      expect(EvidenceCategory.fromExtension('notes.'), EvidenceCategory.other);
      expect(EvidenceCategory.fromExtension(''), EvidenceCategory.other);
    });

    test('the server\'s file_type wins when it sends one', () {
      expect(
        EvidenceCategory.fromWire('video', filename: 'clip.bin'),
        EvidenceCategory.video,
      );
    });

    // Falling back to `other` would flatten every file on the page to a generic
    // icon the moment the server added a sixth category.
    test('an unknown file_type falls back to the extension, not to other', () {
      expect(
        EvidenceCategory.fromWire('photograph', filename: 'scene.jpg'),
        EvidenceCategory.image,
      );
      expect(
        EvidenceCategory.fromWire(null, filename: 'statement.pdf'),
        EvidenceCategory.pdf,
      );
    });

    test('only an image can be shown in place', () {
      expect(EvidenceCategory.image.isPreviewable, isTrue);
      for (final category in EvidenceCategory.values) {
        if (category == EvidenceCategory.image) continue;
        expect(category.isPreviewable, isFalse, reason: category.name);
      }
    });
  });

  group('AllEvidenceResponse — GET /get-all-evidence', () {
    test('flattens the grouping into addressable items', () {
      final items = AllEvidenceResponse.fromJson(const {
        'FIR001': ['scene.jpg', 'statement.pdf'],
        'FIR002': ['cctv.mp4'],
      });

      expect(items, hasLength(3));
      expect(items.first.firNo, 'FIR001');
      expect(items.first.filename, 'scene.jpg');
      expect(items.first.category, EvidenceCategory.image);
    });

    // This payload carries filenames and nothing else, so the timestamp is not
    // "never recorded" — it is not known here.
    test('leaves the timestamp empty rather than inventing one', () {
      final items = AllEvidenceResponse.fromJson(const {
        'FIR001': ['scene.jpg'],
      });

      expect(items.single.uploadedAt, isEmpty);
      expect(items.single.hasTimestamp, isFalse);
    });

    test('skips rows that could never be opened', () {
      final items = AllEvidenceResponse.fromJson(const {
        'FIR001': ['scene.jpg', '', '   '],
        '': ['orphan.jpg'],
        'FIR003': 'not a list',
      });

      expect(items, hasLength(1));
      expect(items.single.filename, 'scene.jpg');
    });

    test('an empty locker parses to an empty list', () {
      expect(AllEvidenceResponse.fromJson(const {}), isEmpty);
    });
  });

  group('EvidenceItemResponse — GET /api/evidence', () {
    test('reads the row the list screen could not', () {
      final item = EvidenceItemResponse.fromJson(const {
        'fir_no': 'FIR001',
        'filename': 'scene.jpg',
        'file_type': 'image',
        'file_url': '/evidence-file/FIR001/scene.jpg',
        'uploaded_at': '2026-08-09 10:11:12.345678',
      });

      expect(item, isNotNull);
      expect(item!.firNo, 'FIR001');
      expect(item.category, EvidenceCategory.image);
      expect(item.uploadedAt, '2026-08-09 10:11:12.345678');
      expect(item.hasTimestamp, isTrue);
    });

    // The collection is seeded from the filesystem, so a nameless row is a real
    // case. Rendering one would put a tappable line on the list leading nowhere.
    test('a row with no filename is dropped', () {
      expect(
        EvidenceItemResponse.fromJson(const {'fir_no': 'FIR001'}),
        isNull,
      );
    });
  });

  group('EvidenceUploadResponse — POST /upload-evidence', () {
    // `secure_filename` rewrites the name server-side. An app that assumed its
    // own would build a detail route to a file that is not there.
    test('trusts the filename the server stored, not the one that was sent',
        () {
      final item = EvidenceUploadResponse.fromJson(
        const {
          'message': 'File uploaded successfully',
          'file': 'scene_1.jpg',
          'fir_no': 'FIR001',
        },
        fallbackFirNo: 'FIR001',
        fallbackFilename: 'scene 1.jpg',
      );

      expect(item.filename, 'scene_1.jpg');
      expect(item.firNo, 'FIR001');
    });

    test('falls back to what was sent when the handler echoes nothing', () {
      final item = EvidenceUploadResponse.fromJson(
        const {'message': 'File uploaded successfully'},
        fallbackFirNo: 'FIR001',
        fallbackFilename: 'scene.jpg',
      );

      expect(item.filename, 'scene.jpg');
      expect(item.firNo, 'FIR001');
      expect(item.category, EvidenceCategory.image);
    });

    // The row's timestamp is the server's UTC clock; a handset's guess at it
    // would be a different number in the same column.
    test('does not stamp a client-side upload time', () {
      final item = EvidenceUploadResponse.fromJson(
        const {'file': 'scene.jpg'},
        fallbackFirNo: 'FIR001',
        fallbackFilename: 'scene.jpg',
      );

      expect(item.uploadedAt, isEmpty);
    });
  });

  group('ApiEndpoints', () {
    test('encodes an FIR number that would otherwise break the path', () {
      expect(
        ApiEndpoints.evidenceFile('41/2026', 'scene 1.jpg'),
        '/evidence-file/41%2F2026/scene%201.jpg',
      );
    });

    test('encodes the query the same way', () {
      expect(
        ApiEndpoints.evidenceForFir('41/2026'),
        '/api/evidence?fir_no=41%2F2026',
      );
    });
  });

  group('EvidenceFile', () {
    // Binary units, matching what a file manager on the same handset says. Two
    // figures disagreeing about one file is worse than either being wrong.
    test('reports a size an officer can compare with the file manager', () {
      EvidenceFile of(int bytes) =>
          EvidenceFile(path: '/tmp/a', name: 'a', sizeInBytes: bytes);

      expect(of(512).displaySize, '512 B');
      expect(of(2048).displaySize, '2.0 KB');
      expect(of(1024 * 1024 * 2.4 ~/ 1).displaySize, '2.4 MB');
      expect(of(1024 * 1024 * 15).displaySize, '15 MB');
      expect(of(1024 * 1024 * 1024 * 3).displaySize, '3.0 GB');
    });
  });
}
